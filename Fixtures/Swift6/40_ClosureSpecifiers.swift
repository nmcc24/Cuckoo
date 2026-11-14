// Non-escaping closures written with a specifier, `sending`, `borrowing` or `inout`, directly or through a
// typealias, which a mock can't record yet (roadmap). A class mock leaves such a method out, with a comment, so
// calls run the class's own implementation. Fixture 41 is the protocol case.
typealias SpecifierHandler = () -> Void

class ClosureSpecifierRunner {
    init() {}
    func run(_ operation: sending () -> Void) { operation() }
    func swap(_ operation: inout () -> Void) {}
    func read(_ operation: borrowing () -> Int) -> Int { operation() }
    func aliased(_ operation: sending SpecifierHandler) { operation() }
    func plain(_ operation: () -> Void) { operation() }
}
