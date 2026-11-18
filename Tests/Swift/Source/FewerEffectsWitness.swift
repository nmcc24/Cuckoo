/// A class implementing a protocol's throwing and `async` requirements with members that don't throw and aren't
/// `async`, as Swift allows.
protocol FewerEffectsLoading {
    func load() throws -> Int
    func later() async -> Int
}

class FewerEffectsLoader: FewerEffectsLoading {
    init() {}
    func load() -> Int { 0 }
    func later() -> Int { 0 }
}
