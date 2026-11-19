protocol Inheritable {
    // Support to dynamically define whether the token is inheritable or not.
    var isInheritable: Bool { get }

    func isEqual(to other: any Inheritable) -> Bool

    /// Whether a class's member implements `requirement`: the same member, or one with fewer effects, as a
    /// non-throwing `func load()` implements `func load() throws`, which Swift accepts.
    func implements(_ requirement: any Inheritable) -> Bool

    /// Whether a class's member implements `requirement` with the types it's written with, `Self` and associated
    /// types included.
    func implementsAsWritten(_ requirement: any Inheritable) -> Bool
}

extension Inheritable {
    var isInheritable: Bool { true }

    /// The names a protocol's requirement uses that a class's member implementing it writes as concrete types: `Self`
    /// and the protocol's associated types. None for a class's member.
    var placeholders: Set<String> {
        guard let protocolDeclaration = (self as? any Token)?.parent?.value as? ProtocolDeclaration else { return [] }
        return Set(["Self"] + (protocolDeclaration.associatedTypes + protocolDeclaration.primaryAssociatedTypes).map(\.name))
    }

    func implements(_ requirement: any Inheritable) -> Bool {
        isEqual(to: requirement)
    }

    func implementsAsWritten(_ requirement: any Inheritable) -> Bool {
        isEqual(to: requirement)
    }
}
