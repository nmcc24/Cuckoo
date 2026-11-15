// Protocol requirements taking non-escaping closures written with `sending`, `borrowing` or `inout`, directly or
// through a typealias. Fixture 40 is the class case.
typealias ServiceHandler = () -> Void

protocol ClosureSpecifierService {
    func run(_ operation: sending () -> Void)
    func swap(_ operation: inout () -> Void)
    func read(_ operation: borrowing () -> Int) -> Int
    func aliased(_ operation: sending ServiceHandler)
    func asyncRun(_ operation: sending () async -> Void) async
}
