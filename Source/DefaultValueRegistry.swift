/// Default values for unstubbed calls, shared by every test. Prefer `CuckooConfiguration.defaultValues` (or the
/// `.cuckoo(defaultValues:)` trait) for values that only some tests need: those don't leak into tests running in
/// parallel.
public enum DefaultValueRegistry {
    private static let defaultRegisteredTypes: [ObjectIdentifier: any Sendable] = [
        ObjectIdentifier(Void.self): Void(),
        ObjectIdentifier(Int.self): Int(),
        ObjectIdentifier(Int8.self): Int8(),
        ObjectIdentifier(Int16.self): Int16(),
        ObjectIdentifier(Int32.self): Int32(),
        ObjectIdentifier(Int64.self): Int64(),
        ObjectIdentifier(UInt.self): UInt(),
        ObjectIdentifier(UInt8.self): UInt8(),
        ObjectIdentifier(UInt16.self): UInt16(),
        ObjectIdentifier(UInt32.self): UInt32(),
        ObjectIdentifier(UInt64.self): UInt64(),
        ObjectIdentifier(String.self): String(),
        ObjectIdentifier(Bool.self): Bool(),
        ObjectIdentifier(Double.self): Double(),
        ObjectIdentifier(Float.self): Float()
    ]
    
    private static let registeredTypes = Locked(defaultRegisteredTypes)
    
    public static func register<T: Sendable>(value: T, forType type: T.Type) {
        // Boxed explicitly, so a registered `nil` is stored rather than removing the entry.
        let boxed: any Sendable = value
        registeredTypes.withLock { $0[ObjectIdentifier(type)] = boxed }
    }
    
    public static func defaultValue<T>(for type: Set<T>.Type) -> Set<T> {
        return defaultValueOrNil(for: type) ?? []
    }
    
    public static func defaultValue<T>(for type: Array<T>.Type) -> Array<T> {
        return defaultValueOrNil(for: type) ?? []
    }
    
    public static func defaultValue<K, V>(for type: Dictionary<K, V>.Type) -> Dictionary<K, V> {
        return defaultValueOrNil(for: type) ?? [:]
    }
    
    public static func defaultValue<T>(for type: Optional<T>.Type) -> Optional<T> {
        return defaultValueOrNil(for: type) ?? nil
    }
    
    public static func defaultValue<T>(for type: T.Type) -> T {
        if let registeredDefault = defaultValueOrNil(for: type) {
            return registeredDefault
        }
        fatalError("Type \(T.self) does not have default return value registered.")
    }
    
    public static func reset() {
        registeredTypes.withLock { $0 = defaultRegisteredTypes }
    }
    
    /// The value the current configuration or the registry holds for exactly `type`.
    private static func defaultValueOrNil<T>(for type: T.Type) -> T? {
        if let value = CuckooConfiguration.current.defaultValues.value(for: type) {
            return value
        }
        guard let value = registeredTypes.withLock({ $0[ObjectIdentifier(type)] }) else {
            return nil
        }
        return value as? T
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
    
    // Overloads for tuples.
    
    public static func defaultValue<P1, P2>(for type: (P1, P2).Type) -> (P1, P2) {
        if let registeredDefault = defaultValueOrNil(for: type) {
            return registeredDefault
        } else {
            return (defaultValue(for: P1.self), defaultValue(for: P2.self))
        }
    }
    
    public static func defaultValue<P1, P2, P3>(for type: (P1, P2, P3).Type) -> (P1, P2, P3) {
        if let registeredDefault = defaultValueOrNil(for: type) {
            return registeredDefault
        } else {
            return (defaultValue(for: P1.self), defaultValue(for: P2.self), defaultValue(for: P3.self))
        }
    }
    
    public static func defaultValue<P1, P2, P3, P4>(for type: (P1, P2, P3, P4).Type) -> (P1, P2, P3, P4) {
        if let registeredDefault = defaultValueOrNil(for: type) {
            return registeredDefault
        } else {
            return (defaultValue(for: P1.self), defaultValue(for: P2.self), defaultValue(for: P3.self), defaultValue(for: P4.self))
        }
    }
    
    public static func defaultValue<P1, P2, P3, P4, P5>(for type: (P1, P2, P3, P4, P5).Type) -> (P1, P2, P3, P4, P5) {
        if let registeredDefault = defaultValueOrNil(for: type) {
            return registeredDefault
        } else {
            return (defaultValue(for: P1.self), defaultValue(for: P2.self), defaultValue(for: P3.self), defaultValue(for: P4.self), defaultValue(for: P5.self))
        }
    }
    
    public static func defaultValue<P1, P2, P3, P4, P5, P6>(for type: (P1, P2, P3, P4, P5, P6).Type) -> (P1, P2, P3, P4, P5, P6) {
        if let registeredDefault = defaultValueOrNil(for: type) {
            return registeredDefault
        } else {
            return (defaultValue(for: P1.self), defaultValue(for: P2.self), defaultValue(for: P3.self), defaultValue(for: P4.self), defaultValue(for: P5.self), defaultValue(for: P6.self))
        }
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
