import Cuckoo
import Testing

/// The registry is global, so these tests register defaults for `Marker` only, which no other test uses, and run
/// one at a time because `reset()` clears what the others register.
@Suite(.serialized)
struct DefaultValueRegistryTest {
    private struct Marker: Sendable, Hashable {
        let value: Int
    }

    init() {
        DefaultValueRegistry.reset()
    }

    @Test
    func reset() {
        DefaultValueRegistry.register(value: [Marker(value: 1)], forType: [Marker].self)
        DefaultValueRegistry.reset()
        #expect(DefaultValueRegistry.defaultValue(for: [Marker].self) == [])
    }

    @Test
    func resetKeepsBuiltInDefaults() {
        DefaultValueRegistry.reset()
        #expect(DefaultValueRegistry.defaultValue(for: Int.self) == 0)
        #expect(DefaultValueRegistry.defaultValue(for: String.self) == "")
        #expect(DefaultValueRegistry.defaultValue(for: Bool.self) == false)
    }

    @Test
    func registerValue() {
        let value = Marker(value: 10)
        DefaultValueRegistry.register(value: value, forType: Marker.self)
        #expect(DefaultValueRegistry.defaultValue(for: Marker.self) == value)
    }

    @Test
    func registerSet() {
        let value: Set = [Marker(value: 1)]
        DefaultValueRegistry.register(value: value, forType: Set<Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Set<Marker>.self) == value)
    }

    @Test
    func registerArray() {
        let value = [Marker(value: 1)]
        DefaultValueRegistry.register(value: value, forType: Array<Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Array<Marker>.self) == value)
    }

    @Test
    func registerDictionary() {
        let value = ["A": Marker(value: 1)]
        DefaultValueRegistry.register(value: value, forType: Dictionary<String, Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Dictionary<String, Marker>.self) == value)
    }

    @Test
    func registerOptional() {
        let value = Marker(value: 1) as Marker?
        DefaultValueRegistry.register(value: value, forType: Optional<Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Optional<Marker>.self) == value)
    }

    @Test
    func registerTuple2() {
        let value = (Marker(value: 1), Marker(value: 2))
        DefaultValueRegistry.register(value: value, forType: (Marker, Marker).self)
        #expect(DefaultValueRegistry.defaultValue(for: (Marker, Marker).self) == value)
    }

    @Test
    func registerTuple3() {
        let value = (Marker(value: 1), Marker(value: 2), Marker(value: 3))
        DefaultValueRegistry.register(value: value, forType: (Marker, Marker, Marker).self)
        #expect(DefaultValueRegistry.defaultValue(for: (Marker, Marker, Marker).self) == value)
    }

    @Test
    func registerTuple4() {
        let value = (Marker(value: 1), Marker(value: 2), Marker(value: 3), Marker(value: 4))
        DefaultValueRegistry.register(value: value, forType: (Marker, Marker, Marker, Marker).self)
        #expect(DefaultValueRegistry.defaultValue(for: (Marker, Marker, Marker, Marker).self) == value)
    }

    @Test
    func registerTuple5() {
        let value = (Marker(value: 1), Marker(value: 2), Marker(value: 3), Marker(value: 4), Marker(value: 5))
        DefaultValueRegistry.register(value: value, forType: (Marker, Marker, Marker, Marker, Marker).self)
        #expect(DefaultValueRegistry.defaultValue(for: (Marker, Marker, Marker, Marker, Marker).self) == value)
    }

    @Test
    func registerTuple6() {
        let value = (Marker(value: 1), Marker(value: 2), Marker(value: 3), Marker(value: 4), Marker(value: 5),
                     Marker(value: 6))
        DefaultValueRegistry.register(value: value, forType: (Marker, Marker, Marker, Marker, Marker, Marker).self)
        #expect(DefaultValueRegistry.defaultValue(for: (Marker, Marker, Marker, Marker, Marker, Marker).self) == value)
    }
}
