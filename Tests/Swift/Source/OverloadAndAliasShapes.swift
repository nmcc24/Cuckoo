// Shapes whose mocks didn't compile before 3.0: a typealias named through `Self` and function values the type eraser
// sets.
protocol AliasedLookup {
    typealias ID = Int
    typealias Callback = (Self.ID) -> Void

    func find(_ id: Self.ID) -> Self.ID?
    func each(_ callback: Self.Callback)
}

struct AliasedLookupImplementation: AliasedLookup {
    func find(_ id: Int) -> Int? { id + 1 }
    func each(_ callback: (Int) -> Void) { callback(7) }
}

typealias ObservedHandler = (Int) -> Int

protocol ObservedStore {
    associatedtype Value

    var handler: ObservedHandler { get set }
    var implicit: Value! { get set }
    subscript(index: Int) -> ObservedHandler { get set }
    func value() -> Value
}

final class ObservedStoreImplementation: ObservedStore {
    var handler: ObservedHandler = { $0 }
    var implicit: String!
    subscript(index: Int) -> ObservedHandler {
        get { handler }
        set { handler = newValue }
    }
    func value() -> String { "" }
}
