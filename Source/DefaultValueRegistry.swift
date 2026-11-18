/// Default values for unstubbed calls, shared by every test. Prefer `CuckooConfiguration.defaultValues` (or the
/// `.cuckoo(defaultValues:)` trait) for values that only some tests need: those don't leak into tests running in
/// parallel.
public enum DefaultValueRegistry {
    private static let defaultRegisteredTypes: [ObjectIdentifier: DefaultValueFactory] = [
        ObjectIdentifier(Void.self): DefaultValueFactory(Void()),
        ObjectIdentifier(Int.self): DefaultValueFactory(Int()),
        ObjectIdentifier(Int8.self): DefaultValueFactory(Int8()),
        ObjectIdentifier(Int16.self): DefaultValueFactory(Int16()),
        ObjectIdentifier(Int32.self): DefaultValueFactory(Int32()),
        ObjectIdentifier(Int64.self): DefaultValueFactory(Int64()),
        ObjectIdentifier(UInt.self): DefaultValueFactory(UInt()),
        ObjectIdentifier(UInt8.self): DefaultValueFactory(UInt8()),
        ObjectIdentifier(UInt16.self): DefaultValueFactory(UInt16()),
        ObjectIdentifier(UInt32.self): DefaultValueFactory(UInt32()),
        ObjectIdentifier(UInt64.self): DefaultValueFactory(UInt64()),
        ObjectIdentifier(String.self): DefaultValueFactory(String()),
        ObjectIdentifier(Bool.self): DefaultValueFactory(Bool()),
        ObjectIdentifier(Double.self): DefaultValueFactory(Double()),
        ObjectIdentifier(Float.self): DefaultValueFactory(Float())
    ]
    
    private static let registeredTypes = Locked(defaultRegisteredTypes)
    
    /// Registers `value` as the default for `type`, replacing any earlier one, for every test.
    public static func register<T: Sendable>(_ value: T, for type: T.Type = T.self) {
        replace(type, with: DefaultValueFactory(value))
    }

    /// Registers `factory` to make the default for `type`, replacing any earlier one, for every test. Each unstubbed
    /// call gets a new value, so `type` needn't be `Sendable`: a class, or a tuple that holds one.
    public static func register<T>(for type: T.Type = T.self, factory: @escaping @Sendable () -> T) {
        replace(type, with: DefaultValueFactory(factory))
    }

    
    /// The registered default for `type`, else an empty value for optionals and the standard collections, even when
    /// `T` is a generic parameter. Crashes when there is none, with a message naming the type.
    public static func defaultValue<T>(for type: T.Type) -> T {
        if let value = unstubbedValue(for: type) {
            return value
        }
        fatalError("Type \(T.self) does not have default return value registered.")
    }
    
    /// Registers `factory` for `type`, releasing the one it replaces after the lock is, since that value's `deinit`
    /// may query the registry.
    private static func replace<T>(_ type: T.Type, with factory: DefaultValueFactory) {
        let replaced = registeredTypes.withLock { $0.updateValue(factory, forKey: ObjectIdentifier(type)) }
        withExtendedLifetime(replaced) {}
    }

    /// Removes every registered default except the built-in ones (numbers, `String`, `Bool`, `Void`).
    public static func reset() {
        // The removed values are released after the lock is, since a value's `deinit` may query the registry.
        // `withExtendedLifetime` keeps them alive that long; a discarded result could be released inside the lock.
        let removed = registeredTypes.withLock { types in
            defer { types = defaultRegisteredTypes }
            return types
        }
        withExtendedLifetime(removed) {}
    }
    
    /// The value the current configuration or the registry holds for exactly `type`.
    private static func defaultValueOrNil<T>(for type: T.Type) -> T? {
        if let value = CuckooConfiguration.current.defaultValues.value(for: type) {
            return value
        }
        return registeredTypes.withLock({ $0[ObjectIdentifier(type)] })?.make(type)
    }

    /// The default value for an unstubbed call returning `T`: a registered value, else an empty value for
    /// optionals and the standard collections. `nil` if there is none.
    static func unstubbedValue<T>(for type: T.Type) -> T? {
        if let value = defaultValueOrNil(for: type) {
            return value
        }
        if let nilLiteral = type as? any ExpressibleByNilLiteral.Type {
            return nilLiteral.init(nilLiteral: ()) as? T
        }
        if let empty = type as? any EmptyInitializable.Type {
            return empty.init() as? T
        }
        return nil
    }
    
    /// The registered default for a tuple type, else each element's default. Crashes when an element has none, with
    /// a message naming the tuple type.
    public static func defaultValue<P1, P2, each P>(for type: (P1, P2, repeat each P).Type) -> (P1, P2, repeat each P) {
        if let value = unstubbedValue(for: type) {
            return value
        }
        fatalError("Type \(type) does not have default return value registered.")
    }

    /// The default value for an unstubbed call returning a tuple: a registered value for the tuple type, else each
    /// element's default. `nil` if an element has none.
    static func unstubbedValue<P1, P2, each P>(for type: (P1, P2, repeat each P).Type) -> (P1, P2, repeat each P)? {
        if let registeredDefault = defaultValueOrNil(for: type) {
            return registeredDefault
        }
        guard let first = unstubbedValue(for: P1.self), let second = unstubbedValue(for: P2.self) else {
            return nil
        }
        let rest = (repeat unstubbedValue(for: (each P).self))
        for element in repeat each rest {
            guard element != nil else {
                return nil
            }
        }
        return (first, second, repeat (each rest)!)
    }
}

/// Makes a registered default value. A `Sendable` value is shared; a factory makes a new value each time.
struct DefaultValueFactory: Sendable {
    private let make: @Sendable () -> Any

    init<T: Sendable>(_ value: T) {
        // Boxed explicitly, so a registered `nil` is returned as a value rather than as no value.
        let boxed: any Sendable = value
        make = { boxed }
    }

    init<T>(_ factory: @escaping @Sendable () -> T) {
        make = { factory() as Any }
    }

    /// A new value, or `nil` if it isn't a `T`.
    func make<T>(_: T.Type) -> T? {
        make() as? T
    }
}

/// Types whose empty value is a sensible answer to an unstubbed call.
protocol EmptyInitializable {
    init()
}

extension Array: EmptyInitializable {}
extension Set: EmptyInitializable {}
extension Dictionary: EmptyInitializable {}
extension ContiguousArray: EmptyInitializable {}
