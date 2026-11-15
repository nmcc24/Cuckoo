// Shapes the fixture matrix compiles, run here too: an `AsyncSequence` existential, value generics, members inside
// `#if DEBUG`, and deprecated requirements that the type eraser of a protocol with an associated type forwards.

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
protocol EventFeed {
    var stream: AsyncStream<Int> { get }
    func updates() -> any AsyncSequence<Int, Never>
}

@available(macOS 26, iOS 26, tvOS 26, watchOS 26, *)
class InlineBuffer<let Count: Int> {
    init() {}

    func first<let N: Int>(_ values: InlineArray<N, Int>) -> Int {
        values[0]
    }
}

protocol DebugReporting {
    #if DEBUG
    var debugInfo: String { get }
    #else
    var releaseInfo: String { get }
    #endif
    func report() -> String
}

// Only Swift 6.4's `@diagnose` keeps the eraser's forwarding to a deprecated requirement from warning.
#if compiler(>=6.4)
protocol LegacySource {
    associatedtype Item
    @available(*, deprecated, message: "use next()")
    func old() -> Item
    func next() -> Item
}

/// A default implementation whose deprecated requirement still answers.
struct LegacyCounter: LegacySource {
    @available(*, deprecated, message: "use next()")
    func old() -> Int { 1 }

    func next() -> Int { 2 }
}
#endif
