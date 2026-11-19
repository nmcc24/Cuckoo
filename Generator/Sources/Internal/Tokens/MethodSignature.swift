import RegexBuilder

extension Method {
    struct Signature: Sendable {
        let genericParameters: [GenericParameter]
        let parameters: [MethodParameter]
        let asyncType: AsyncType?
        let throwType: ThrowType?
        let returnType: ComplexType?
        let whereConstraints: [String]

        init(
            genericParameters: [GenericParameter],
            parameters: [MethodParameter],
            asyncType: AsyncType? = nil,
            throwType: ThrowType? = nil,
            returnType: ComplexType? = nil,
            whereConstraints: [String]
        ) {
            self.genericParameters = genericParameters
            self.parameters = parameters.enumerated().map { index, parameter in
                MethodParameter(
                    parent: parameter.parent,
                    name: parameter.name,
                    innerName: "p\(index)",
                    type: parameter.type,
                    isNoncopyable: parameter.isNoncopyable,
                    variadicElement: parameter.variadicElement,
                    defaultValue: parameter.defaultValue,
                    isSubscriptKey: parameter.isSubscriptKey
                )
            }
            self.asyncType = asyncType
            self.throwType = throwType
            self.returnType = returnType
            self.whereConstraints = whereConstraints
        }

        var description: String {
            description(parameters: parameters.map(\.description))
        }

        /// The signature as an override declares it, with the parameters' default values.
        var declarationDescription: String {
            description(parameters: parameters.map(\.declarationDescription))
        }

        private func description(parameters: [String]) -> String {
            let genericParametersString = genericParameters.map { $0.description }.joined(separator: ", ")
            let returnString: String? = if let returnType, !returnType.isVoid {
                "-> \(returnType.description)"
            } else {
                nil
            }
            let whereString = whereConstraints.isEmpty ? nil : "where \(whereConstraints.joined(separator: ", "))"
            return [
                genericParametersString.isEmpty ? nil : "<\(genericParametersString)>",
                "(\(parameters.joined(separator: ", ")))",
                asyncType?.description,
                throwType?.description,
                returnString,
                whereString,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }
    }
}

extension Method.Signature {
    /// The type names the sources declare, while their inheritance is merged: `Swift.Result` and `Result` differ
    /// when the sources declare a `Result` of their own.
    @TaskLocal static var declaredTypes: Set<String> = []

    /// The types a placeholder can stand for in the class whose requirements are being matched: `Self` is the class or
    /// a superclass, and an associated type the class names with a typealias is that typealias's type. A placeholder
    /// without an entry stands for any type.
    @TaskLocal static var placeholderTypes: [String: Set<String>] = [:]

    /// A type as `canonicalForm` writes it, without spaces and without a standard type's `Swift.`.
    static func canonicalType(_ text: String) -> String {
        let declared = declaredTypes
        return text.replacing(/\bSwift\.(\w+)/.wordBoundaryKind(.simple)) { match in
            declared.contains(String(match.output.1)) ? String(match.output.0) : String(match.output.1)
        }
        .filter { !$0.isWhitespace }
    }

    /// Whether a member with this signature implements a requirement with `requirement`'s: the same signature, with
    /// the same effects or fewer. A member that doesn't throw implements one that throws or rethrows, one that throws
    /// a typed error, `throws(ParseError)`, one that throws any error, and a synchronous one an `async` one.
    /// `placeholders` are the requirement's names that the member writes as concrete types, `Self` and the protocol's
    /// associated types: `func make() -> Int` implements `func make() -> Output`.
    func implements(_ requirement: Method.Signature, placeholders: Set<String> = []) -> Bool {
        // A typed throw throws fewer errors than an untyped one, `throws(any Error)` included. A bare `Error` may name
        // a type of the sources, so it doesn't count.
        let untyped: [ThrowType?] = [.throws(nil), .throws("any Error"), .throws("Swift.Error"), .throws("any Swift.Error")]
        let requirementThrowsAnyError = untyped.contains(requirement.throwType)
        // `throws` and `throws(any Error)` are one effect, however each side spells it.
        let throwsFewer = throwType == nil || throwType == requirement.throwType
            || (throwType?.isTyped == true || untyped.contains(throwType)) && requirementThrowsAnyError
        let isFewerAsync = asyncType == nil || asyncType == requirement.asyncType
        guard throwsFewer, isFewerAsync else { return false }
        let withRequirementsEffects = Method.Signature(
            genericParameters: genericParameters,
            parameters: parameters,
            asyncType: requirement.asyncType,
            throwType: requirement.throwType,
            returnType: returnType,
            whereConstraints: whereConstraints
        )
        return withRequirementsEffects.isApiEqual(to: requirement, placeholders: placeholders)
    }

