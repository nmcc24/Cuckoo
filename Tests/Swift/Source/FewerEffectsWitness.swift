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

enum FewerEffectsError: Error {
    case failed
}

/// A typed throw implementing an untyped one.
protocol TypedFewerEffectsLoading {
    func load() throws -> Int
}

class TypedFewerEffectsLoader: TypedFewerEffectsLoading {
    init() {}
    func load() throws(FewerEffectsError) -> Int { 0 }
}
