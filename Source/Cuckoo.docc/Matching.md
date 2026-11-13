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

A value stands for a matcher when its type conforms to ``Matchable``. Strings, characters, `Bool`, the integer and
floating-point types, and arrays, sets and dictionaries of them conform, and their optionals do too: `"Ann"`
matches a `String?` parameter that holds `"Ann"`, through ``OptionalMatchable``.

Make your own `Equatable` type matchable with an empty conformance, and it matches equal values:

```swift
extension User: Matchable {}

verify(store).save(User(id: 1))
```

For a type that isn't `Equatable`, or to compare it another way, use ``equal(to:equalWhen:)-1kl3b``
or a matcher of your own.

### Matcher functions

- ``any(_:)->ParameterMatcher<T>`` matches every argument. Pass the type, `any(Int.self)`, where inference can't
  pick it. `anyInt()` and `anyString()` spell two common ones.
- `equal(to:)` matches an equal value. ``sameInstance(as:)->ParameterMatcher<T>`` matches the same class instance.
- ``isNil()`` and ``notNil()`` match optionals.
- `anyClosure()` and `anyThrowingClosure()` match closure arguments, which can't be compared.
- ``not(_:)`` inverts a matcher, and `or(_:)` and `and(_:)` on any ``Matchable`` combine two.

### Custom matchers

A ``ParameterMatcher`` decides with a closure:

```swift
func even() -> ParameterMatcher<Int> {
    ParameterMatcher { $0.isMultiple(of: 2) }
}

when(stub.page(number: even())).thenReturn(.left)
```

A matcher is ``Matchable`` itself, so it combines with values and other matchers: `even().and(not(equal(to: 0)))`.

### Matchers are Sendable

A mock may be called from any task, and its stubs' matchers run in that task, so a ``ParameterMatcher`` is
`Sendable`. Its closure is `@Sendable`, and the matchers that keep a value need a `Sendable` one: `equal(to:)`, the
`where:` closures and the collection matchers. The argument a matcher checks needn't be `Sendable`, and neither does
the object ``sameInstance(as:)->ParameterMatcher<T>`` keeps, since it only compares identities.

A module built with MainActor default isolation, as a new Xcode 26 project is, makes its types' conformances
MainActor-isolated, and `equal(to:)` can't compare with an isolated `==` from another task. Declare the conformance
`nonisolated`, as in `struct User: nonisolated Equatable`.

To match a value that isn't `Sendable`, make its type `Sendable`, match it by identity, or match the `Sendable`
parts you care about:

```swift
when(stub.save(document: ParameterMatcher { $0.title == "Draft" })).thenReturn(true)
```

`equal(to:)` and ``equal(to:equalWhen:)-2d753`` still accept a value or a function that isn't `Sendable`, deprecated, so an
existing suite compiles with a warning. A closure matcher that captures something that isn't `Sendable` doesn't
compile; ``ParameterMatcher/init(unchecked:)``, also deprecated, takes it while you migrate.

### Collections

Arrays, sets and dictionaries match equal collections. The collection matchers compare part of one instead:

- `containsAllOf(_:)`, `containsAnyOf(_:)` and `containsNoneOf(_:)` match a sequence holding all, any or none of
  the elements, passed as a sequence or one by one after `values:`. For elements that aren't `Equatable`, pass `where:` with a closure that compares two.
- `containsAllKeysOf(_:)`, `containsAllValuesOf(_:)` and their `Any` and `No` versions look at a dictionary's
  keys or values.
- `hasLength(exactly:)`, `hasLength(atLeast:inclusive:)`, `hasLength(atMost:inclusive:)` and
  `hasLength(inRange:)` match by count. `hasLength(inRange:)` takes any range of counts, such as `1..<3` or `2...`.

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
