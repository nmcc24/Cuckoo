import Foundation
import Stencil
import SwiftBasicFormat
import SwiftParser
import SwiftSyntax

@globalActor
actor StaticActor {
    static let shared = StaticActor()
}

struct GeneratorHelper {
    @StaticActor
    private static let extensions = createExtensions()

    @StaticActor
    static func generate(
        tokens: [any Token],
        keepDocumentation: Bool = true,
        mockNaming: MockNaming = .default,
        debug: Bool = false
    ) throws -> String {
        // Serializing the tokens and the template filters both name mocks.
        try MockNaming.$current.withValue(mockNaming) {
            let containers = try tokens.map { token in
                var context = token.serialize()
                if let container = token as? any ContainerToken {
                    context["nopImplStub"] = try NopImplStubBuilder.build(container)
                }
                return context
            }

            let environment = Environment(
                extensions: extensions,
                trimBehaviour: .smart
            )
            let rendered = try environment.renderTemplate(
                string: Templates.mock,
                context: ["containers": containers, "keepDocumentation": keepDocumentation, "debug": debug]
            )
            return try format(rendered)
        }
    }

    /// Lays `source` out with swift-syntax's formatter. Output that doesn't parse is a generator bug, which would
    /// format into something worse, so it fails generation with the line the parser stopped at.
    static func format(_ source: String) throws -> String {
        let tree = Parser.parse(source: source)
        guard tree.hasError else {
            return SingleBlankLines().rewrite(tree.formatted()).description
        }
        let converter = SourceLocationConverter(fileName: "", tree: tree)
        let firstError = tree.tokens(viewMode: .all).first { token in
            token.presence == .missing || token.parent?.is(UnexpectedNodesSyntax.self) == true
        }
        let line = firstError.map { converter.location(for: $0.positionAfterSkippingLeadingTrivia).line } ?? 1
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        let text = lines.indices.contains(line - 1) ? lines[line - 1].trimmingCharacters(in: .whitespaces) : ""
        throw FormatError.unparsableOutput(line: line, text: text)
    }

    /// Keeps at most one blank line between declarations and statements, and none just inside braces. The newlines
    /// between tokens are trivia, so string literals and comments keep theirs.
    private final class SingleBlankLines: SyntaxRewriter {
        override func visit(_ token: TokenSyntax) -> TokenSyntax {
            // No blank line just inside braces.
            let opensOrCloses = token.tokenKind == .rightBrace || token.previousToken(viewMode: .sourceAccurate)?.tokenKind == .leftBrace
            let limit = opensOrCloses ? 1 : 2
            var pieces: [TriviaPiece] = []
            var newlines = 0
            for piece in token.leadingTrivia {
                switch piece {
                case .newlines(let count):
                    // Whitespace before a newline only ends a line.
                    while let last = pieces.last, last.isSpaceOrTab { pieces.removeLast() }
                    let kept = min(count, limit - newlines)
                    newlines += kept
                    if kept > 0 { pieces.append(.newlines(kept)) }
                case .spaces, .tabs:
                    pieces.append(piece)
                default:
                    newlines = 0
                    pieces.append(piece)
                }
            }
            let trivia = Trivia(pieces: pieces)
            // Returning the token itself when nothing changed keeps the rewriter from rebuilding every node above it.
            guard trivia != token.leadingTrivia else { return token }
            return token.with(\.leadingTrivia, trivia)
        }
    }

    enum FormatError: Error, CustomStringConvertible {
        case unparsableOutput(line: Int, text: String)

        var description: String {
            switch self {
            case .unparsableOutput(let line, let text):
                return "The generated mocks don't parse, at line \(line): `\(text)`. Please report this as a Cuckoo bug, with the declaration it mocks."
            }
        }
    }

    static func matchableGenericTypes(from method: Method, forVerification: Bool = false) -> String {
        let genericParameters = method.proxyGenerics(forVerification: forVerification).parameters
        guard !method.signature.parameters.isEmpty || !genericParameters.isEmpty else { return "" }

        let matchableGenericParameters = method.signature.parameters.enumerated().map { index, parameter -> String in
            let type = parameter.matchedType.isOptional ? "OptionalMatchable" : "Matchable"
            return "M\(index + 1): Cuckoo.\(type)"
        }
        let methodGenericParameters = genericParameters.map { $0.description }
        return "<\((matchableGenericParameters + methodGenericParameters).joined(separator: ", "))>"
    }

