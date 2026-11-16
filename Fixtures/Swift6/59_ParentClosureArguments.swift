// A parent protocol's primary associated types bound to a closure type, whose `->` isn't a generic argument's end.
protocol Transforming<Output, Input> {
    associatedtype Output
    associatedtype Input
    func make() -> Output
    func take(_ input: Input)
}

protocol Formatter: Transforming<(Int) -> String, [String: Int]> {
    func reset()
}
