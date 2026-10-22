protocol Combiner {
    func combine<each T>(_ values: repeat each T) -> (repeat each T)
}
