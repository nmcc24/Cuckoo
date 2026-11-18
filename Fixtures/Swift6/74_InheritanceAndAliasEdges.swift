// Shapes the review of the crawler fixes turned up.

// The sources' own `Result` isn't Swift's, so these are two requirements.
struct Result<A, B> {}

protocol Loading {
    func load(_ x: Int) -> Swift.Result<Int, any Error>
    func swap<T, U>(a: T, b: U)
}

protocol Reloading: Loading {
    func load(_ x: Int) -> Result<Int, any Error>
    // The same requirement as the parent's: Swift matches generic parameters by where they're used.
    func swap<U, T>(a: T, b: U)
}

// Every associated type fixed: the requirement on them holds, and the mock has no generic parameter to state it on.
protocol Keyed where Keys.Element: Hashable {
    associatedtype Keys: Collection
    func keys() -> Keys
}

protocol StringKeyed: Keyed where Keys == [String] {}

// A type between a nested class and a `nonisolated` ancestor that states a global actor: the class takes the
// module's default isolation, not `nonisolated`.
nonisolated enum Outermost {
    @MainActor struct Isolated {
        class Inner {
            init() {}
            func f() {}
        }
    }
}

// Closure typealiases: a variadic generic one, a `sending` parameter, and an alias whose name is shadowed by a
// non-closure typealias in its scope.
typealias Callback = (Int) -> Void
typealias Many<T> = (T...) -> Void
typealias Sent<T> = (sending T) -> Void

enum Scope {
    typealias Callback = Int
    typealias Value = Callback
}

protocol Aliased {
    func many(_ handler: Many<Callback>)
    func sent(_ handler: Sent<Callback>)
    func value(_ value: Scope.Value)
}
