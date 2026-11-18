struct ClassDeclaration: ContainerToken, HasEnclosingCompilationConditions {
    var parent: Reference<any Token>?

    var attributes: [Attribute]
    var accessibility: Accessibility
    var name: String
    var genericParameters: [GenericParameter]
    var genericRequirements: [String]
    var inheritedTypes: [String]
    var members: [any Token]
    var enclosingCompilationConditions: [String]
    /// The global actor the type is isolated to, if any.
    var isolation: Isolation?
    /// The isolation is the module's default, which a superclass's isolation replaces, as Swift infers it.
    var isIsolationDefault = false
    /// Members the mock can't override, each with the reason, stated in a comment in the mock.
    var unmockedMembers: [String] = []
    /// Attributes the generator couldn't classify, which the mock names in a comment; see `Crawler.unknownAttributes`.
    var unknownAttributes: [String] = []
    /// The non-public type whose use by a non-public member made a public class's mock internal, if any.
    var internalMockReason: String?
    /// Whether the class, or an extension of it, is declared `@unchecked Sendable`, which a subclass, its mock and
    /// stub, has to restate.
    var isUncheckedSendable = false
    /// Overrides the mock can't override, `final` or unavailable ones: they hide the superclass's member, which
    /// the mock would otherwise override.
    var shadowedMembers: [any Token] = []
    /// A generic superclass in the sources, `Base<Int>`, whose members the mock doesn't override, with their names.
    var unmockedGenericSuperclass: (name: String, members: [String])?

    func replacing(members: [any Token]) -> ClassDeclaration {
        ClassDeclaration(
            parent: parent,
            attributes: attributes,
            accessibility: accessibility,
            name: name,
            genericParameters: genericParameters,
            genericRequirements: genericRequirements,
            inheritedTypes: inheritedTypes,
            members: members,
            enclosingCompilationConditions: enclosingCompilationConditions,
            isolation: isolation,
            isIsolationDefault: isIsolationDefault,
            unmockedMembers: unmockedMembers,
            unknownAttributes: unknownAttributes,
            internalMockReason: internalMockReason,
            isUncheckedSendable: isUncheckedSendable,
            shadowedMembers: shadowedMembers,
            unmockedGenericSuperclass: unmockedGenericSuperclass
        )
    }
}
