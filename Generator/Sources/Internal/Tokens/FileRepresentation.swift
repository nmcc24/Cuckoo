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
    /// - Parameter defaultIsolation: The module's default isolation, under which Swift infers a witness's isolation
    ///   in a `nonisolated` class.
    func mergingInheritance(with files: [FileRepresentation], names: TypeNames, defaultIsolation: Isolation? = nil) -> FileRepresentation {
        replacing(tokens: tokens.map { $0.mergingInheritance(with: files, names: names, defaultIsolation: defaultIsolation, merging: []) })
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
    /// The sources' classes and protocols by canonical qualified name, the first of a name.
    private var declarations: [String: any Token & HasName] = [:]
    /// The sources' classes and protocols by the qualified name they're declared with.
    private var qualifiedDeclarations: Set<String> = []
    /// The modules the sources import, and Swift's own, but not the sources' own modules: a name qualified with one,
    /// as `Swift.Error`, is declared outside the sources, even when the sources declare a type of the same name.
    private var importedModules: Set<String> = ["Swift", "_Concurrency"]
    /// What the sources' extensions declare for each type, by its canonical qualified name; see
    /// `NamespaceDeclaration.extensionMembers`.
    private var extensionMembers: [String: [any Token]] = [:]
    /// See `NamespaceDeclaration.overridableExtensionMembers`.
    private var overridableExtensionMembers: [String: [any Token]] = [:]
    /// See `NamespaceDeclaration.extensionConformances`.
    private var extensionConformances: [String: [String]] = [:]

    /// The names, with the classes and protocols of `files`, flattened so nested ones are listed, indexed for
    /// ``declaration(named:)`` and ``resolve(_:from:)``.
    /// - Parameter sourceModules: the Swift modules the sources belong to, which one source file can import from
    ///   another, as `import Core` in an entry with `Core` and `App` sources.
    init(typealiases: [String: String] = [:], types: Set<String> = [], files: [FileRepresentation], sourceModules: Set<String> = []) {
        self.typealiases = typealiases
        self.types = types
        qualifiedDeclarations = Set(files.flatMap(\.tokens).compactMap { ($0 as? any Token & HasName)?.fullyQualifiedName })
        for file in files {
            for module in file.imports {
                switch module.target {
                case .library(let name): importedModules.insert(name)
                case .component(_, let name): importedModules.insert(String(name.split(separator: ".").first ?? ""))
                }
            }
        }
        importedModules.subtract(sourceModules)
        for token in files.flatMap(\.tokens) where token.isClass || token.isProtocol {
            guard let named = token as? any Token & HasName else { continue }
            let name = canonical(named.fullyQualifiedName)
            if declarations[name] == nil {
                declarations[name] = named
            }
        }
        for case let namespace as NamespaceDeclaration in files.flatMap(\.tokens) {
            extensionMembers[canonical(namespace.fullyQualifiedName), default: []] += namespace.extensionMembers
            extensionConformances[canonical(namespace.fullyQualifiedName), default: []] += namespace.extensionConformances
            // A member keeps the isolation its extension states, which the class it moves to doesn't have.
            overridableExtensionMembers[canonical(namespace.fullyQualifiedName), default: []] += namespace.overridableExtensionMembers.map { member in
                namespace.memberIsolation.map { member.withDefaultIsolation($0) } ?? member
            }
        }
    }

    /// The members the sources' extensions declare for the type with the qualified name.
    func extensionMembers(of qualifiedName: String) -> [any Token] {
        extensionMembers[canonical(qualifiedName)] ?? []
    }

    /// The protocols the sources' extensions of the type with the qualified name make it conform to.
    func extensionConformances(of qualifiedName: String) -> [String] {
        extensionConformances[canonical(qualifiedName)] ?? []
    }

    /// The `@objc` members the extensions of a class and of its superclasses in the sources declare,
    /// which a mock overrides. A superclass outside the sources ends the chain.
    func overridableExtensionMembers(of classDeclaration: ClassDeclaration) -> [any Token] {
        var members: [any Token] = []
        var seen: Set<String> = []
        var current: ClassDeclaration? = classDeclaration
        while let declaration = current, seen.insert(declaration.fullyQualifiedName).inserted {
            members += overridableExtensionMembers[canonical(declaration.fullyQualifiedName)] ?? []
            current = declaration.inheritedTypes.first.flatMap {
                resolve($0.withoutGenericArguments, from: declaration.fullyQualifiedName) as? ClassDeclaration
            }
        }
        return members
    }

    /// The members of a class and of its superclasses in the sources that no mock can override: the `static` and
    /// `final` ones and those their extensions declare. A superclass outside the sources ends the chain.
    func hidingMembers(of classDeclaration: ClassDeclaration) -> [any Token] {
        var members: [any Token] = []
        var seen: Set<String> = []
        var current: ClassDeclaration? = classDeclaration
        while let declaration = current, seen.insert(declaration.fullyQualifiedName).inserted {
            members += declaration.shadowedMembers + extensionMembers(of: declaration.fullyQualifiedName)
            // Only the first inherited type can be the superclass; a generic one is found without its arguments.
            current = declaration.inheritedTypes.first.flatMap {
                resolve($0.withoutGenericArguments, from: declaration.fullyQualifiedName) as? ClassDeclaration
            }
        }
        return members
    }

    /// The class or protocol declared with the qualified name, as Swift reads it.
    func declaration(named qualifiedName: String) -> (any Token & HasName)? {
        declarations[canonical(qualifiedName)]
    }

    /// `name` as Swift reads it: a typealias of a type replaced by the type, and a leading component that names
    /// no declared type, the sources' module's name as in `extension App.Outer`, left out. An imported module's
    /// name stays, so `Swift.Error` names no declaration.
    func canonical(_ name: String) -> String {
        var components = name.split(separator: ".").map(String.init)
        for _ in 0..<8 {
            if components.count > 1, !types.contains(components[0]), !importedModules.contains(components[0]), types.contains(components[1]) {
                components.removeFirst()
                continue
            }
            // The longest prefix that's a typealias stands for its type.
            guard let length = (1...max(components.count, 1)).reversed().first(where: { typealiases[components.prefix($0).joined(separator: ".")] != nil }),
                  let target = typealiases[components.prefix(length).joined(separator: ".")] else { break }
            // The target is written in the typealias's scope: `typealias S = Service` in `Feature` is `Feature.Service`.
            let aliasScope = Array(components.prefix(length - 1))
            let targetComponents = target.split(separator: ".").map(String.init)
            let scoped = stride(from: aliasScope.count, through: 1, by: -1)
                .map { Array(aliasScope.prefix($0)) + targetComponents }
                .first { qualifiedDeclarations.contains($0.joined(separator: ".")) }
            components = (scoped ?? targetComponents) + components.dropFirst(length)
        }
        return components.joined(separator: ".")
    }

    /// The class or protocol `name` refers to from inside `scope` (the inheriting type's qualified name), found as
    /// Swift would: in the type's enclosing scopes from the innermost outwards, through typealiases. A name written
    /// qualified, `Outer.Service`, matches that declaration. Nil means it's declared outside the sources, as
    /// Swift's own `Error` is, even when a protocol nested elsewhere has the same name.
    /// A type never inherits from itself: a name that would resolve to `scope`'s own declaration, which Swift
    /// rejects or reads as an outside type of the same name, resolves to nil.
    func resolve(_ name: String, from scope: String, depth: Int = 0) -> (any Token)? {
        let ownName = canonical(scope)
        var enclosingScopes = ownName.split(separator: ".").map(String.init)
        // Invalid source can declare a type without a name.
        guard !enclosingScopes.isEmpty else { return nil }
        while true {
            enclosingScopes.removeLast()
            if let match = declaration(named: (enclosingScopes + [name]).joined(separator: ".")), canonical(match.fullyQualifiedName) != ownName {
                return match
            }
            // A class's scope also holds what its superclasses declare: `class Child: Base` sees `Base.Delegate`.
            if !enclosingScopes.isEmpty,
               let enclosingClass = declaration(named: enclosingScopes.joined(separator: ".")) as? ClassDeclaration,
               let match = member(named: name, ofSuperclassesOf: enclosingClass, depth: depth) {
                return match
            }
            if enclosingScopes.isEmpty { break }
        }
        return nil
    }

    /// The class or protocol `name` declared in one of `subclass`'s superclasses, nearest first: their members
    /// only, not the scopes they're declared in, which Swift doesn't search from the subclass.
    private func member(named name: String, ofSuperclassesOf subclass: ClassDeclaration, depth: Int) -> (any Token)? {
        guard depth < 16 else { return nil }
        for superclassName in subclass.inheritedTypes {
            // The depth carries through, so a class that inherits from itself, which Swift rejects, ends the search.
            guard let superclass = resolve(superclassName.withoutGenericArguments, from: subclass.fullyQualifiedName, depth: depth + 1) as? ClassDeclaration else { continue }
            if let match = declaration(named: superclass.fullyQualifiedName + "." + name)
                ?? member(named: name, ofSuperclassesOf: superclass, depth: depth + 1) {
                return match
            }
        }
        return nil
    }
}

