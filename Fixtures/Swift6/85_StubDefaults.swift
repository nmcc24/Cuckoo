// An unstubbed call returning a protocol mocked in the same module answers with a new `…Stub` of it, which the mock
// hands the manager: the call's return type, an existential, has no default value of its own. `Fix`, the module the
// fixture matrix compiles this as, qualifies a type only there.

protocol Engine {
    func start() -> Bool
}

@MainActor
protocol Dashboard {
    var title: String { get }
}

protocol Tracker: Actor {
    func count() -> Int
}

protocol Storage: Sendable {
    func read() -> Int
}

enum Garage {
    protocol Door {
        func open()
    }
}

// Inside `Depot`, `EngineStub` is `Depot.Engine`'s stub, so a member there that names the top-level `Engine` through
// `Motor` has no default: the mock can't name that stub.
enum Depot {
    protocol Engine {
        func idle()
    }

    protocol Bay {
        func nearest() -> any Engine
        func aliased() -> any Motor
    }
}

typealias Motor = Engine

// No stub default: the stub is generic, has no `init()`, or isn't always declared.
protocol Shelf<Item> {
    associatedtype Item
    func first() -> Item?
}

protocol Named {
    init(name: String)
}

#if DEBUG
protocol Probe {
    func probe()
}
#endif

protocol Car {
    var engine: any Engine { get }
    var spare: any Engine { get set }
    func aliased() -> any Motor
    func qualified() -> any Fix.Engine
    func nested() -> any Garage.Door
    func parenthesized() -> (any Engine)
    func dashboard() -> any Dashboard
    func tracker() -> any Tracker
    func storage() -> any Storage
    func later() async -> any Engine
    func failing() throws -> any Engine
    subscript(index: Int) -> any Engine { get }
    static func make() -> any Engine

    // These keep the defaults they had, or none.
    func optional() -> (any Engine)?
    func list() -> [any Engine]
    func pair() -> (any Engine, Int)
    func composed() -> any Engine & Sendable
    func shelf() -> any Shelf<Int>
    func named() -> any Named
    func generic<Engine>(_ value: Engine) -> Engine
    #if DEBUG
    func probe() -> any Probe
    #endif
}

@MainActor
protocol Cockpit {
    var dashboard: any Dashboard { get }
    func engine() -> any Engine
    func tracker() async -> any Tracker
}

protocol Pit: Actor {
    func storage() -> any Storage
    func tracker() -> any Tracker
}

// Its mock forwards through a type eraser, which answers the member it can't forward with the same default.
protocol Fleet {
    associatedtype Vehicle
    func lead() -> Vehicle
    func tune(_ level: inout Int) -> any Engine
}

class Workshop {
    init() {}

    var storage: any Storage { fatalError() }

    func engine() -> any Engine { fatalError() }
    func door(at index: Int) -> any Garage.Door { fatalError() }
}
