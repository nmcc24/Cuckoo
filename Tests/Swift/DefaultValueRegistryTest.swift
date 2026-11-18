@testable import Cuckoo
import Testing

/// The registry is global, so these tests register defaults only for types of their own, which no other test uses,
/// and run one at a time because `reset()` clears what the others register.
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
        DefaultValueRegistry.register([Marker(value: 1)], for: [Marker].self)
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

    /// A replaced or reset value is released outside the registry's lock, so a `deinit` that queries the registry
    /// doesn't deadlock.
    @Test
    func replacedAndResetValuesAreReleasedOutsideTheLock() {
        final class QueriesRegistryOnDeinit: Sendable {
            let released: Locked<Bool>
            init(released: Locked<Bool>) {
                self.released = released
            }
            deinit {
                _ = DefaultValueRegistry.defaultValue(for: Int.self)
                released.withLock { $0 = true }
            }
        }
        let replaced = Locked(false)
        let removed = Locked(false)
        DefaultValueRegistry.register(QueriesRegistryOnDeinit(released: replaced))

        DefaultValueRegistry.register(QueriesRegistryOnDeinit(released: removed))
        #expect(replaced.withLock { $0 })

        DefaultValueRegistry.reset()
        #expect(removed.withLock { $0 })
    }

    @Test
    func aFactoryMakesANewValueForEachCall() {
        final class Box {}
        DefaultValueRegistry.register(for: Box.self) { Box() }
        let first = DefaultValueRegistry.defaultValue(for: Box.self)
        let second = DefaultValueRegistry.defaultValue(for: Box.self)
        #expect(first !== second)
        DefaultValueRegistry.reset()
    }

    @Test
    func tupleElementsUseTheirDefaults() {
        let value = DefaultValueRegistry.defaultValue(for: (Int, String?, [Marker], Bool, Int, Int, Int).self)
        #expect(value.0 == 0)
        #expect(value.1 == nil)
        #expect(value.2 == [])
        #expect(value.3 == false)
    }

    /// A tuple's elements get their defaults as any generic type does, which can't name a nested tuple's elements.
    @Test
    func aNestedTupleHasNoDefault() {
        #expect(DefaultValueRegistry.unstubbedValue(for: ((Int, Int), String).self) == nil)
        #expect(MockManager.unstubbedTupleValue(for: ((Int, Int), String).self) == nil)
    }

    @Test
    func genericTypesGetEmptyValues() {
        func defaultValue<T>(of _: T.Type) -> T {
            DefaultValueRegistry.defaultValue(for: T.self)
        }
        #expect(defaultValue(of: Marker?.self) == nil)
        #expect(defaultValue(of: [Marker].self) == [])
    }

    @Test
    func registerValue() {
        let value = Marker(value: 10)
        DefaultValueRegistry.register(value, for: Marker.self)
        #expect(DefaultValueRegistry.defaultValue(for: Marker.self) == value)
    }

    @Test
    func registerSet() {
        let value: Set = [Marker(value: 1)]
        DefaultValueRegistry.register(value, for: Set<Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Set<Marker>.self) == value)
    }

    @Test
    func registerArray() {
        let value = [Marker(value: 1)]
        DefaultValueRegistry.register(value, for: Array<Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Array<Marker>.self) == value)
    }

    @Test
    func registerDictionary() {
        let value = ["A": Marker(value: 1)]
        DefaultValueRegistry.register(value, for: Dictionary<String, Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Dictionary<String, Marker>.self) == value)
    }

    @Test
    func registerOptional() {
        let value = Marker(value: 1) as Marker?
        DefaultValueRegistry.register(value, for: Optional<Marker>.self)
        #expect(DefaultValueRegistry.defaultValue(for: Optional<Marker>.self) == value)
    }

    /// One parameter-pack overload serves every tuple, so the shortest and longest `Equatable` ones cover it.
    @Test
    func registerTuples() {
        let pair = (Marker(value: 1), Marker(value: 2))
        DefaultValueRegistry.register(pair, for: (Marker, Marker).self)
        #expect(DefaultValueRegistry.defaultValue(for: (Marker, Marker).self) == pair)

        let six = (Marker(value: 1), Marker(value: 2), Marker(value: 3), Marker(value: 4), Marker(value: 5),
                   Marker(value: 6))
        DefaultValueRegistry.register(six, for: (Marker, Marker, Marker, Marker, Marker, Marker).self)
        #expect(DefaultValueRegistry.defaultValue(for: (Marker, Marker, Marker, Marker, Marker, Marker).self) == six)
    }
}
