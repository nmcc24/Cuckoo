// Requirements of a protocol with associated types that its mock's type eraser forwards to the default
// implementation with their effects (async and throwing getters), and ones it can't forward: inout and sending
// arguments, Self, and members isolated otherwise than the protocol. Those record a failure saying to stub them and
// return a default value, so the mock compiles.
struct NS {}
protocol Shapes {
    associatedtype T
    func bump(_ x: inout T)
    var asyncValue: T { get async }
    var throwingValue: T { get throws }
    @MainActor func onMain(_ x: T)
    @MainActor var mainValue: T { get }
    func copySelf(_ x: Self) -> Self
    func take(_ x: consuming T)
    func look(_ x: borrowing T)
    func send(_ x: sending T) async -> sending T
    func plain(_ x: T) -> T
}
protocol NonisolatedShapes {
    associatedtype T
    nonisolated func free(_ x: T)
}
protocol SendingShapes {
    associatedtype T
    func a(_ x: sending T)
    func b() -> sending T
    func c(_ x: sending T) async
    func d() async -> sending T
    func e(_ x: sending T) async -> sending T
}
protocol GenericInout {
    associatedtype T
    func bump<U>(_ x: inout T, by u: U)
    func send<U>(_ x: sending T, _ u: U)
}
