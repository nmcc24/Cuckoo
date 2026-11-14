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
    func mergingInheritance(with files: [FileRepresentation], names: TypeNames) -> FileRepresentation {
        replacing(tokens: tokens.map { $0.mergingInheritance(with: files, names: names) })
    }

    func flatMappingMemberContainers() -> FileRepresentation {
        replacing(tokens: tokens.flatMap { $0.flatMappingMemberContainers() })
    }
}

/// What the module's sources declare that changes how a type name is read: its typealiases of other types, by
/// qualified name (`Outer.Alias`, or `Alias` at the top level), and the names of its types.
struct TypeNames: Sendable {
    var typealiases: [String: String] = [:]
    var types: Set<String> = []
    /// The sources' classes and protocols by canonical qualified name, the first of a name; see `indexing(_:)`.
    private var declarations: [String: any Token & HasName] = [:]

    init(typealiases: [String: String] = [:], types: Set<String> = []) {
        self.typealiases = typealiases
        self.types = types
    }

    /// These names, with the classes and protocols of `files` indexed for ``declaration(named:)``.
    func indexing(_ files: [FileRepresentation]) -> TypeNames {
        var indexed = self
        for token in files.flatMap(\.tokens) where token.isClass || token.isProtocol {
            guard let named = token as? any Token & HasName else { continue }
            let name = canonical(named.fullyQualifiedName)
            if indexed.declarations[name] == nil {
                indexed.declarations[name] = named
            }
        }
        return indexed
    }

    /// The class or protocol declared with the qualified name, as Swift reads it.
    func declaration(named qualifiedName: String) -> (any Token & HasName)? {
        declarations[canonical(qualifiedName)]
    }

    /// `name` as Swift reads it: a typealias of a type replaced by the type, and a leading component that names
    /// no declared type, a module's name as in `extension App.Outer`, left out.
    func canonical(_ name: String) -> String {
        var components = name.split(separator: ".").map(String.init)
        for _ in 0..<8 {
            if components.count > 1, !types.contains(components[0]), types.contains(components[1]) {
                components.removeFirst()
                continue
            }
            // The longest prefix that's a typealias stands for its type.
            guard let length = (1...max(components.count, 1)).reversed().first(where: { typealiases[components.prefix($0).joined(separator: ".")] != nil }),
                  let target = typealiases[components.prefix(length).joined(separator: ".")] else { break }
            components = target.split(separator: ".").map(String.init) + components.dropFirst(length)
        }
        return components.joined(separator: ".")
    }
}

extension Token {
    /// The class or protocol `name` refers to from inside `scope` (the inheriting type's qualified name), found as
    /// Swift would: in the type's enclosing scopes from the innermost outwards, through typealiases. A name written
    /// qualified, `Outer.Service`, matches that declaration. Nil means it's declared outside the sources, as
    /// Swift's own `Error` is, even when a protocol nested elsewhere has the same name.
    private static func findToken(forClassOrProtocol name: String, from scope: String, names: TypeNames) -> (any Token)? {
        var enclosingScopes = names.canonical(scope).split(separator: ".").map(String.init)
        while true {
            enclosingScopes.removeLast()
            if let match = names.declaration(named: (enclosingScopes + [name]).joined(separator: ".")) {
                return match
            }
            // A class's scope also holds what its superclasses declare: `class Child: Base` sees `Base.Delegate`.
            if !enclosingScopes.isEmpty,
               let enclosingClass = names.declaration(named: enclosingScopes.joined(separator: ".")) as? ClassDeclaration,
               let match = member(named: name, ofSuperclassesOf: enclosingClass, names: names, depth: 0) {
                return match
            }
            if enclosingScopes.isEmpty { break }
        }
        return nil
    }

    /// The class or protocol `name` declared in one of `subclass`'s superclasses, nearest first: their members
    /// only, not the scopes they're declared in, which Swift doesn't search from the subclass.
    private static func member(named name: String, ofSuperclassesOf subclass: ClassDeclaration, names: TypeNames, depth: Int) -> (any Token)? {
        guard depth < 16 else { return nil }
        for superclassName in subclass.inheritedTypes {
            guard let superclass = findToken(forClassOrProtocol: superclassName.withoutGenericArguments, from: subclass.fullyQualifiedName, names: names) as? ClassDeclaration else { continue }
            if let match = names.declaration(named: superclass.fullyQualifiedName + "." + name)
                ?? member(named: name, ofSuperclassesOf: superclass, names: names, depth: depth + 1) {
                return match
            }
        }
        return nil
    }

    fileprivate func mergingInheritance(with files: [FileRepresentation], names: TypeNames) -> any Token {
        guard let token = self as? any Token & HasMembers & HasInheritance & HasName else { return self }

        // A protocol bound to a class doesn't take the class's members: the mock subclasses the class instead.
        // A protocol's parent can be written with its primary associated types, as `Parent<String>`.
        let inheritedRepresentations = token.inheritedTypes
            .compactMap { Self.findToken(forClassOrProtocol: token.isProtocol ? $0.withoutGenericArguments : $0, from: token.fullyQualifiedName, names: names) }
            .filter { !(token.isProtocol && $0.isClass) }
            .map { $0.mergingInheritance(with: files, names: names) }

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
            var merged = protocolToken.replacing(members: mergedTokens).inheritingAssociatedTypes(from: parents)
            // A parent that isn't found by scope is declared outside the sources, even if a protocol nested
            // elsewhere has its name; the crawler, which saw names only, couldn't tell.
            merged.parentsOutsideSources = protocolToken.inheritedTypes.filter { parent in
                let name = parent.withoutGenericArguments
                return !Crawler.parentsWithoutRequirements.contains(String(name.split(separator: ".").last ?? ""))
                    && Self.findToken(forClassOrProtocol: name, from: protocolToken.fullyQualifiedName, names: names) == nil
            }
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
