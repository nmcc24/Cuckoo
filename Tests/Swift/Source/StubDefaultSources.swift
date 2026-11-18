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

class Workbench {
    func part() -> any Part {
        fatalError("Mocked in the tests.")
    }
}
