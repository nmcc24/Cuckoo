// Non-escaping closures written with a specifier, `sending`, `borrowing` or `inout`, which a mock can't record
// yet (roadmap). A class mock leaves such a method out, with a comment, so calls run the class's own
// implementation; a protocol's mock can't leave a requirement out, so its mock doesn't compile. This fixture
// is an expected failure for the protocol, and checks that the class's mock compiles.
class ClosureSpecifierRunner {
    init() {}
    func run(_ operation: sending () -> Void) { operation() }
    func swap(_ operation: inout () -> Void) {}
    func read(_ operation: borrowing () -> Int) -> Int { operation() }
    func plain(_ operation: () -> Void) { operation() }
}

protocol ClosureSpecifierService {
    func run(_ operation: sending () -> Void)
}
