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

// The same through a typealias, and through a qualified one.
typealias Formatting = (Int) -> String

protocol AliasedFormatter: Transforming<Formatting> {}

enum Formats {
    typealias Parse = (String) -> Int
}

protocol QualifiedFormatter: Transforming<Formats.Parse> {}

struct Box {
    typealias Handler = (Int) -> Void

    // Found in the enclosing scope, as a parameter's typealias is.
    protocol NestedFormatter: Transforming<Handler> {}
}

// A generic constraint isn't a parent: a method's own or the type's generic parameter, or a nearer typealias, still
// shadows the top-level `Callback` there.
typealias Callback = (Int) -> Void

class Runner<Callback> {
    init() {}
    func run<T: Transforming<Callback>>(_ value: T) {}
}

class Service {
    typealias Callback = (String) -> Void
    init() {}
    func run<T: Transforming<Callback>>(_ value: T) {}
}

// From its inheritance clause, a protocol's own typealias isn't in scope: the top-level `Callback` binds `Input`.
protocol OwnShadow: Transforming<Callback> {
    typealias Callback = (String) -> Void
}
