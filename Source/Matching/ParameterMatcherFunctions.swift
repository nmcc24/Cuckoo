/// Returns an equality matcher.
public func equal<T: Equatable & Sendable>(to value: T) -> ParameterMatcher<T> {
    equal(to: value, equalWhen: ==)
}

/// Returns an equality matcher for a value that isn't `Sendable`, which the matcher calls `==` on from the task that
/// calls the mock.
@available(*, deprecated, message: "A matcher may run on any task that calls the mock; match a Sendable value with a nonisolated Equatable conformance, or use sameInstance(as:) for a class instance.")
public func equal<T: Equatable & SendableMetatype>(to value: T) -> ParameterMatcher<T> {
    let value = UncheckedSendable(value)
    return ParameterMatcher { value.value == $0 }
}

/// Returns an identity matcher. Disfavored, so an `Equatable` class compares with `==`.
@available(*, deprecated, renamed: "sameInstance(as:)", message: "equal(to:) compares an Equatable class with ==; use sameInstance(as:) to compare identity.")
@_disfavoredOverload
public func equal<T: AnyObject>(to value: T) -> ParameterMatcher<T> {
    sameInstance(as: value)
}

/// Returns an equality matcher for Array<Equatable> (ordered)
public func equal<T: Equatable & Sendable>(to array: [T]) -> ParameterMatcher<[T]> {
    equal(to: array) { $0 == $1 }
}

/// Returns an equality matcher for Set<Equatable>
public func equal<T: Sendable>(to set: Set<T>) -> ParameterMatcher<Set<T>> {
    equal(to: set) { $0 == $1 }
}

/// Returns an equality matcher for Dictionary<Hashable, Equatable>
public func equal<K: Hashable & Sendable, V: Equatable & Sendable>(to dictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    equal(to: dictionary) { $0 == $1 }
}

/// Returns a matcher using the supplied function.
public func equal<T: Sendable>(
    to value: T,
    equalWhen equalityFunction: @escaping @Sendable (T, T) -> Bool
) -> ParameterMatcher<T> {
    ParameterMatcher {
        equalityFunction(value, $0)
    }
}

/// Returns a matcher using the supplied function, for a value or function that isn't `Sendable`.
@available(*, deprecated, message: "A matcher may run on any task that calls the mock; match a Sendable value with a nonisolated Equatable conformance, or use sameInstance(as:) for a class instance.")
@_disfavoredOverload
public func equal<T>(
    to value: T,
    equalWhen equalityFunction: @escaping (T, T) -> Bool
) -> ParameterMatcher<T> {
    let captured = UncheckedSendable((value, equalityFunction))
    return ParameterMatcher {
        captured.value.1(captured.value.0, $0)
    }
}

/// Returns a matcher matching any Int value.
public func anyInt() -> ParameterMatcher<Int> {
    ParameterMatcher()
}

/// Returns a matcher matching any String value.
public func anyString() -> ParameterMatcher<String> {
    ParameterMatcher()
}

/// Returns a matcher matching any T value or nil.
public func any<T>(_ type: T.Type = T.self) -> ParameterMatcher<T> {
    ParameterMatcher()
}

/// Returns a matcher matching any T value or nil.
public func any<T>(_ type: T.Type = T.self) -> ParameterMatcher<T?> {
    ParameterMatcher()
}

/// Returns an equality matcher.
public func equal<T: Equatable & Sendable>(to value: T?) -> ParameterMatcher<T?> {
    equal(to: value) { $0 == $1 }
}

/// Returns an equality matcher for a value that isn't `Sendable`, which the matcher calls `==` on from the task that
/// calls the mock.
@available(*, deprecated, message: "A matcher may run on any task that calls the mock; match a Sendable value with a nonisolated Equatable conformance, or use sameInstance(as:) for a class instance.")
public func equal<T: Equatable & SendableMetatype>(to value: T?) -> ParameterMatcher<T?> {
    let value = UncheckedSendable(value)
    return ParameterMatcher { value.value == $0 }
}

/// Returns an identity matcher. Disfavored, so an `Equatable` class compares with `==`.
@available(*, deprecated, renamed: "sameInstance(as:)", message: "equal(to:) compares an Equatable class with ==; use sameInstance(as:) to compare identity.")
@_disfavoredOverload
public func equal<T: AnyObject>(to value: T?) -> ParameterMatcher<T?> {
    sameInstance(as: value)
}

/// Returns an identity matcher. It keeps the object alive and compares identities only, so the object needn't be
/// `Sendable`.
public func sameInstance<T: AnyObject>(as object: T?) -> ParameterMatcher<T?> {
    let identity = Identity(object: object)
    return ParameterMatcher { identity.isSame(as: $0) }
}

/// Returns an identity matcher. It keeps the object alive and compares identities only, so the object needn't be
/// `Sendable`.
public func sameInstance<T: AnyObject>(as object: T) -> ParameterMatcher<T> {
    let identity = Identity(object: object)
    return ParameterMatcher { identity.isSame(as: $0) }
}

/// Returns a matcher using the supplied function.
public func equal<T: Sendable>(to value: T?, equalWhen equalityFunction: @escaping @Sendable (T?, T?) -> Bool) -> ParameterMatcher<T?> {
    ParameterMatcher {
        equalityFunction(value, $0)
    }
}

/// Returns a matcher using the supplied function, for a value or function that isn't `Sendable`.
@available(*, deprecated, message: "A matcher may run on any task that calls the mock; match a Sendable value with a nonisolated Equatable conformance, or use sameInstance(as:) for a class instance.")
@_disfavoredOverload
public func equal<T>(to value: T?, equalWhen equalityFunction: @escaping (T?, T?) -> Bool) -> ParameterMatcher<T?> {
    let captured = UncheckedSendable((value, equalityFunction))
    return ParameterMatcher {
        captured.value.1(captured.value.0, $0)
    }
}

/// Returns a matcher matching any Int value.
public func anyInt() -> ParameterMatcher<Int?> {
    notNil()
}

/// Returns a matcher matching any String value.
public func anyString() -> ParameterMatcher<String?> {
    notNil()
}

/// Returns a matcher matching any non-`nil` optional throwing closure.
public func anyOptionalThrowingClosure<IN, OUT>() -> ParameterMatcher<(((IN)) throws -> OUT)?> {
    notNil()
}

/// Returns a matcher matching any non-nil value.
public func notNil<T>() -> ParameterMatcher<T?> {
    ParameterMatcher {
        $0 != nil
    }
}

/// Returns a matcher matching any nil value.
public func isNil<T>() -> ParameterMatcher<T?> {
    ParameterMatcher {
        $0 == nil
    }
}

/// Returns a matcher negating any matcher it's applied to.
public func not<T>(_ matcher: ParameterMatcher<T>) -> ParameterMatcher<T> {
    ParameterMatcher { value in
        !matcher.matches(value)
    }
}