    /// Whether the two declare the same requirement, however they spell it: generic parameters named differently,
    /// a constraint written in the parameter list or in a `where` clause, or a standard type qualified as `Swift.Int`.
    /// Each of `other`'s `placeholders`, as `Self.Output` or `Output`, stands for any type in this signature.
    func isApiEqual(to other: Method.Signature, placeholders: Set<String> = []) -> Bool {
        guard genericParameters.map(\.kind) == other.genericParameters.map(\.kind),
              parameters.count == other.parameters.count,
              asyncType == other.asyncType,
              throwType == other.throwType,
              parameters.elementsEqual(other.parameters, by: { $0.name == $1.name }) else { return false }
        let mine = canonicalForm, theirs = other.canonicalForm
        guard mine.constraints == theirs.constraints else { return false }
        // A generic parameter of the requirement's own shadows a placeholder of its name.
        let placeholders = placeholders.subtracting(other.genericParameters.map(\.name))
        guard !placeholders.isEmpty else { return mine.types == theirs.types }
        // Matched as one text, so a placeholder stands for one type wherever the requirement writes it.
        let separator: Character = "\u{1F}"
        var budget = PlaceholderMatcher.budget
        let allowed = Self.placeholderTypes
        return PlaceholderMatcher.matches(
            mine.types.joined(separator: String(separator))[...],
            PlaceholderMatcher.pattern(theirs.types.joined(separator: String(separator)), placeholders: placeholders)[...],
            bindings: [:],
            allowed: allowed,
            budget: &budget
        )
    }


    /// The parameters' and result's types and the generic constraints, with the generic parameters renamed by
    /// position and `Swift.` left out, and without spaces.
    private var canonicalForm: (types: [String], constraints: Set<String>) {
        // Renamed in the order the parameters' and result's types first use them, so `h<U, T>(a: T, b: U)` is
        // `h<T, U>(a: T, b: U)`; one they don't use keeps its place after them.
        let signatureText = (parameters.map(\.type.description) + [returnType?.description ?? ""]).joined(separator: ",")
        let names = genericParameters.map(\.name).sorted { first, second in
            let firstUse = signatureText.firstRange(of: Regex { Anchor.wordBoundary; first; Anchor.wordBoundary }.wordBoundaryKind(.simple))?.lowerBound
            let secondUse = signatureText.firstRange(of: Regex { Anchor.wordBoundary; second; Anchor.wordBoundary }.wordBoundaryKind(.simple))?.lowerBound
            switch (firstUse, secondUse) {
            case let (first?, second?): return first < second
            case (_?, nil): return true
            default: return false
            }
        }
        func canonical(_ text: String) -> String {
            var text = Self.canonicalType(text)
            for (index, name) in names.enumerated() {
                text = text.replacing(Regex { Anchor.wordBoundary; name; Anchor.wordBoundary }.wordBoundaryKind(.simple), with: "__G\(index)")
            }
            return text
        }
        let types = parameters.map { canonical($0.type.description) } + [returnType.map { canonical($0.description) } ?? "Void"]
        let constraints = genericParameters.flatMap { parameter in parameter.inheritedTypes.map { "\(parameter.name): \($0)" } } + whereConstraints
        return (types, Set(constraints.map(canonical)))
    }
}

extension Method.Signature {
    func containsType(named typeName: String) -> Bool {
        parameters.map(\.type)
            .contains(where: { $0.containsType(named: typeName) })
    }
    
