// Parameter and effect shapes the mocks must spell as the requirement does: `sending` before `@escaping`,
// `@isolated(any)` kept on the closure type, a typed-throws getter, typed throws through a non-escaping closure,
// a closure written through a typealias, `consuming` and `borrowing` parameters, and `-> ()`.
enum ShapeError: Error { case failed }

typealias ShapeHandler = (Int) -> Void

protocol ParameterShapes {
    func run(_ operation: sending @escaping () -> Void)
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    func spawn(_ operation: sending @escaping @isolated(any) () async -> Int)
    var value: Int { get throws(ShapeError) }
    var asyncValue: String { get async throws(ShapeError) }
    func transform(_ body: () -> Void) throws(ShapeError) -> Int
    func handle(_ handler: ShapeHandler)
    func store(items: consuming [Int], name: borrowing String) -> Int
    func reset(_ count: Int) -> ()
}

/// A typed-throws requirement of an associated-type protocol, which the type-erasing default caller forwards.
protocol TypedSequence<Element> {
    associatedtype Element
    associatedtype Failure: Error = Never
    func next() async throws(Failure) -> Element?
}
