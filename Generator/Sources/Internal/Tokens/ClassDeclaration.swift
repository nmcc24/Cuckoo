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
    /// Members the mock can't override, each with the reason, stated in a comment in the mock.
    var unmockedMembers: [String] = []
    /// Attributes the generator couldn't classify, which the mock names in a comment; see `Crawler.unknownAttributes`.
    var unknownAttributes: [String] = []
    /// The non-public type whose use by a non-public member made a public class's mock internal, if any.
    var internalMockReason: String?
    /// Whether the class, or an extension of it, is declared `@unchecked Sendable`, which a subclass, its mock and
    /// stub, has to restate.
    var isUncheckedSendable = false
    /// Typealiases, as `Model = Feature.Model`, for the types the scopes around the one this is nested in declare:
    /// the mock and stub sit in an extension of that type, which doesn't see them. See `Generator.outerScopeTypealiases`.
    var outerScopeTypealiases: [OuterScopeTypealias] = []

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
            unmockedMembers: unmockedMembers,
            unknownAttributes: unknownAttributes,
            internalMockReason: internalMockReason,
            isUncheckedSendable: isUncheckedSendable
        )
    }
}