    static func matchableGenericsWhereClause(from method: Method, forVerification: Bool = false) -> String {
        guard method.signature.parameters.isEmpty == false else { return "" }

        let matchableWhereConstraints = method.signature.parameters.enumerated().map { index, parameter -> String in
            let type = parameter.matchedType.isOptional ? "OptionalMatchedType" : "MatchedType"
            return "M\(index + 1).\(type) == \(genericSafeType(from: parameter.matchedType.genericArgumentSafe.unoptionaled.description))"
        }
        let methodWhereConstraints = method.proxyGenerics(forVerification: forVerification).whereConstraints
        return " where \((matchableWhereConstraints + methodWhereConstraints).joined(separator: ", "))"
    }

    static func matchableParameterSignature(with parameters: [MethodParameter]) -> String {
        guard !parameters.isEmpty else { return "" }

        return parameters.enumerated()
            .map { "\($1.nameAndInnerName): M\($0 + 1)" }
            .joined(separator: ", ")
    }

    static func parameterMatchers(for parameters: [MethodParameter]) -> String {
        guard parameters.isEmpty == false else { return "let matchers: [Cuckoo.ParameterMatcher<Void>] = []" }

        let tupleType = parameters.map { $0.matchedType.genericArgumentSafe.description }.joined(separator: ", ")
        let matchers = parameters
            // Enumeration is done after filtering out parameters without usable names.
            .enumerated()
            .compactMap { index, parameter in
                let name = escapeReservedKeywords(for: parameter.usableName)
                return "Cuckoo.wrap(matchable: \(name)) { $0\(parameters.count > 1 ? ".\(index)" : "") }"
            }
            .joined(separator: ", ")
        return "let matchers: [Cuckoo.ParameterMatcher<(\(genericSafeType(from: tupleType)))>] = [\(matchers)]"
    }

    static func genericSafeType(from type: String) -> String {
        return type.replacingOccurrences(of: "!", with: "?")
    }

    /// The non-escaping closure parameters, with their positions, which the mock makes escaping with
    /// `withoutActuallyEscaping` to record them.
    private static func nonEscapingClosureParameters(of method: Method) -> [(offset: Int, element: MethodParameter)] {
        method.signature.parameters.enumerated().filter { !$0.element.type.containsAttribute(named: "@escaping") && $0.element.type.findClosure() != nil }
    }

    /// Whether the mock's body is wrapped in local functions rather than closures; see `openNestedClosure`.
    private static func usesLocalFunctions(_ method: Method) -> Bool {
        method.isAsync
    }

    private static func openNestedClosure(for method: Method) -> String {
        let parameters = nonEscapingClosureParameters(of: method)
        guard !parameters.isEmpty else { return "" }
        let returnSignature = if let returnType = method.returnType, !returnType.isVoid { " -> \(returnType.description)" } else { "" }
        var fullString = "\n"
        if usesLocalFunctions(method) {
            // An async body goes into local functions: under NonisolatedNonsendingByDefault, a closure passed to
            // `withoutActuallyEscaping` runs concurrently, so capturing the non-`Sendable` mock is a data race. A
            // nonisolated member's function is `nonisolated(nonsending)` explicitly, to run on the caller's actor
            // whatever the module's default; an isolated member's function keeps the member's isolation.
            let isolation = parent(of: method).stubIsolation(forMember: method.stubbedIsolation)
            let execution = isolation.sharing != .isolated && isolation.isolatedParameter == nil ? "nonisolated(nonsending) " : ""
            let effects = ["async", method.signature.throwType.map { $0.isRethrowing ? "throws" : $0.description }]
                .compactMap { $0 }
                .joined(separator: " ")
            for (index, parameter) in parameters {
                let indents = String(repeating: "\t", count: index + 2)
                fullString += "\(indents)\(execution)func \(localFunctionName(for: parameter))(_ \(parameter.usableName): @escaping \(parameter.type)) \(effects)\(returnSignature) {\n"
            }
        } else {
            let tries = method.isThrowing ? "try " : ""
            for (index, parameter) in parameters {
                let indents = String(repeating: "\t", count: index + 2)
                fullString += "\(indents)return \(tries)withoutActuallyEscaping(\(parameter.usableName), do: { (\(parameter.usableName): @escaping \(parameter.type))\(returnSignature) in\n"
            }
        }
        return fullString
    }

