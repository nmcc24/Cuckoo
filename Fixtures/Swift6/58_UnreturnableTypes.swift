// Members returning `~Copyable` or `~Escapable` values, which a mock can't keep a stub of: a class's mock leaves them
// to the real implementation, and a protocol with one isn't mocked, each with a warning. A `Span` result is covered
// by CrawlerDiagnosticsTests, as returning one needs the experimental lifetime feature.
struct Receipt: ~Copyable {
    var id: Int
}

@available(macOS 26, iOS 26, tvOS 26, watchOS 26, *)
class Register {
    init() {}
    func receipt() -> Receipt { Receipt(id: 0) }
    func make<T: ~Copyable>(_ make: () -> T) -> T { make() }
    func total() -> Int { 0 }
    func maybeReceipt() -> Optional<Receipt> { nil }
}

// A class's own `~Copyable` generic parameter, and a generic subscript's.
class Pool<Item: ~Copyable> {
    init() {}
    func take() -> Item { fatalError() }
    func count() -> Int { 0 }
}

protocol Factory {
    subscript<T: ~Copyable>(make make: () -> T) -> T { get }
}

protocol Printer {
    func receipt() -> Receipt
    func print() -> Int
}

// It refines `Printer`, so its mock would need `receipt()` too: it isn't mocked either.
protocol FancyPrinter: Printer {
    func color() -> Int
}

protocol Mocked {
    func value() -> Int
}