    func containsTypes(named typeNames: [String]) -> Bool {
        typeNames.contains(where: { containsType(named: $0) })
    }
}

/// Matches a class member's types against a requirement's, where `Self` and the protocol's associated types stand for
/// the types the member writes.
private enum PlaceholderMatcher {
    enum Part: Equatable {
        case literal(Character)
        case placeholder(String)
    }

    /// The most steps a match takes before it gives up, so a contrived signature can't stall the generator: a
    /// requirement the match misses is declared again, as before placeholders were matched.
    static let budget = 10_000

    /// `pattern` as literal characters and a slot for each of `placeholders`, written alone or after `Self.`, with
    /// the member types it names, as `Output.Element`. A name after another type's, as `Other.Output`, is literal.
    static func pattern(_ pattern: String, placeholders: Set<String>) -> [Part] {
        func isIdentifier(_ character: Character) -> Bool { character.isLetter || character.isNumber || character == "_" }
        var parts: [Part] = []
        var rest = pattern[...]
        while let first = rest.first {
            guard first.isLetter || first == "_" else {
                parts.append(.literal(first))
                rest = rest.dropFirst()
                continue
            }
            let word = rest.prefix(while: isIdentifier)
            rest = rest.dropFirst(word.count)
            var name = String(word)
            let isMemberType = parts.last == .literal(".")
            if name == "Self", rest.first == ".", case let next = rest.dropFirst().prefix(while: isIdentifier),
               next != "Self", placeholders.contains(String(next)) {
                name = String(next)
                rest = rest.dropFirst(next.count + 1)
            }
            guard !isMemberType, placeholders.contains(name) else {
                parts += name.map(Part.literal)
                continue
            }
            // A member type of a placeholder's is a type the member writes as it likes too.
            var path = name
            while rest.first == ".", let next = rest.dropFirst().first, next.isLetter || next == "_" {
                let member = rest.dropFirst().prefix(while: isIdentifier)
                path += "." + member
                rest = rest.dropFirst(member.count + 1)
            }
            parts.append(.placeholder(path))
        }
        return parts
    }

    /// Whether `type` is `pattern` with one whole type in each slot, the same one for each placeholder: balanced
    /// brackets, no `,` or `:` outside them, and none of the member's generic parameters, which `canonicalForm` writes
    /// `__G0`.
    /// A placeholder with `allowed` types stands only for one of them, or for its own name.
    static func matches(
        _ type: Substring,
        _ pattern: ArraySlice<Part>,
        bindings: [String: Substring],
        allowed: [String: Set<String>],
        budget: inout Int
    ) -> Bool {
        budget -= 1
        guard budget > 0 else { return false }
        guard let first = pattern.first else { return type.isEmpty }
        switch first {
        case .literal(let character):
            return type.first == character && matches(type.dropFirst(), pattern.dropFirst(), bindings: bindings, allowed: allowed, budget: &budget)
        case .placeholder(let name):
            if let bound = bindings[name] {
                return type.hasPrefix(bound)
                    && matches(type.dropFirst(bound.count), pattern.dropFirst(), bindings: bindings, allowed: allowed, budget: &budget)
            }
            for candidate in wholeTypes(at: type) {
                if let types = allowed[name], candidate != name, !types.contains(String(candidate)) { continue }
                var bindings = bindings
                bindings[name] = candidate
                if matches(type.dropFirst(candidate.count), pattern.dropFirst(), bindings: bindings, allowed: allowed, budget: &budget) {
                    return true
                }
            }
            return false
        }
    }

    /// The prefixes of `text` that are a whole type, shortest first.
    private static func wholeTypes(at text: Substring) -> [Substring] {
        var prefixes: [Substring] = []
        var depth = 0
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            switch character {
            case "(", "[", "<": depth += 1
            case ")", "]", ">":
                // A `>` of `->` closes nothing.
                if character == ">", index > text.startIndex, text[text.index(before: index)] == "-" { break }
                depth -= 1
                if depth < 0 { return prefixes }
            case "\u{1F}": return prefixes
            case "," where depth == 0, ":" where depth == 0: return prefixes
            default: break
            }
            index = text.index(after: index)
            let prefix = text[..<index]
            if depth == 0, character != "-", !prefix.contains("__G") {
                prefixes.append(prefix)
            }
        }
        return prefixes
    }
}
