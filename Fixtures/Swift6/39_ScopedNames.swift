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
// protocol is found when it's the module's only one of that name, and a default naming something any type
// declares private is left out, which compiles either way. A parent declared in a superclass's scope is found
// through the subclass, and an actor extended through its qualified name keeps its nested types nonisolated.
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
func passArgument(_ store: MockSettingsStore) { store.save(settings: .shared) }

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

// An `inout` closure through a typealias is mocked, as a variable the caller owns; an internal protocol's
// typealias makes a public class's mock internal; and an actor declared in a module-qualified extension is
// recognised when it's extended the same way.
typealias SwapHandler = () -> Void
class SwapRunner {
    init() {}
    func swap(_ handler: inout SwapHandler) {}
}

protocol Configurable {
    typealias Model = Int
}
open class ConfiguredClient: Configurable {
    public init() {}
    func load(_ model: Model) {}
}

enum QualifiedHost {}
extension Fix.QualifiedHost {
    actor Worker {}
}
extension Fix.QualifiedHost.Worker {
    protocol Job { func run() }
}
nonisolated func runJob(_ job: any Fix.QualifiedHost.Worker.Job) { job.run() }

// A closure typealias used qualified, whose function type names a type of its own scope; one declared in another
// extension of the enclosing type, or in a superclass, found even when an unrelated type shares its name; and a
// typealias of a parent protocol whose target is written relative to its own scope.
class QualifiedUploader {
    struct Receipt {}
    typealias Completion = (Receipt) -> Void
    init() {}
}
protocol QualifiedSender {
    func send(_ completion: QualifiedUploader.Completion)
}

enum ExtendedFeature {}
extension ExtendedFeature {
    typealias Handler = () -> Void
}
extension ExtendedFeature {
    class Worker {
        init() {}
        func run(_ handler: Handler) { handler() }
    }
}
struct UnrelatedRouter {
    struct Handler {}
}

class AliasBase {
    init() {}
    typealias Completion = () -> Void
}
class AliasChild: AliasBase {
    func load(_ completion: Completion) { completion() }
}
enum UnrelatedCompletion {
    enum Completion {}
}

enum RelativeFeature {
    protocol Service { func service() }
    typealias Alias = Service
}
protocol UsesRelativeAlias: RelativeFeature.Alias { func own() }

// Defaults that need private access another way: a member of a `private extension`, which states no access of
// its own, and a type's `fileprivate init`. The mock leaves them out.
private extension Int {
    static let scopedDefaultTimeout = 30
}
struct SigningToken {
    fileprivate init(secret: Int) {}
}
// A type nested in a private extension is private too, through an `#if` as well. A default that only names a type
// with a private init, such as a singleton's `current`, stays in the mock.
private extension SigningToken {
    enum Secret {
        static let value = 1
    }
    #if DEBUG
    enum DebugSecret {
        static let value = 2
    }
    #endif
}
final class ScopedConfig: Sendable {
    static let current = ScopedConfig()
    private init() {}
}
class PrivateDefaults {
    init() {}
    func load(timeout: Int = .scopedDefaultTimeout) {}
    func sign(_ token: SigningToken = SigningToken(secret: 0)) {}
    func secret(_ value: Int = SigningToken.Secret.value) {}
    #if DEBUG
    func debugSecret(_ value: Int = SigningToken.DebugSecret.value) {}
    #endif
    func configure(_ config: ScopedConfig = ScopedConfig.current) {}
}

func configureWithDefault(_ mock: MockPrivateDefaults) {
    mock.configure()
}
