// A parent's primary associated type bound to a closure type, used as a parameter: the mock's parameter is a
// non-escaping closure, which it has to make escaping to record. Also as `sending`, in a subscript, inside a closure's
// parameters.
protocol Transforming<Input> {
    associatedtype Input
    func transform(_ input: Input)
    func transformAll(_ inputs: [Input], fallback: Input?) -> Int
    func send(_ input: sending Input)
    func take(_ body: (Input) -> Void)
    func make() -> Input
    subscript(input: Input) -> Int { get }
}

protocol Formatter: Transforming<(Int) -> String> {
    func reset()
}
