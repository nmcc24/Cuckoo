// Shapes whose mocks didn't compile before 3.0: a typealias named through `Self`, function values the type eraser
// sets, a sync and an async overload of one signature and requirements a class implements with `final` or `static`
// members or in an extension, and a typealias a member's generic parameter shadows.
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

protocol OverloadedLoader {
    func value() -> Int
    func value() async -> Int
}

/// Public, so its mock's proxies aren't implicitly `Sendable`: stubbing and verifying the overloads from an actor
/// mustn't send them off it.
public protocol PublicOverloadedLoader {
    func value() -> Int
    nonisolated(nonsending) func value() async -> Int
    static func shared() -> Int
    static func shared() async -> Int
}

protocol ShadowedAliasStore {
    typealias Key = String

    func key<Key>(for value: Key) -> Self.Key
}

struct ShadowedAliasStoreImplementation: ShadowedAliasStore {
    func key<Key>(for value: Key) -> String { "\(value)" }
}

/// A member named `async` takes the proxies' name for the async overloads, which `await` names instead.
protocol AsyncNamedLoader {
    var async: Bool { get }
    func value() -> Int
    func value() async -> Int
}

protocol CountingRequirements {
    static func reset()
    func increment() -> Int
    func decrement() -> Int
}

class FinalWitnessCounter: CountingRequirements {
    init() {}

    static func reset() {}
    final func increment() -> Int { 1 }
    func decrement() -> Int { -1 }
}

protocol RefreshingRequirements {
    var stamp: Int { get }
    func refresh() -> Int
    func reload() -> Int
}

class ExtensionWitnessFeed: RefreshingRequirements {
    init() {}

    func reload() -> Int { 1 }
}

extension ExtensionWitnessFeed {
    var stamp: Int { 3 }
    func refresh() -> Int { 2 }
}

/// Overloads that differ in their result too are still a pair: a call of a proxy's member doesn't state it.
protocol ResultOverloadedLoader {
    func value() -> Int
    func value() async -> String
}

/// A typealias of a type naming the associated type, in generic members, which a default implementation gets
/// through the opened existential, and next to a generic parameter of its name.
protocol ItemListing {
    associatedtype Item
    typealias Items = [Item]

    func doubled<T>(_ items: Items, with value: T) -> Items
    func each<T>(_ value: T, body: (Items) -> Void)
    func shadowed<Items>(_ value: Items, real: Self.Items) -> Self.Items
}

struct ItemListingImplementation: ItemListing {
    func doubled<T>(_ items: [Int], with value: T) -> [Int] { items + items }
    func each<T>(_ value: T, body: ([Int]) -> Void) { body([1, 2]) }
    func shadowed<Items>(_ value: Items, real: [Int]) -> [Int] { real.reversed() }
}

protocol SuperclassRequirements {
    static func reset() -> Int
    func ping() -> Int
    func hello() -> Int
    func open() -> Int
}

class SuperclassWitnessBase {
    init() {}

    static func reset() -> Int { 1 }
    final func ping() -> Int { 2 }
    func open() -> Int { 4 }
}

extension SuperclassWitnessBase {
    func hello() -> Int { 3 }
}

class SuperclassWitnessChild: SuperclassWitnessBase, SuperclassRequirements {}
