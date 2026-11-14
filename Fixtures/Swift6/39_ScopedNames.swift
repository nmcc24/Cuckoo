// Names the generator resolves by scope, as Swift does: a default argument naming a private declaration (left
// out of the mock, which can't see it), a closure typealias shadowed by a generic parameter or associated type,
// same-named typealiases nested in two types and one used qualified, nested composition typealiases, a type
// nested in an extension of an actor (which the module's default isolation doesn't reach), and a class subscript
// of opaque type or with a default argument.
fileprivate let defaultPrefix = "x"

class DefaultsPrinter {
    private static let hidden = 2
    init() {}
    func a(count: Int = DefaultsPrinter.hidden) {}
    func b(prefix: String = defaultPrefix) {}
    subscript(row: Int, column: Int = 0) -> Int { row + column }
    subscript(label: String) -> some Equatable { label }
}

func useSubscriptDefault(_ printer: MockDefaultsPrinter) -> Int { printer[1] }

typealias ScopedHandler = (Int) -> Void

protocol ScopedRouter {
    associatedtype ScopedHandler
    func route(_ handler: ScopedHandler)
}

protocol ScopedGenericUser {
    func use<ScopedHandler>(_ handler: ScopedHandler)
}

class ScopedDownloader {
    typealias Completion = (Bool) -> Void
    init() {}
    func load(_ completion: Completion) {}
}

class ScopedUploader {
    typealias Completion = (Int, String) -> Void
    init() {}
    func send(_ completion: Completion) {}
}

protocol ScopedSender {
    func send(_ completion: ScopedUploader.Completion)
}

protocol PartC1 { func c1() }
protocol PartC2 { func c2() }
protocol PartC3 { func c3() }
typealias PartC12 = PartC1 & PartC2
typealias PartC123 = PartC12 & PartC3
protocol NestedComposed: PartC123 { func composed() }

enum CompositionScope {
    typealias Both = PartC1 & PartC2
}
protocol QualifiedComposed: CompositionScope.Both { func qualified() }

actor ScopedStore {}

extension ScopedStore {
    class Cache {
        init() {}
        func clear() {}
    }

    protocol Loader {
        func load()
    }
}

nonisolated func useNestedInActorExtension(_ cache: ScopedStore.Cache, _ loader: any ScopedStore.Loader) {
    cache.clear()
    loader.load()
}

// When a name's scope can't be settled, the earlier behaviour applies: a type name both public and internal in
// the module keeps the mock internal, a closure typealias declared in another extension, a superclass or a parent
// protocol is found when it's the module's only one of that name, and a default naming something only some
// other type declares private is kept. A parent declared in a superclass's scope is found through the subclass,
// and an actor extended through its qualified name keeps its nested types nonisolated.
public struct Player {
    public struct State {}
    public init() {}
}

open class Downloader {
    struct State {}
    var state: State = State()
    public init() {}
    open func start() {}
}

enum API {}
extension API {
    typealias Done = () -> Void
}
extension API {
    protocol Client { func fetch(_ done: Done) }
}

class BaseRunner {
    typealias Handler = () -> Void
    init() {}
}
class ChildRunner: BaseRunner {
    func run(_ handler: Handler) { handler() }
}
protocol BaseTask {
    typealias Callback = (Int) -> Void
}
protocol ChildTask: BaseTask {
    func go(_ callback: Callback)
}

final class Registry {
    private static let shared = 1
}
struct Settings {
    static let shared = Settings()
}
class SettingsStore {
    init() {}
    func save(settings: Settings = .shared) {}
}
func useDefault(_ store: MockSettingsStore) { store.save() }

class Base {
    init() {}
    class Inner {
        init() {}
        func work() {}
    }
    protocol Delegate { func notify() }
}
class Child: Base {
    class Sub: Inner { func extra() {} }
    protocol SubDelegate: Delegate { func more() }
}

enum WorkerScope {
    actor Worker {}
}
extension WorkerScope.Worker {
    class Cache {
        init() {}
        func clear() {}
    }
    protocol Loader { func load() }
}
nonisolated func useQualifiedActorExtension(_ cache: WorkerScope.Worker.Cache, _ loader: any WorkerScope.Worker.Loader) {
    cache.clear()
    loader.load()
}