extension Token {
    /// `merging` holds the types whose inheritance is being merged, outermost first: a cycle, which Swift rejects,
    /// ends at the type that closes it.
    fileprivate func mergingInheritance(with files: [FileRepresentation], names: TypeNames, defaultIsolation: Isolation?, merging: Set<String>) -> any Token {
        guard let token = self as? any Token & HasMembers & HasInheritance & HasName,
              !merging.contains(token.fullyQualifiedName) else { return self }
        let merging = merging.union([token.fullyQualifiedName])

        // A protocol bound to a class doesn't take the class's members: the mock subclasses the class instead.
        // A protocol's parent can be written with its primary associated types, as `Parent<String>`.
        // A class also adopts the protocols its `@objc` extensions declare, as `@objc extension Base: Ringing`; a
        // subclass inherits them through its merged superclass.
        let representations = { (types: [String]) in
            types
                .compactMap { names.resolve(token.isProtocol ? $0.withoutGenericArguments : $0, from: token.fullyQualifiedName) }
                .filter { !(token.isProtocol && $0.isClass) }
                .map { $0.mergingInheritance(with: files, names: names, defaultIsolation: defaultIsolation, merging: merging) }
        }
        let statedRepresentations = representations(token.inheritedTypes)
        let inheritedRepresentations = statedRepresentations
            + representations(token.isClass ? names.extensionConformances(of: token.fullyQualifiedName) : [])

        let hidingMembers = (token as? ClassDeclaration).map { names.hidingMembers(of: $0) } ?? []
        // A requirement an `@objc` extension member implements is that member, which the class's mock overrides.
        let classReference = (token as? ClassDeclaration).map { Reference<any Token>($0.replacing(members: [])) }
        let overridableMembers = (token as? ClassDeclaration).map { names.overridableExtensionMembers(of: $0) } ?? []
        let mergedTokens = inheritedRepresentations
            .compactMap { $0 as? any HasMembers }
            .flatMap { $0.members }
            .reduce(token.members) { tokens, inheritedToken in
                guard let inheritedInheritable = inheritedToken as? any Inheritable else {
                    return tokens + [inheritedToken]
                }

                // A `final` or unavailable override hides the superclass's member as an override the mock has does,
                // and a `static` or `final` member, or one an extension declares, the requirement it implements,
                // whether the class or a superclass has it.
                // In a class, a member implements a protocol's requirement with more effects too, as a non-throwing
                // one a throwing one, and the class's own override a superclass's member; a superclass's `async`
                // overload of a sync member stays its own. Among protocols, each is a requirement of its own.
                let isRequirement = inheritedToken.parent?.value is ProtocolDeclaration
                let ownMembers = token.members.compactMap { $0 as? any Inheritable }
                let isAlreadyPresent = (tokens + hidingMembers)
                    .compactMap({ $0 as? any Inheritable })
                    .contains(where: { candidate in
                        if candidate.isEqual(to: inheritedInheritable) { return true }
                        guard token is ClassDeclaration, candidate.implements(inheritedInheritable) else { return false }
                        let candidateIsRequirement = (candidate as? any Token)?.parent?.value is ProtocolDeclaration
                        if isRequirement { return !candidateIsRequirement }
                        return ownMembers.contains { $0.isEqual(to: candidate) }
                            && !inheritedRepresentations.compactMap({ $0 as? any HasMembers }).flatMap(\.members)
                                .contains { ($0 as? any Inheritable)?.isEqual(to: candidate) == true }
                    })

                guard !isAlreadyPresent, inheritedInheritable.isInheritable else { return tokens }
                if var overridable = overridableMembers.first(where: { ($0 as? any Inheritable)?.implements(inheritedInheritable) == true }) {
                    overridable.parent = classReference
                    return tokens + [overridable]
                }
                return tokens + [inheritedToken]
            }

        switch token {
        case let classToken as ClassDeclaration:
            var merged = classToken.replacing(members: mergedTokens)
            // A generic superclass's members name its generic parameters, which the mock would have to replace with
            // the arguments the class gives them: they're left to the real implementation, and the mock says so.
            if let superclassName = classToken.inheritedTypes.first(where: { $0.contains("<") }),
               names.resolve(superclassName, from: classToken.fullyQualifiedName) == nil,
               let superclass = names.resolve(superclassName.withoutGenericArguments, from: classToken.fullyQualifiedName) as? ClassDeclaration {
                let members = superclass.members.compactMap { member -> String? in
                    switch member {
                    case let method as Method: "\(method.name)(\(method.signature.parameters.map { "\($0.name):" }.joined()))"
                    case let variable as Variable: variable.name
                    case is Subscript: "subscript"
                    default: nil
                    }
                }
                if !members.isEmpty {
                    merged.unmockedGenericSuperclass = (superclassName, members)
                    merged.unmockedMembers.append("\(members.map { "'\($0)'" }.joined(separator: ", ")), inherited from the generic superclass '\(superclassName)'.")
                }
            }
            // A subclass takes its superclass's stated isolation, as Swift infers it, over the module's default.
            if classToken.isIsolationDefault,
               let superclass = inheritedRepresentations.lazy.compactMap({ $0 as? ClassDeclaration }).first,
               !superclass.isIsolationDefault {
                merged.isolation = superclass.isolation
                merged.isIsolationDefault = false
                // The class's own members read its isolation through their parent.
                let reference = Reference<any Token>(merged.replacing(members: []))
                merged = merged.replacing(members: merged.members.map { member in
                    guard (member.parent?.value as? any HasName)?.fullyQualifiedName == classToken.fullyQualifiedName else { return member }
                    var member = member
                    member.parent = reference
                    return member
                })
            }
            // With a default isolation, Swift gives a member of a `nonisolated` class the global actor of the
            // requirement it implements, for a protocol the class itself states: `show()` of a default-isolated
            // `Showing` is on the main actor in `class Child: Plain, Showing`, whatever `Plain` makes of the class.
            // A member that states its isolation keeps it, and so does one of a `nonisolated` requirement. Swift
            // infers nothing for a protocol an extension states.
            if defaultIsolation != nil, merged.isolation == .nonisolated {
                let requirements = statedRepresentations
                    .compactMap { $0 as? ProtocolDeclaration }
                    .flatMap { parent in
                        parent.members.compactMap { member -> (requirement: any Inheritable, isolation: Isolation)? in
                            guard let requirement = member as? any Inheritable,
                                  let isolation = member.memberIsolation ?? parent.isolation,
                                  case .globalActor = isolation else { return nil }
                            return (requirement, isolation)
                        }
                    }
                merged = merged.replacing(members: merged.members.map { member in
                    guard (member.parent?.value as? any HasName)?.fullyQualifiedName == classToken.fullyQualifiedName,
                          member.memberIsolation == nil,
                          let inheritable = member as? any Inheritable,
                          let witnessed = requirements.first(where: { inheritable.implements($0.requirement) }) else { return member }
                    return member.withDefaultIsolation(witnessed.isolation)
                })
            }
            return merged
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
                    && names.resolve(name, from: protocolToken.fullyQualifiedName) == nil
            }
            // A requirement of a parent with no global actor is nonisolated in a protocol that has one, as a
            // conforming type's witness must be: Swift doesn't isolate it to the refining protocol's actor.
            let nonisolatedRequirements = merged.globalActor == nil ? [] : inheritedRepresentations
                .compactMap { $0 as? ProtocolDeclaration }
                .filter { $0.globalActor == nil && !$0.isActor }
                .flatMap(\.members)
                .compactMap { $0 as? any Inheritable }
            let ownRequirements = protocolToken.members.compactMap { $0 as? any Inheritable }
            func isNonisolatedRequirement(_ member: any Token) -> Bool {
                guard let member = member as? any Inheritable else { return false }
                return nonisolatedRequirements.contains { $0.isEqual(to: member) } && !ownRequirements.contains { $0.isEqual(to: member) }
            }
            // Every member, inherited ones included, belongs to this protocol now: its mock is the one they're
            // generated into, and its isolation, which may come from a parent, is the one they take.
            let reference = Reference<any Token>(merged.replacing(members: []))
            return merged.replacing(members: merged.members.map { member in
                var member = isNonisolatedRequirement(member) ? member.withDefaultIsolation(.nonisolated) : member
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

extension Token {
    /// The isolation a member states: its own, or `nonisolated` for a method that runs on its caller's actor or on
    /// the one a parameter names.
    fileprivate var memberIsolation: Isolation? {
        switch self {
        case let method as Method: method.stubbedIsolation
        case let variable as Variable: variable.isolation
        case let subscriptDeclaration as Subscript: subscriptDeclaration.isolation
        default: nil
        }
    }

    /// The member with `isolation` if it states none of its own.
    fileprivate func withDefaultIsolation(_ isolation: Isolation) -> any Token {
        switch self {
        case var method as Method where method.isolation == nil:
            method.isolation = isolation
            return method
        case var variable as Variable where variable.isolation == nil:
            variable.isolation = isolation
            return variable
        case var subscriptDeclaration as Subscript where subscriptDeclaration.isolation == nil:
            subscriptDeclaration.isolation = isolation
            return subscriptDeclaration
        default:
            return self
        }
    }
}
