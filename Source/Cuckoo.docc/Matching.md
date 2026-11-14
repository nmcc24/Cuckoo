# Matching arguments and calls

Say which arguments a stub or a `verify` applies to, and how many calls a `verify` expects.

## Overview

Every argument passed to a member in `when(_:)` or `verify` is a matcher. A plain value matches arguments equal
to it; a matcher function matches by any other rule:

```swift
when(stub.greet(name: "Ann")).thenReturn("Hello, Ann")       // equal to "Ann"
when(stub.greet(name: any())).thenReturn("Hi")               // any name
when(stub.store(any(), forKey: "token")).thenDoNothing()     // any value, the key "token"
verify(greeter).greet(name: "Ann".or("Bob"))                 // either name
```

### Values

Strings, characters, `Bool`, the integer and floating-point types, and arrays, sets and dictionaries of them stand
for an equality matcher, and so do their optionals: `"Ann"` matches a `String?` parameter that holds `"Ann"`.

For your own types, pass `equal(to:)`. It takes any `Equatable` value, so the type needs nothing else:

```swift
verify(store).save(equal(to: User(id: 1)))
```

For a type that isn't `Equatable`, or to compare it another way, use `equal(to:equalWhen:)` or a matcher of your
own. Cuckoo 2 had you conform your own types to `Matchable` instead. That's deprecated: the protocol is how
generated mocks take their arguments, and Cuckoo 4 hides it from your code. A conformance of a type you don't own
also needs `@retroactive`.

### Matcher functions

- `any()` matches every argument. Pass the type, `any(Int.self)`, where inference can't pick it. `anyInt()` and
  `anyString()` spell two common ones.
- `equal(to:)` matches an equal value. `sameInstance(as:)` matches the same class instance.
- `isNil()` and `notNil()` match optionals.
- `anyClosure()` and `anyThrowingClosure()` match closure arguments, which can't be compared.
- `not(_:)` inverts a matcher, and `or(_:)` and `and(_:)` combine a matcher or value with another.

### Custom matchers

A ``ParameterMatcher`` decides with a closure:

```swift
func even() -> ParameterMatcher<Int> {
    ParameterMatcher { $0.isMultiple(of: 2) }
}

when(stub.page(number: even())).thenReturn(.left)
```

It combines with values and other matchers: `even().and(not(equal(to: 0)))`.

### Matchers for Sendable mocks

The mock of a `Sendable` type, or of an actor, can be called from any task, so its stubs match arguments
wherever a call comes from. They only take matchers that are safe there: a ``SendableMatcher``, whose closure is
`@Sendable`. Each matcher function returns one when the values it keeps are `Sendable`, and a ``ParameterMatcher``
otherwise, so the same code works with every mock:

```swift
when(cache.lookup(equal(to: "Ann"), limit: isNil())).thenReturn(1)    // SendableMatcher
when(store.save(equal(to: session))).thenReturn(true)                   // ParameterMatcher: Session isn't Sendable
```

A `Sendable` mock rejects the second at compile time: its stub could compare `session` on another thread while
your test changes it. A matcher that takes a closure, such as `containsAnyOf(_:where:)`, returns a
``SendableMatcher`` for a `Sendable` mock and a ``ParameterMatcher`` otherwise, so its closure may capture
non-`Sendable` state when the mock isn't `Sendable`. Write your own with a `@Sendable` closure:

```swift
func even() -> SendableMatcher<Int> {
    SendableMatcher { $0.isMultiple(of: 2) }
}
```

In a project that isolates code to the main actor by default, as new Xcode 26 projects do, a type's `Equatable`
conformance is isolated to the main actor too, so `equal(to:)` returns a ``ParameterMatcher`` for it. That suits
the mocks of main-actor and other non-`Sendable` types. For a `Sendable` mock, make the conformance
`nonisolated`: `struct User: nonisolated Equatable`.

Verification compares arguments right away, in your test, so `verify` takes either kind.

### Collections

Arrays, sets and dictionaries match equal collections. The collection matchers compare part of one instead:

- `containsAllOf(_:)`, `containsAnyOf(_:)` and `containsNoneOf(_:)` match a sequence holding all, any or none of
  the elements, passed as a sequence or one by one after `values:`. For elements that aren't `Equatable`, pass `where:` with a closure that compares two.
- `containsAllKeysOf(_:)`, `containsAllValuesOf(_:)` and their `Any` and `No` versions look at a dictionary's
  keys or values.
- `hasLength(exactly:)`, `hasLength(atLeast:inclusive:)`, `hasLength(atMost:inclusive:)` and
  `hasLength(in:)` match by count. `hasLength(in:)` takes any range of counts and means what it says: `1..<3`
  matches 1 or 2, `1...3` matches 1 to 3, and `2...` matches 2 or more.

```swift
verify(mailer).send(to: containsAllOf(values: "ann@example.com", "bob@example.com"))
verify(cache).store(hasLength(atLeast: 1))
```

### Special arguments

A parameter pack, `repeat each T`, is recorded as one ``ParameterPack``. Match it with `any()`, with
`equal(to:)` and the pack's values when they're `Equatable`, or with a matcher over the whole pack; a `then`
closure receives it as one `ParameterPack` too.

A `~Copyable` argument can't be copied into the recorded call, so the mock records a ``NoncopyableArgument``
placeholder instead. Match it with `any()`. A `then` closure receives the argument itself, borrowed, except for a
generic `T: ~Copyable` or an `inout` argument, which get the placeholder.

A variadic argument, `String...`, is recorded as the array the function receives. Match it with `equal(to:)` and
an array, `equal(to: ["a", "b"])`, with `any()` or a collection matcher; a `then` closure and a captor receive the
array too. Swift can't pass an array on as separate arguments, so the mock can't call the real or default
implementation of a member that takes one: stub it instead.

An `inout` argument is recorded and matched with the value the caller passed in. A `then` closure takes it as `inout`, and what the closure
writes reaches the caller when the call returns.

### Call matchers

The second argument of `verify` is a ``CallMatcher``, which decides whether the calls that matched the member and
its arguments are the expected ones. It's ``times(_:)`` with `1` by default:

- ``times(_:)``: exactly that many calls.
- ``never()``: no call.
- ``atLeastOnce()`` and ``atLeast(_:)``: at least that many.
- ``atMost(_:)``: at most that many.

Combine them with ``CallMatcher/or(_:)`` and ``CallMatcher/and(_:)``:
`verify(log, atLeast(2).and(atMost(4))).write(any())`.
For any other rule, create a `CallMatcher` with a name for failure messages and a closure over the calls:

```swift
let evenTimes = CallMatcher(name: "an even number of times") { $0.count.isMultiple(of: 2) }
verify(log, evenTimes).write(any())
```
