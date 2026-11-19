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

    /// The names of a requirement that a class's member may write as other types. See `Inheritable.placeholders`.
    struct Placeholders: Sendable {
        /// `Self` and the protocol's associated types.
        var names: Set<String> = []
        /// The protocol's typealiases, by name, with the types they stand for.
        var aliases: [String: String] = [:]
    }

    /// The types a placeholder can stand for in the class whose requirements are being matched: `Self` is the class or
    /// a superclass, and an associated type the class names with a typealias is that typealias's type. A placeholder
    /// without an entry stands for any type.
    @TaskLocal static var placeholderTypes: [String: Set<String>] = [:]

    /// Every order of `elements`, the given one first.
    private static func permutations(of elements: [String]) -> [[String]] {
        guard elements.count > 1 else { return [elements] }
        return elements.indices.flatMap { index in
            var rest = elements
            let first = rest.remove(at: index)
            return permutations(of: rest).map { [first] + $0 }
        }
    }

    /// A type as `canonicalForm` writes it, without spaces and without a standard type's `Swift.`, and, in a class's
    /// merge, with the class's typealiases written as what they stand for unless `expandingClassTypealiases` is false,
    /// as for a protocol's requirement, whose names aren't the class's.
    static func canonicalType(_ text: String, expandingClassTypealiases: Bool = true) -> String {
        let declared = declaredTypes
        let text = text.replacing(/\bSwift\.(\w+)/.wordBoundaryKind(.simple)) { match in
            declared.contains(String(match.output.1)) ? String(match.output.0) : String(match.output.1)
        }
        .filter { !$0.isWhitespace }
        return normalized(text, aliases: expandingClassTypealiases ? classTypealiases : [:])
    }

    /// The typealiases of the class whose members are being matched, and of its superclasses, with the types they
    /// stand for: `put(_ k: Name)` with `typealias Name = String` is `put(_ k: String)`. Empty outside a class's merge.
    @TaskLocal static var classTypealiases: [String: String] = [:]

    /// `text`, without spaces, with `Optional<X>`, `Array<X>` and `Dictionary<K, V>` written `X?`, `[X]` and `[K: V]`,
    /// and each of `aliases`, not after a `.`, written as what it stands for.
    private static func normalized(_ text: String, aliases: [String: String], depth: Int = 0) -> String {
        func isIdentifier(_ character: Character) -> Bool { character.isLetter || character.isNumber || character == "_" }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character.isLetter || character == "_", result.last.map({ $0 != "." && !isIdentifier($0) }) ?? true else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            var word = String(text[index...].prefix(while: isIdentifier))
            index = text.index(index, offsetBy: word.count)
            // `Self.Output` names the class's typealias as `Output` does.
            if word == "Self", index < text.endIndex, text[index] == ".",
               case let next = String(text[text.index(after: index)...].prefix(while: isIdentifier)), aliases[next] != nil {
                word = next
                index = text.index(index, offsetBy: next.count + 1)
            }
            let isGeneric = index < text.endIndex && text[index] == "<"
            if !isGeneric, depth < 4, let original = aliases[word] {
                result += normalized(original.filter { !$0.isWhitespace }, aliases: aliases, depth: depth + 1)
                continue
            }
            // A type of the sources' named like one of them isn't the standard library's.
            guard isGeneric, ["Optional", "Array", "Dictionary"].contains(word), !declaredTypes.contains(word),
                  let (arguments, end) = genericArguments(in: text, opening: index) else {
                result += word
                continue
            }
            let parts = arguments.map { normalized($0, aliases: aliases, depth: depth) }
            switch (word, parts.count) {
            case ("Optional", 1):
                // A function, composed or existential type is wrapped, as `(() -> Void)?`.
                let wrapped = parts[0].contains("->") || parts[0].contains("&") || parts[0].hasPrefix("any") || parts[0].hasPrefix("some")
                result += wrapped ? "(\(parts[0]))?" : "\(parts[0])?"
            case ("Array", 1):
                result += "[\(parts[0])]"
            case ("Dictionary", 2):
                result += "[\(parts[0]):\(parts[1])]"
            default:
                result += word + "<" + parts.joined(separator: ",") + ">"
            }
            index = end
        }
        return result
    }

    /// The top-level generic arguments of the `<` at `opening`, and the index after its `>`.
    private static func genericArguments(in text: String, opening: String.Index) -> (arguments: [String], end: String.Index)? {
        var depth = 0
        var arguments: [String] = []
        var current = ""
        var index = opening
        while index < text.endIndex {
            let character = text[index]
            let isArrow = character == ">" && index > text.startIndex && text[text.index(before: index)] == "-"
            switch character {
            case "<", "(", "[":
                depth += 1
                if depth > 1 { current.append(character) }
            case ">" where !isArrow, ")", "]":
                depth -= 1
                if depth == 0 {
                    arguments.append(current)
                    return (arguments, text.index(after: index))
                }
                current.append(character)
            case "," where depth == 1:
                arguments.append(current)
                current = ""
            default:
                current.append(character)
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// Whether a member with this signature implements a requirement with `requirement`'s: the same signature, with
    /// the same effects or fewer. A member that doesn't throw implements one that throws or rethrows, one that throws
    /// a typed error, `throws(ParseError)`, one that throws any error, and a synchronous one an `async` one.
    /// `placeholders` are the requirement's names that the member writes as concrete types, `Self` and the protocol's
    /// associated types: `func make() -> Int` implements `func make() -> Output`.
    func implements(_ requirement: Method.Signature, placeholders: Placeholders = .init()) -> Bool {
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
    /// Each of `other`'s `placeholders`, as `Self.Output` or `Output`, stands for a type in this signature, in its
    /// `where` clause too.
    func isApiEqual(to other: Method.Signature, placeholders: Placeholders = .init()) -> Bool {
        guard genericParameters.map(\.kind) == other.genericParameters.map(\.kind),
              parameters.count == other.parameters.count,
              asyncType == other.asyncType,
              throwType == other.throwType,
              parameters.elementsEqual(other.parameters, by: { $0.name == $1.name }) else { return false }
        // A protocol's requirement, with its placeholders, is written with the protocol's names, not the class's.
        let mine = canonicalForm(expandingClassTypealiases: true)
        let theirs = other.canonicalForm(expandingClassTypealiases: placeholders.names.isEmpty)
        // A generic parameter of the requirement's own shadows a placeholder of its name.
        let shadowed = Set(other.genericParameters.map(\.name))
        let placeholders = Placeholders(
            names: placeholders.names.subtracting(shadowed),
            aliases: placeholders.aliases.filter { !shadowed.contains($0.key) }
        )
        guard !placeholders.names.isEmpty || !placeholders.aliases.isEmpty else {
            return mine.types == theirs.types && mine.constraints == theirs.constraints
        }
        guard mine.constraints.count == theirs.constraints.count else { return false }
        // The constraints are in the order of what they constrain, `__G0.Element == Key` matching
        // `__G0.Element == String` when they're the only constraints on `__G0.Element`.
        func ordered(_ constraints: Set<String>) -> [String] {
            constraints.sorted { first, second in
                let firstSide = first.prefix { $0 != ":" && $0 != "=" }, secondSide = second.prefix { $0 != ":" && $0 != "=" }
                return firstSide == secondSide ? first < second : firstSide < secondSide
            }
        }
        // Matched as one text, so a placeholder stands for one type wherever the requirement writes it.
        let separator: Character = "\u{1F}"
        let allowed = Self.placeholderTypes
        let pattern = PlaceholderMatcher.pattern(
            (theirs.types + ordered(theirs.constraints)).joined(separator: String(separator)),
            placeholders: placeholders
        )
        // A placeholder on a constraint's left side, as `Key == T.Element`, can sort it apart from the member's: a few
        // constraints are tried in every order.
        let orders = mine.constraints.count <= 4 ? Self.permutations(of: ordered(mine.constraints)) : [ordered(mine.constraints)]
        // Each order has a budget of its own, so the ones that fail don't use up the right one's.
        return orders.contains { constraints in
            var budget = PlaceholderMatcher.budget
            return PlaceholderMatcher.matches(
                (mine.types + constraints).joined(separator: String(separator))[...],
                pattern[...],
                bindings: [:],
                allowed: allowed,
                budget: &budget
            )
        }
    }


    /// The parameters' and result's types and the generic constraints, with the generic parameters renamed by
    /// position and `Swift.` left out, and without spaces.
    private func canonicalForm(expandingClassTypealiases: Bool) -> (types: [String], constraints: Set<String>) {
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
        // The generic parameters first, so a class's typealias of a generic parameter's name doesn't replace it.
        func canonical(_ text: String) -> String {
            var text = text
            for (index, name) in names.enumerated() {
                text = text.replacing(Regex { Anchor.wordBoundary; name; Anchor.wordBoundary }.wordBoundaryKind(.simple), with: "__G\(index)")
            }
            return Self.canonicalType(text, expandingClassTypealiases: expandingClassTypealiases)
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
/// the types the member writes, and the protocol's typealiases for what they stand for.
private enum PlaceholderMatcher {
    enum Part: Equatable {
        case literal(Character)
        /// A placeholder, with the member types it names after it, as `.Element` in `Output.Element`.
        case placeholder(root: String, path: String)
        /// A typealias written as it is or as what it stands for.
        case choice([[Part]])
    }

    /// The most steps a match takes before it gives up, so a contrived signature can't stall the generator: a
    /// requirement the match misses is declared again, as before placeholders were matched.
    static let budget = 10_000

    /// `text` as literal characters, a slot for each placeholder, written alone or after `Self.`, with the member
    /// types it names, and a choice for each typealias. A name after another type's, as `Other.Output`, is literal.
    static func pattern(_ text: String, placeholders: Method.Signature.Placeholders, depth: Int = 0) -> [Part] {
        func isIdentifier(_ character: Character) -> Bool { character.isLetter || character.isNumber || character == "_" }
        let names = placeholders.names
        var parts: [Part] = []
        var rest = text[...]
        while let first = rest.first {
            guard first.isLetter || first == "_" else {
                parts.append(.literal(first))
                rest = rest.dropFirst()
                continue
            }
            let word = rest.prefix(while: isIdentifier)
            rest = rest.dropFirst(word.count)
            var name = String(word)
            var written = name
            let isMemberType = parts.last == .literal(".")
            if name == "Self", rest.first == ".", case let next = String(rest.dropFirst().prefix(while: isIdentifier)),
               next != "Self", names.contains(next) || placeholders.aliases[next] != nil {
                name = next
                written = "Self." + next
                rest = rest.dropFirst(next.count + 1)
            }
            if !isMemberType, let original = placeholders.aliases[name], !names.contains(name), depth < 4 {
                // Written as the protocol writes it, or as what it stands for, itself matched with the placeholders.
                let expansion = pattern(
                    Method.Signature.canonicalType(original, expandingClassTypealiases: false),
                    placeholders: placeholders,
                    depth: depth + 1
                )
                parts.append(.choice([written.map(Part.literal), name.map(Part.literal), expansion]))
                continue
            }
            guard !isMemberType, names.contains(name) else {
                parts += written.map(Part.literal)
                continue
            }
            var path = ""
            while rest.first == ".", let next = rest.dropFirst().first, next.isLetter || next == "_" {
                let member = rest.dropFirst().prefix(while: isIdentifier)
                path += "." + member
                rest = rest.dropFirst(member.count + 1)
            }
            parts.append(.placeholder(root: name, path: path))
        }
        return parts
    }

    /// Whether `type` is `pattern` with one whole type in each slot: balanced brackets, no `,` or `:` outside them,
    /// and none of the member's generic parameters, which `canonicalForm` writes `__G0`.
    ///
    /// A placeholder with `allowed` types, `Self` or an associated type the class names with a typealias, stands for
    /// its own name or one of them, as `Output` or `Int`, and as a metatype, `Output.Type`, for one of those followed by
    /// `.Type`. Any other placeholder stands for the same type wherever the requirement writes it.
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
        let rest = pattern.dropFirst()
        switch first {
        case .literal(let character):
            return type.first == character && matches(type.dropFirst(), rest, bindings: bindings, allowed: allowed, budget: &budget)
        case .choice(let alternatives):
            return alternatives.contains { alternative in
                matches(type, alternative[...] + rest, bindings: bindings, allowed: allowed, budget: &budget)
            }
        case .placeholder(let root, let path):
            // A metatype, `Output.Type`, is the allowed type's; another member type, as `Output.Element`, is one the
            // generator can't work out, so it's bound as an unnamed placeholder's is.
            if let types = allowed[root], path.isEmpty || path == ".Type" || path == ".Protocol" {
                let spellings = Set((types + [root]).map { $0 + path })
                return wholeTypes(at: type).contains { candidate in
                    spellings.contains(String(candidate))
                        && matches(type.dropFirst(candidate.count), rest, bindings: bindings, allowed: allowed, budget: &budget)
                }
            }
            let key = root + path
            if let bound = bindings[key] {
                return type.hasPrefix(bound)
                    && matches(type.dropFirst(bound.count), rest, bindings: bindings, allowed: allowed, budget: &budget)
            }
            return wholeTypes(at: type).contains { candidate in
                var bindings = bindings
                bindings[key] = candidate
                return matches(type.dropFirst(candidate.count), rest, bindings: bindings, allowed: allowed, budget: &budget)
            }
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
