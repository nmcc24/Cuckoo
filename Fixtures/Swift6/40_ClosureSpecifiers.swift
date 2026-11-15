// Non-escaping closures written with a specifier, `sending`, `borrowing` or `inout`, directly or through a
// typealias: the mock records them as it does a plain non-escaping closure. Fixture 41 is the protocol case.
typealias SpecifierHandler = () -> Void

class ClosureSpecifierRunner {
    init() {}
    func run(_ operation: sending () -> Void) { operation() }
    func swap(_ operation: inout () -> Void) {}
    func read(_ operation: borrowing () -> Int) -> Int { operation() }
    func aliased(_ operation: sending SpecifierHandler) { operation() }
    func plain(_ operation: () -> Void) { operation() }
}
