// Parameters a mock can't record, each with a warning: a protocol with one isn't mocked, and a class's mock keeps
// the real implementation.
final class Box {}

protocol Exchanging {
    func swap(_ box: inout sending Box)
}

protocol Opaque {
    func fill(_ value: inout some Sendable)
}

protocol Packing {
    func apply<each T>(_ values: repeat each T, to body: (repeat each T) -> Void)
}

class Mixed {
    init() {}
    func fill(_ value: inout some Sendable) {}
    func apply<each T>(_ values: repeat each T, to body: (repeat each T) -> Void) {}
    func isolated(_ actor: isolated (any Actor)?, body: () -> Void) async {}
    func keep() {}
}
