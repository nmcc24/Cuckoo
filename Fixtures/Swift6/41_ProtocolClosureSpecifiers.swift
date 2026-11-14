// A protocol requirement taking a non-escaping closure written with `sending`: a protocol's mock can't leave a
// requirement out, and can't record the closure yet (roadmap), so it doesn't compile. An expected failure.
protocol ClosureSpecifierService {
    func run(_ operation: sending () -> Void)
}
