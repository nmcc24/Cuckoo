typealias SpecifiedHandler = () -> Void

/// Non-escaping closure parameters written with `sending`, `borrowing` or `inout`, directly or through a typealias.
protocol ClosureSpecifierService {
    func run(_ operation: sending () -> Void)
    func swap(_ operation: inout () -> Void)
    func read(_ operation: borrowing () -> Int) -> Int
    func aliased(_ operation: sending SpecifiedHandler)
}

class ClosureSpecifierRunner {
    init() {}

    func run(_ operation: sending () -> Void) { operation() }
    func read(_ operation: borrowing () -> Int) -> Int { operation() }
    func aliased(_ operation: sending SpecifiedHandler) { operation() }
}