    private static func closeNestedClosure(for method: Method) -> String {
        let parameters = nonEscapingClosureParameters(of: method)
        guard !parameters.isEmpty else { return "" }
        var fullString = "\n"
        let tries = method.isThrowing ? "try " : ""
        for (index, parameter) in parameters.reversed() {
            let indents = String(repeating: "\t", count: index + 2)
            if usesLocalFunctions(method) {
                fullString += "\(indents)}\n"
                fullString += "\(indents)return \(tries)await withoutActuallyEscaping(\(parameter.usableName), do: \(localFunctionName(for: parameter)))\n"
            } else {
                fullString += "\(indents)})\n"
            }
        }
        return fullString
    }

    private static func localFunctionName(for parameter: MethodParameter) -> String {
        "__cuckoo_escaping_\(parameter.usableName)"
    }

    private static func parent(of method: Method) -> any Token {
        guard let parent = method.parent?.value else {
            fatalError("Failed to find parent of method \(method.fullSignature). Please file a bug.")
        }
        return parent
    }

    static func removeClosureArgumentNames(for type: String) -> String {
        type.replacingOccurrences(
            of: "_\\s+?[_a-zA-Z]\\w*?\\s*?:",
            with: "",
            options: .regularExpression
        )
    }
}

extension GeneratorHelper {
    private static func createExtensions() -> [Extension] {
        let stencilExtension = Extension()

        stencilExtension.registerFilter("genericSafe") { (value: Any?) in
            guard let string = value as? String else { return value }
            return genericSafeType(from: string)
        }
        stencilExtension.registerFilter("matchableGenericNames") { (value: Any?) in
            guard let method = value as? Method else { return value }
            return matchableGenericTypes(from: method)
        }
        stencilExtension.registerFilter("matchableGenericWhereClause") { (value: Any?) in
            guard let method = value as? Method else { return value }
            return matchableGenericsWhereClause(from: method)
        }
        stencilExtension.registerFilter("matchableVerificationGenericNames") { (value: Any?) in
            guard let method = value as? Method else { return value }
            return matchableGenericTypes(from: method, forVerification: true)
        }
        stencilExtension.registerFilter("matchableVerificationGenericWhereClause") { (value: Any?) in
            guard let method = value as? Method else { return value }
            return matchableGenericsWhereClause(from: method, forVerification: true)
        }
        stencilExtension.registerFilter("matchableParameterSignature") { (value: Any?) in
            guard let parameters = value as? [MethodParameter] else { return value }
            return matchableParameterSignature(with: parameters)
        }
        stencilExtension.registerFilter("parameterMatchers") { (value: Any?) in
            guard let parameters = value as? [MethodParameter] else { return value }
            return parameterMatchers(for: parameters)
        }
        stencilExtension.registerFilter("openNestedClosure") { (value: Any?) in
            guard let method = value as? Method else { return value }
            return openNestedClosure(for: method)
        }
        stencilExtension.registerFilter("closeNestedClosure") { (value: Any?) in
            guard let method = value as? Method else { return value }
            return closeNestedClosure(for: method)
        }
        stencilExtension.registerFilter("escapeReservedKeywords") { (value: Any?) in
            guard let name = value as? String else { return value }
            return escapeReservedKeywords(for: name)
        }
        stencilExtension.registerFilter("removeClosureArgumentNames") { (value: Any?) in
            guard let type = value as? String else { return value }
            return removeClosureArgumentNames(for: type)
        }
        stencilExtension.registerFilter("withSpace") { (value: Any?) in
            if let value = value as? String, !value.isEmpty {
                return "\(value) "
            } else {
                return ""
            }
        }

        return [stencilExtension]
    }
}

/// Reserved keywords that are not allowed as function names, function parameters, or local variables, etc.
fileprivate let reservedKeywords: Set = [
    // Keywords used in declarations:
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout",
    "internal", "let", "operator", "private", "precedencegroup", "protocol", "public", "rethrows", "static",
    "struct", "subscript", "typealias", "var",
    // Keywords used in statements:
    "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in",
    "repeat", "return", "throw", "switch", "where", "while",
    // Keywords used in expressions and types:
    "Any", "as", "catch", "false", "is", "nil", "rethrows", "self", "super", "throw", "throws", "true", "try", "async",
    // Keywords used in patterns:
    "_",
]

/// Utility function for escaping reserved keywords for a symbol name.
func escapeReservedKeywords(for name: String) -> String {
    reservedKeywords.contains(name) ? "`\(name)`" : name
}

private extension TriviaPiece {
    var isSpaceOrTab: Bool {
        switch self {
        case .spaces, .tabs: true
        default: false
        }
    }
}
