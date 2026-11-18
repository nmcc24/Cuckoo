protocol Inheritable {
    // Support to dynamically define whether the token is inheritable or not.
    var isInheritable: Bool { get }

    func isEqual(to other: any Inheritable) -> Bool

    /// Whether a class's member implements `requirement`: the same member, or one with fewer effects, as a
    /// non-throwing `func load()` implements `func load() throws`, which Swift accepts.
    func implements(_ requirement: any Inheritable) -> Bool
}

extension Inheritable {
    var isInheritable: Bool { true }

    func implements(_ requirement: any Inheritable) -> Bool {
        isEqual(to: requirement)
    }
}
