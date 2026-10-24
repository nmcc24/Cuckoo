class NonSendableBox { var v = 0 }
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
