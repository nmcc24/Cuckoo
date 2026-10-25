/// How the values a stub holds may be shared, chosen by the generator from the mocked type.
///
/// It decides what `thenReturn` accepts, so a value handed to every call can't race:
/// - ``Confined``: the mocked type isn't `Sendable`, so the mock, its stubs and its calls stay in one
///   isolation domain. Any value can be returned.
/// - ``Shared``: the mocked type is `Sendable` and nonisolated, so calls can come from any task at once.
///   Returned values must be `Sendable`.
/// - ``Isolated``: the mocked type is isolated to an actor (`@MainActor`, another global actor, or an actor
///   instance), so every call runs there. A returned value is sent to it.
public enum StubSharing {
    public enum Confined {}
    public enum Shared {}
    public enum Isolated {}
}
