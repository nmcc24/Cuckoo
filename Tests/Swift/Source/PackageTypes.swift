// `package` declarations, which a mock in another module of the same package can see and override.
package protocol PackageService {
    func run(_ value: Int) -> Int
}

package class PackageWorker {
    package init() {}

    package func work() -> String {
        "real"
    }
}

/// A public actor protocol: its mock is an actor whose `init()` can't be `nonisolated`.
public protocol PublicActorService: Actor {
    func count() -> Int
}

/// Public protocols bound to a class: their mocks subclass it and inherit its initializers.
open class PublicServiceBase {
    public let id: Int

    public init(id: Int) {
        self.id = id
    }
}

public protocol PublicBoundService: PublicServiceBase {
    func describe() -> String
}

open class PublicPlainBase {
    public init() {}
}

public protocol PublicPlainBoundService: PublicPlainBase {
    func ping() -> Bool
}

/// A public class whose only initializer is the implicit, internal `init()`: its mock and stub declare a public one.
open class PublicImplicitWorker {
    open func work() -> Int {
        1
    }
}

public protocol PublicImplicitBoundService: PublicImplicitWorker {
    func check() -> Bool
}
