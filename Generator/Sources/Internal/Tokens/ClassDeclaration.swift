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
    /// Whether the class declares no initializer and inherits from no class but `NSObject`, so its only initializer
    /// is the implicit `init()`, which is internal: a public mock declares its own, so another module can create it.
    var hasOnlyImplicitInitializer = false

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
            hasOnlyImplicitInitializer: hasOnlyImplicitInitializer
        )
    }
}
