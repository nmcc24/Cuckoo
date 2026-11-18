import SwiftBasicFormat
import SwiftParser
import SwiftSyntax

struct GeneratorHelper {
    /// The access of a member's stubbing or verification proxy member: the member's own, up to
    /// the mock's, so a public or package mock can be stubbed and verified from another module without `@testable`.
    /// An `@_spi` member's proxy members stay internal, as before: public ones would need the tests to import the
    /// mocks with the same `@_spi`.
    static func proxyAccess(of member: some HasAccessibility & HasAttributes, in container: any ContainerToken) -> Accessibility {
        guard member.attributes.allSatisfy({ $0.spiGroup == nil }) else { return min(member.accessibility, .internal) }
        return min(member.accessibility, container.accessibility)
    }

    /// The mocks and stubs of a file's mocked types, laid out.
    static func generate(tokens: [any Token], keepDocumentation: Bool = true, mockNaming: MockNaming = .default) throws -> String {
        // The builders name mocks through the tokens.
        try MockNaming.$current.withValue(mockNaming) {
            let mocks = try tokens.compactMap { $0 as? any ContainerToken }.map {
                try MockBuilder.build($0, keepDocumentation: keepDocumentation)
            }
            return try format(mocks.joined())
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
        let text = lines.indices.contains(line - 1) ? lines[line - 1].trimmedSpaces : ""
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

    /// - Parameter sendable: whether the proxy is a `Sendable` mock's stubbing proxy, whose stubs can be matched from any
    ///   task, so it takes `Sendable` matchers.
    static func matchableGenericTypes(from method: Method, forVerification: Bool = false, sendable: Bool = false) -> String {
        let genericParameters = method.proxyGenerics(forVerification: forVerification).parameters
        guard !method.signature.parameters.isEmpty || !genericParameters.isEmpty else { return "" }

        let prefix = matcherPrefix
        let matchableGenericParameters = method.signature.parameters.enumerated().map { index, parameter -> String in
            return "\(prefix)\(index + 1): Cuckoo.\(matcherProtocol(isOptional: parameter.matchedType.isOptional, sendable: sendable))"
        }
        let methodGenericParameters = genericParameters.map { $0.description }
        return "<\((matchableGenericParameters + methodGenericParameters).joined(separator: ", "))>"
    }

    static func matchableGenericsWhereClause(from method: Method, forVerification: Bool = false) -> String {
        guard method.signature.parameters.isEmpty == false else { return "" }

        let prefix = matcherPrefix
        let matchableWhereConstraints = method.signature.parameters.enumerated().map { index, parameter -> String in
            let type = parameter.matchedType.isOptional ? "OptionalMatchedType" : "MatchedType"
            return "\(prefix)\(index + 1).\(type) == \(genericSafeType(from: parameter.matchedType.genericArgumentSafe.unoptionaled.description))"
        }
        let methodWhereConstraints = method.proxyGenerics(forVerification: forVerification).whereConstraints
        return " where \((matchableWhereConstraints + methodWhereConstraints).joined(separator: ", "))"
    }

    static func matchableParameterSignature(with parameters: [MethodParameter], of method: Method) -> String {
        guard !parameters.isEmpty else { return "" }

        let prefix = matcherPrefix
        return parameters.enumerated()
            .map { "\($1.nameAndInnerName): \(prefix)\($0 + 1)" }
            .joined(separator: ", ")
    }

    /// What a call tells one method's proxy member from another's by: its name, labels, generic parameters and the
    /// types its matchers match. Not its result, its access or the matchers' `Sendable` flavour, which a call
    /// such as `stub.value()` doesn't state.
    static func proxyCallKey(of method: Method) -> String {
        let generics = matchableGenericTypes(from: method, forVerification: true)
        let parameters = matchableParameterSignature(with: method.signature.parameters, of: method)
        return "\(method.proxyName)\(generics)(\(parameters))\(matchableGenericsWhereClause(from: method, forVerification: true))"
    }

    /// The async methods among `methods` that a sync one overloads with the same call, as `value() async` next to
    /// `value()`, by their place in `methods`. Both proxies name them through `async`, so both ask here.
    static func asyncOverloads(among methods: [Method]) -> Set<Int> {
        let syncKeys = Set(methods.filter { !$0.isAsync }.map(proxyCallKey))
        return Set(methods.indices.filter { methods[$0].isAsync && syncKeys.contains(proxyCallKey(of: methods[$0])) })
    }

    /// The type of a proxy's `async` member, which holds the async overloads of the methods with a sync one too.
    static let asyncNamespaceType = "__Async"

    /// Whether a proxy can declare `async`: a mocked property or method of that name takes it, and the async
    /// overloads' own members are then `async`, named with `await`.
    static func canDeclareAsyncNamespace(in container: any ContainerToken, isStatic: Bool) -> Bool {
        let names = container.mockedProperties.filter { $0.isStatic == isStatic }.map(\.name)
            + container.mockedMethods.filter { $0.isStatic == isStatic }.map(\.proxyName)
        return !names.contains { $0 == "async" || $0 == "`async`" }
    }

    /// The name of a proxy member's matcher generics, `__M1`, `__M2` and so on, which no name of the mocked code
    /// shadows or is shadowed by, as `M1` could be: a generic parameter of the member or a type it names.
    static let matcherPrefix = "__M"

    /// The protocol a proxy's matcher parameter conforms to.
    static func matcherProtocol(isOptional: Bool, sendable: Bool) -> String {
        "_\(sendable ? "Sendable" : "")\(isOptional ? "OptionalMatchable" : "Matchable")"
    }

    /// The matcher type a proxy keeps.
    static func matcherType(sendable: Bool) -> String {
        sendable ? "Cuckoo.SendableMatcher" : "Cuckoo.ParameterMatcher"
    }

    /// The matcher of the call's argument tuple for one parameter: a key path into the tuple for a `Sendable` mock's
    /// stubbing proxy, which a `@Sendable` closure can't be over a non-`Sendable` generic type, otherwise a closure.
    static func parameterMatcher(name: String, index: Int, count: Int, sendable: Bool) -> String {
        if sendable {
            return "Cuckoo.wrap(matchable: \(name), at: \\.\(count > 1 ? "\(index)" : "self"))"
        }
        return "Cuckoo.wrap(matchable: \(name)) { $0\(count > 1 ? ".\(index)" : "") }"
    }

    static func parameterMatchers(for parameters: [MethodParameter], sendable: Bool = false) -> String {
        let type = matcherType(sendable: sendable)
        guard parameters.isEmpty == false else { return "let matchers: [\(type)<Void>] = []" }

        let tupleType = parameters.map { $0.matchedType.genericArgumentSafe.description }.joined(separator: ", ")
        let matchers = parameters
            .enumerated()
            .map { index, parameter in
                parameterMatcher(name: escapeReservedKeywords(for: parameter.usableName), index: index, count: parameters.count, sendable: sendable)
            }
            .joined(separator: ", ")
        return "let matchers: [\(type)<(\(genericSafeType(from: tupleType)))>] = [\(matchers)]"
    }

    /// The argument that gives an unstubbed call returning a tuple its default value, or `nil` for any other return
    /// type: the manager's generic return type can't name a tuple's elements. The tuple is named by a local
    /// `typealias`, as `(...).self` can't spell every type: a closure element with a `borrowing` parameter, say.
    static func unstubbedTupleArgument(for type: ComplexType?) -> String? {
        guard case .type(let description) = type, let tuple = unlabeledTupleType(description) else { return nil }
        return "unstubbedTuple: { \(defaultTypealias(tuple)); return Cuckoo.MockManager.unstubbedTupleValue(for: \(defaultTypealiasName).self) }()"
    }

    /// The name `defaultTypealias(_:)` declares.
    static let defaultTypealiasName = "__CuckooDefault"

    /// A local `typealias` naming `type`, whose metatype an expression then takes: `(type).self` doesn't parse when
    /// the type has a closure with a `borrowing`, `consuming`, `isolated`, `sending`, `__owned` or `__shared`
    /// parameter. A tuple goes without its labels, which the runtime's tuple defaults take.
    static func defaultTypealias(_ type: String) -> String {
        "typealias \(defaultTypealiasName) = \(type.isEmpty ? "Void" : unlabeledTupleType(type) ?? type)"
    }

    /// A tuple type of two or more elements without its labels: a labeled tuple's metatype doesn't match the runtime's
    /// parameter pack, and the unlabeled value converts back to the labeled type. `nil` for any other type, and for a
    /// tuple with a pack expansion.
    static func unlabeledTupleType(_ description: String) -> String? {
        guard let tuple = typeSyntax(description)?.as(TupleTypeSyntax.self),
              tuple.elements.count >= 2,
              tuple.elements.allSatisfy({ $0.ellipsis == nil && $0.type.as(PackExpansionTypeSyntax.self) == nil })
        else {
            return nil
        }
        return "(" + tuple.elements.map { $0.type.trimmedDescription }.joined(separator: ", ") + ")"
    }

    /// `description` parsed as a type, from a `typealias` that names it.
    private static func typeSyntax(_ description: String) -> TypeSyntax? {
        Parser.parse(source: "typealias __CuckooType = \(description)").statements.first?.item
            .as(TypeAliasDeclSyntax.self)?.initializer.value
    }

    static func genericSafeType(from type: String) -> String {
        return type.replacing("!", with: "?")
    }

    /// The non-escaping closure parameters, with their positions, which the mock makes escaping with
    /// `withoutActuallyEscaping` to record them.
    private static func nonEscapingClosureParameters(of method: Method) -> [(offset: Int, element: MethodParameter)] {
        // An `inout` closure is a variable the caller owns, already escaping.
        method.signature.parameters.enumerated().filter {
            !$0.element.type.containsAttribute(named: "@escaping") && !$0.element.type.containsAttribute(named: "inout")
                && $0.element.type.findClosure() != nil
        }
    }

    /// Whether an async member takes an `isolated` parameter and a non-escaping closure: the local function the
    /// closure is made escaping in isn't isolated to the parameter's actor, so it can't forward the closure to the
    /// member's default implementation or superclass, which are. A sync member's closure isn't in a local function.
    static func forwardsAcrossIsolation(_ method: Method) -> Bool {
        method.isAsync && method.signature.parameters.contains { $0.type.containsAttribute(named: "isolated") }
            && !nonEscapingClosureParameters(of: method).isEmpty
    }

    /// Whether the mock's body is wrapped in local functions rather than closures; see `openNestedClosure`.
    private static func usesLocalFunctions(_ method: Method) -> Bool {
        method.isAsync
    }

    /// The lines that open the closures or local functions making each non-escaping closure parameter escaping, so
    /// the mock can record it; ``closeNestedClosure(for:)`` closes them after the body.
    /// The closure `withoutActuallyEscaping` takes: a `borrowing` one is copied first, as it can't be passed on.
    private static func escapable(_ parameter: MethodParameter) -> String {
        parameter.type.containsAttribute(named: "borrowing") ? "copy \(parameter.usableName)" : parameter.usableName
    }

    static func openNestedClosure(for method: Method) -> [String] {
        let parameters = nonEscapingClosureParameters(of: method)
        guard !parameters.isEmpty else { return [] }
        let returnSignature = if let returnType = method.returnType, !returnType.isVoid { " -> \(returnType.description)" } else { "" }
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
            return parameters.enumerated().map { level, element in
                let parameter = element.1
                return "\(indentation(level))\(execution)func \(localFunctionName(for: parameter))(_ \(parameter.usableName): @escaping \(parameter.type.withoutParameterSpecifiers)) \(effects)\(returnSignature) {"
            }
        } else {
            let tries = method.isThrowing ? "try " : ""
            // A typed error has to be spelled on the closure: inferred, it would be `any Error`.
            let typedThrows = method.signature.throwType.flatMap { $0.isTyped ? " \($0.description)" : nil } ?? ""
            return parameters.enumerated().map { level, element in
                let parameter = element.1
                return "\(indentation(level))return \(tries)withoutActuallyEscaping(\(escapable(parameter)), do: { (\(parameter.usableName): @escaping \(parameter.type.withoutParameterSpecifiers))\(typedThrows)\(returnSignature) in"
            }
        }
    }

    static func closeNestedClosure(for method: Method) -> [String] {
        let parameters = nonEscapingClosureParameters(of: method)
        let tries = method.isThrowing ? "try " : ""
        return parameters.enumerated().reversed().flatMap { level, element in
            let parameter = element.1
            return if usesLocalFunctions(method) {
                ["}", "return \(tries)await withoutActuallyEscaping(\(escapable(parameter)), do: \(localFunctionName(for: parameter)))"]
                    .map { indentation(level) + $0 }
            } else {
                [indentation(level) + "})"]
            }
        }
    }

    /// The indentation of the closure or local function at `level`, counted from 0 for the outermost.
    static func indentation(_ level: Int) -> String {
        String(repeating: "    ", count: level)
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

extension TriviaPiece {
    var isSpaceOrTab: Bool {
        switch self {
        case .spaces, .tabs: true
        default: false
        }
    }
}
