/// Parameters whose value matchers Matching.md describes: a `Float`, and an optional collection.
protocol ValueMatching {
    func scale(by factor: Float)
    func tag(_ names: [String]?)
}
