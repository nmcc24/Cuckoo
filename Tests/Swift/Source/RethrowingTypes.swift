/// Rethrowing members, which a caller may pass closures that don't throw, and then calls without `try`.
protocol RethrowingService {
    func transform(_ value: Int, using closure: (Int) throws -> Int) rethrows -> Int
    func transformAsync(_ value: Int, using closure: (Int) async throws -> Int) async rethrows -> Int
}
