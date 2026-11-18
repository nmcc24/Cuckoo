// Shapes whose mocks didn't compile before 3.0: a typealias named through `Self`.
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
