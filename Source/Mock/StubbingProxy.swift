/// A generated mock's stubbing proxy, which ``stub(_:block:)-(M,_)`` hands to its block. It has one stubbing
/// member per mocked member.
public protocol StubbingProxy {
    /// Creates the proxy that adds stubs to `manager`.
    init(manager: MockManager)
}
