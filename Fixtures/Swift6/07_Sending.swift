class NonSendableBox {
    var v = 0
    init() {}
}
protocol Transfer {
    func take(_ box: sending NonSendableBox)
    func make() -> sending NonSendableBox
}

// The type-erased default implementation opens the existential in a nested function,
// which must take the `sending` arguments as parameters instead of capturing them.
protocol Converter<Input> {
    associatedtype Input
    associatedtype Output
    func convert<T>(value: sending T, input: sending Input, fallback: Output) async -> Output
}

// An actor mock hands its `then` closure the `sending` arguments: a closure that captured one would be a
// "sending ... risks causing data races" error.
protocol SendingActor: Actor {
    func take(_ box: sending NonSendableBox)
    func load(_ box: sending NonSendableBox) async -> Int
    func update(_ count: inout Int, box: sending NonSendableBox) -> Int
    func maybe(_ box: sending NonSendableBox?)
    func all(_ boxes: sending [NonSendableBox]) async throws -> Int
    func run(_ work: sending @escaping () -> Void)
}
