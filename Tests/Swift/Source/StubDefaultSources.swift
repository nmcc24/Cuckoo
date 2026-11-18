/// A protocol the module mocks, so a mock that returns it without a stub answers with a `PartStub`.
protocol Part {
    var name: String { get }
    func weight() -> Int
}

@MainActor
protocol Gauge {
    func reading() -> Int
}

/// Members returning mocked protocols, which have no default value of their own.
protocol Assembly {
    var part: any Part { get }
    func spare() -> any Part
    func optionalPart() -> (any Part)?
    func parts() -> [any Part]
    func gauge() -> any Gauge
    func fetched() async -> any Part
    func checked() throws -> any Part
}

/// A member taking `Self` isn't forwarded to a default implementation, and answers with the default value instead.
protocol Fitting {
    func adapter(to other: Self) -> any Part
}

/// A protocol with an associated type, whose mock forwards through a type eraser, which can't forward an `inout`
/// member and answers with the default value instead.
protocol Crate {
    associatedtype Item
    func first() -> Item?
    func unpack(_ count: inout Int) -> any Part
}

class Workbench {
    func part() -> any Part {
        fatalError("Mocked in the tests.")
    }
}
