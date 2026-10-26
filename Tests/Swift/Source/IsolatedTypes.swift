import Foundation

/// A view model the MainActor stubs below capture, to show that their `then` closures run on the MainActor.
@MainActor
final class RecordingViewModel {
    var events: [String] = []
}

@MainActor
protocol MainActorService {
    var title: String { get set }

    func load(id: Int) -> String
    func refresh() async throws
}

@MainActor
class MainActorViewModel {
    var state = ""

    func select(index: Int) -> Bool {
        true
    }

    func reload() async {
    }
}

@globalActor
actor TestDatabaseActor {
    static let shared = TestDatabaseActor()
}

@TestDatabaseActor
protocol DatabaseStore {
    func save(_ value: String)
    func all() -> [String]
}

protocol CounterStore: Actor {
    var count: Int { get }

    func increment(by amount: Int) -> Int
    func fetch(id: Int) async throws -> String
}

protocol SendableService: Sendable {
    func value(for key: String) -> Int
    func load() async -> String
}

/// Not `Sendable`, so an actor mock must hand it to a `then` closure without capturing it.
nonisolated final class Ledger {
    var entries: [String] = []
}

protocol LedgerStore: Actor {
    var ledger: Ledger { get set }

    func record(_ entry: String, in ledger: Ledger) -> Int
    func archive(_ ledger: Ledger) async -> Int
    subscript(ledger: Ledger) -> String { get }
}

actor RealLedgerStore: LedgerStore {
    var ledger = Ledger()

    func record(_ entry: String, in ledger: Ledger) -> Int {
        ledger.entries.append(entry)
        return ledger.entries.count
    }

    func archive(_ ledger: Ledger) async -> Int {
        ledger.entries.count
    }

    subscript(ledger: Ledger) -> String {
        ledger.entries.joined(separator: ", ")
    }
}
