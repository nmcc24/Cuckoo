struct FileRepresentation: Sendable {
    let file: TextFile
    let imports: [Import]
    let tokens: [any Token]

    init(file: TextFile, imports: [Import], tokens: [any Token]) {
        self.file = file
        self.imports = imports
        self.tokens = tokens
    }

    func replacing(tokens: [any Token]) -> FileRepresentation {
        FileRepresentation(file: file, imports: imports, tokens: tokens)
    }
}

extension FileRepresentation {
    func mergingInheritance(with files: [FileRepresentation]) throws -> FileRepresentation {
        var mergedTokens: [any Token] = []
        for token in tokens {
            mergedTokens.append(try token.mergingInheritance(with: files))
        }
        return replacing(tokens: mergedTokens)
    }

    func flatMappingMemberContainers() -> FileRepresentation {
        replacing(tokens: tokens.flatMap { $0.flatMappingMemberContainers() })
    }
}

/// A parent type's name matches more than one declaration in the sources, and Swift's lookup from the inheriting
/// type doesn't settle which.
struct AmbiguousInheritanceError: Error, CustomStringConvertible {
    let declaration: String
    let parent: String
    let candidates: [String]

    var description: String {
        "'\(declaration)' inherits '\(parent)', which matches \(candidates.map { "'\($0)'" }.joined(separator: " and ")) in the "
            + "mocked sources. Write the parent's qualified name, such as '\(candidates[0])', so Cuckoo can tell which."
    }
}

extension Token {
    /// The class or protocol `name` refers to from inside `scope` (the inheriting type's qualified name), found as
    /// Swift would: in the type's enclosing scopes from the innermost outwards, then anywhere if only one declaration
    /// has the name. A name written qualified, `Outer.Service`, matches that declaration.
    private static func findToken(forClassOrProtocol name: String, from scope: String, in files: [FileRepresentation]) throws -> (any Token)? {
        let candidates = files
            .flatMap(\.tokens)
            .filter { $0.isClass || $0.isProtocol }
            .compactMap { $0 as? any Token & HasName }
        var enclosingScopes = scope.split(separator: ".").map(String.init)
        while true {
            enclosingScopes.removeLast()
            let qualifiedName = (enclosingScopes + [name]).joined(separator: ".")
            if let match = candidates.first(where: { $0.fullyQualifiedName == qualifiedName }) {
                return match
            }
            if enclosingScopes.isEmpty { break }
        }
        let matching = candidates.filter { $0.fullyQualifiedName.hasSuffix("." + name) }
        guard matching.count <= 1 else {
            throw AmbiguousInheritanceError(declaration: scope, parent: name, candidates: matching.map(\.fullyQualifiedName).sorted())
        }
        return matching.first
    }

    fileprivate func mergingInheritance(with files: [FileRepresentation]) throws -> any Token {
        guard let token = self as? any Token & HasMembers & HasInheritance & HasName else { return self }

        // A protocol bound to a class doesn't take the class's members: the mock subclasses the class instead.
        // A protocol's parent can be written with its primary associated types, as `Parent<String>`.
        let inheritedRepresentations = try token.inheritedTypes
            .compactMap { try Self.findToken(forClassOrProtocol: token.isProtocol ? $0.withoutGenericArguments : $0, from: token.fullyQualifiedName, in: files) }
            .filter { !(token.isProtocol && $0.isClass) }
            .map { try $0.mergingInheritance(with: files) }

        let mergedTokens = inheritedRepresentations
            .compactMap { $0 as? any HasMembers }
            .flatMap { $0.members }
            .reduce(token.members) { tokens, inheritedToken in
                guard let inheritedInheritable = inheritedToken as? any Inheritable else {
                    return tokens + [inheritedToken]
                }

                let isAlreadyPresent = tokens.compactMap({ $0 as? any Inheritable }).contains(where: { $0.isEqual(to: inheritedInheritable) })

                return isAlreadyPresent || !inheritedInheritable.isInheritable ? tokens : tokens + [inheritedToken]
            }

        switch token {
        case let classToken as ClassDeclaration:
            return classToken.replacing(members: mergedTokens)
        case let protocolToken as ProtocolDeclaration:
            let parents = inheritedRepresentations.compactMap { $0 as? ProtocolDeclaration }.map { parent in
                (declaration: parent, arguments: protocolToken.inheritedTypes.first { $0.withoutGenericArguments == parent.name }?.genericArguments ?? [])
            }
            let merged = protocolToken.replacing(members: mergedTokens).inheritingAssociatedTypes(from: parents)
            // Every member, inherited ones included, belongs to this protocol now: its mock is the one they're
            // generated into, and its isolation, which may come from a parent, is the one they take.
            let reference = Reference<any Token>(merged.replacing(members: []))
            return merged.replacing(members: merged.members.map { member in
                var member = member
                member.parent = reference
                return member
            })
        default:
            assertionFailure("This case should not be possible.")
            return token
        }
    }
}

extension Token {
    fileprivate func flatMappingMemberContainers() -> [any Token] {
        guard let selfHasMembers = self as? any HasMembers else { return [self] }
        return [self] + selfHasMembers.members.flatMap { token in
            if let hasMembers = token as? any HasMembers {
                return hasMembers.flatMappingMemberContainers()
            } else {
                return []
            }
        }
    }
}
