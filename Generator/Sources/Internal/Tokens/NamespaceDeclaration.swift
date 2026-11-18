/// This structure exists purely for supporting nested classes,
/// it could be any container (like `struct` or `extension`).
struct NamespaceDeclaration: Token, HasAttributes, HasAccessibility, HasName, HasMembers, HasEnclosingCompilationConditions {
    var parent: Reference<any Token>?

    var attributes: [Attribute]
    var accessibility: Accessibility
    var name: String
    var members: [any Token]
    var enclosingCompilationConditions: [String]
    /// An `extension`, whose access level is the default for what it declares.
    var isExtension = false
    /// An `actor`: the module's default isolation doesn't apply to the types nested in it.
    var isActor = false
    /// The isolation the type states: a `nonisolated` one's nested types aren't given the module's default isolation,
    /// a global actor's are. An extension's isn't recorded: it applies to the extension's members, not its types.
    var statedIsolation: Isolation?
    /// An extension's `where` requirements, which the extension a mock is declared in repeats.
    var genericRequirements: [String] = []
    /// The methods, properties and subscripts an extension declares for the type it extends. A class's mock can't
    /// override them, and they hide the requirements of the class's protocols that they implement.
    var extensionMembers: [any Token] = []
    /// The `@objc` instance members an extension declares for the class it extends: the Objective-C
    /// runtime dispatches them, so a subclass, the mock, can override them, and they implement the requirements of the
    /// class's protocols they match as the class's own members do.
    var overridableExtensionMembers: [any Token] = []
    /// The isolation an extension states, as `nonisolated extension`, which its members take unless they state one.
    var memberIsolation: Isolation?

    func replacing(members: [any Token]) -> NamespaceDeclaration {
        NamespaceDeclaration(
            parent: parent,
            attributes: attributes,
            accessibility: accessibility,
            name: name,
            members: members,
            enclosingCompilationConditions: enclosingCompilationConditions,
            isExtension: isExtension,
            isActor: isActor,
            statedIsolation: statedIsolation,
            genericRequirements: genericRequirements,
            extensionMembers: extensionMembers,
            overridableExtensionMembers: overridableExtensionMembers,
            memberIsolation: memberIsolation
        )
    }
}
