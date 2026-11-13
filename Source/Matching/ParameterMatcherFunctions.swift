// Each matcher that keeps a value comes in two kinds: a `SendableMatcher` when the value is `Sendable`, which every
// mock accepts, and a `ParameterMatcher` otherwise, which a `Sendable` mock rejects. The `Sendable` one wins when
// both apply. Where a closure decides, it loses instead, so a closure that captures non-`Sendable` state still
// compiles for a mock that isn't `Sendable`.

/// Returns an equality matcher.
public func equal<T: Equatable & Sendable>(to value: T) -> SendableMatcher<T> {
    SendableMatcher { $0 == value }
}

/// Returns an equality matcher, for a value that isn't `Sendable` or whose `==` is isolated to an actor.
public func equal<T: Equatable>(to value: T) -> ParameterMatcher<T> {
    ParameterMatcher { $0 == value }
}

/// Returns an identity matcher. Disfavored, so an `Equatable` class compares with `==`.
@available(*, deprecated, renamed: "sameInstance(as:)", message: "equal(to:) compares an Equatable class with ==; use sameInstance(as:) to compare identity.")
@_disfavoredOverload
public func equal<T: AnyObject>(to value: T) -> ParameterMatcher<T> {
    equal(to: value, equalWhen: ===)
}

/// Returns an equality matcher for Array<Equatable> (ordered)
public func equal<T: Equatable & Sendable>(to array: [T]) -> SendableMatcher<[T]> {
    SendableMatcher { $0 == array }
}

/// Returns an equality matcher for Array<Equatable> (ordered)
public func equal<T: Equatable>(to array: [T]) -> ParameterMatcher<[T]> {
    ParameterMatcher { $0 == array }
}

/// Returns an equality matcher for Set<Equatable>
public func equal<T: Sendable>(to set: Set<T>) -> SendableMatcher<Set<T>> {
    SendableMatcher { $0 == set }
}

/// Returns an equality matcher for Set<Equatable>
public func equal<T>(to set: Set<T>) -> ParameterMatcher<Set<T>> {
    ParameterMatcher { $0 == set }
}

/// Returns an equality matcher for Dictionary<Hashable, Equatable>
public func equal<K: Hashable & Sendable, V: Equatable & Sendable>(to dictionary: [K: V]) -> SendableMatcher<[K: V]> {
    SendableMatcher { $0 == dictionary }
}

/// Returns an equality matcher for Dictionary<Hashable, Equatable>
public func equal<K: Hashable, V: Equatable>(to dictionary: [K: V]) -> ParameterMatcher<[K: V]> {
    ParameterMatcher { $0 == dictionary }
}

/// Returns a matcher using the supplied function.
@_disfavoredOverload
public func equal<T: Sendable>(
    to value: T,
    equalWhen equalityFunction: @escaping @Sendable (T, T) -> Bool
) -> SendableMatcher<T> {
    SendableMatcher {
        equalityFunction(value, $0)
    }
}

/// Returns a matcher using the supplied function.
public func equal<T>(
    to value: T,
    equalWhen equalityFunction: @escaping (T, T) -> Bool
) -> ParameterMatcher<T> {
    ParameterMatcher {
        equalityFunction(value, $0)
    }
}

/// Returns a matcher matching any Int value.
public func anyInt() -> SendableMatcher<Int> {
    SendableMatcher()
}

/// Returns a matcher matching any String value.
public func anyString() -> SendableMatcher<String> {
    SendableMatcher()
}

/// Returns a matcher matching any T value or nil.
public func any<T>(_ type: T.Type = T.self) -> SendableMatcher<T> {
    SendableMatcher()
}

/// Returns a matcher matching any T value or nil.
public func any<T>(_ type: T.Type = T.self) -> SendableMatcher<T?> {
    SendableMatcher()
}

/// Returns an equality matcher.
public func equal<T: Equatable & Sendable>(to value: T?) -> SendableMatcher<T?> {
    SendableMatcher { $0 == value }
}

/// Returns an equality matcher, for a value that isn't `Sendable` or whose `==` is isolated to an actor.
public func equal<T: Equatable>(to value: T?) -> ParameterMatcher<T?> {
    ParameterMatcher { $0 == value }
}

/// Returns an identity matcher. Disfavored, so an `Equatable` class compares with `==`.
@available(*, deprecated, renamed: "sameInstance(as:)", message: "equal(to:) compares an Equatable class with ==; use sameInstance(as:) to compare identity.")
@_disfavoredOverload
public func equal<T: AnyObject>(to value: T?) -> ParameterMatcher<T?> {
    equal(to: value, equalWhen: ===)
}

/// Returns an identity matcher. It compares identities only, so it's `Sendable` for any class.
public func sameInstance<T: AnyObject>(as object: T?) -> SendableMatcher<T?> {
    let identity = Identity(object: object)
    return SendableMatcher { identity.isSame(as: $0) }
}

/// Returns an identity matcher. It compares identities only, so it's `Sendable` for any class.
public func sameInstance<T: AnyObject>(as object: T) -> SendableMatcher<T> {
    let identity = Identity(object: object)
    return SendableMatcher { identity.isSame(as: $0) }
}

/// Returns a matcher using the supplied function.
@_disfavoredOverload
public func equal<T: Sendable>(
    to value: T?,
    equalWhen equalityFunction: @escaping @Sendable (T?, T?) -> Bool
) -> SendableMatcher<T?> {
    SendableMatcher {
        equalityFunction(value, $0)
    }
}

/// Returns a matcher using the supplied function.
public func equal<T>(to value: T?, equalWhen equalityFunction: @escaping (T?, T?) -> Bool) -> ParameterMatcher<T?> {
    ParameterMatcher {
        equalityFunction(value, $0)
    }
}

/// Returns a matcher matching any Int value.
public func anyInt() -> SendableMatcher<Int?> {
    notNil()
}

/// Returns a matcher matching any String value.
public func anyString() -> SendableMatcher<String?> {
    notNil()
}

/// Returns a matcher matching any non-`nil` optional throwing closure.
public func anyOptionalThrowingClosure<IN, OUT>() -> SendableMatcher<(((IN)) throws -> OUT)?> {
    notNil()
}

/// Returns a matcher matching any non-nil value.
public func notNil<T>() -> SendableMatcher<T?> {
    SendableMatcher {
        $0 != nil
    }
}

/// Returns a matcher matching any nil value.
public func isNil<T>() -> SendableMatcher<T?> {
    SendableMatcher {
        $0 == nil
    }
}

/// Returns a matcher negating any matcher it's applied to.
public func not<T>(_ matcher: SendableMatcher<T>) -> SendableMatcher<T> {
    SendableMatcher { value in
        !matcher.matches(value)
    }
}

/// Returns a matcher negating any matcher it's applied to.
public func not<T>(_ matcher: ParameterMatcher<T>) -> ParameterMatcher<T> {
    ParameterMatcher { value in
        !matcher.matches(value)
    }
}

/// An object kept for its identity. Comparing identities with `===` reads no state of the object, so this is safe
/// whether or not the object is `Sendable`.
struct Identity<Object: AnyObject>: @unchecked Sendable {
    let object: Object?

    func isSame(as other: Object?) -> Bool {
        object === other
    }
}
