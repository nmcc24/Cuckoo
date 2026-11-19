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

    /// Whether a protocol's requirement restates a parent's `requirement` with the types the parent's typealiases
    /// stand for, as `func a() -> String` does `func a() -> A` of a parent that fixes `A == String`.
    func restates(_ requirement: any Inheritable) -> Bool
}

extension Inheritable {
    var isInheritable: Bool { true }

    /// The names a protocol's requirement uses that a class's member implementing it writes as concrete types: `Self`
    /// and the protocol's associated types, and the protocol's typealiases, which the member may write as what they
    /// stand for. None for a class's member.
    var placeholders: Method.Signature.Placeholders {
        guard let protocolDeclaration = (self as? any Token)?.parent?.value as? ProtocolDeclaration else { return .init() }
        let names = Set(["Self"] + (protocolDeclaration.associatedTypes + protocolDeclaration.primaryAssociatedTypes).map(\.name))
        let aliases = protocolDeclaration.members.compactMap { $0 as? Typealias }.filter { !$0.alias.contains("<") }
        return .init(names: names, aliases: Dictionary(aliases.map { ($0.alias, $0.original) }, uniquingKeysWith: { first, _ in first }))
    }

    func implements(_ requirement: any Inheritable) -> Bool {
        isEqual(to: requirement)
    }

    func implementsAsWritten(_ requirement: any Inheritable) -> Bool {
        isEqual(to: requirement)
    }

    func restates(_ requirement: any Inheritable) -> Bool {
        false
    }
}
