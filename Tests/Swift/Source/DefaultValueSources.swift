/// A non-`Sendable` class, whose default for unstubbed calls can only be registered as a factory.
final class Canvas {
    var strokes: [String] = []
}

/// Members whose return types have no built-in default.
protocol DefaultValueSource {
    func pair() -> (Int, String)
    func canvas() -> Canvas
}
