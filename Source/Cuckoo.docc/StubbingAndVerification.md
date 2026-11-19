# Stubbing and verification

Decide what a mock's members do, then check the calls they received.

## Overview

A test stubs the members the code under test will call, runs that code, and verifies the calls that matter. The
examples use this protocol and its generated mock, `MockGreeter`:

```swift
protocol Greeter {
    var name: String { get set }
    func greet(name: String) -> String
    func load(id: Int) async throws -> String
}
```

### Create a mock

A mock has the initializers of the type it mocks: `MockGreeter()` for a protocol, and the class's own
initializers for a class. A mock whose initializer calls its own members needs those stubbed before it exists;
``createMock(_:configuration:)`` stubs it first, and its ``MockBuilder``
enables a superclass spy before the initializer runs:

```swift
let store = createMock(MockSettingsStore.self) { builder, stub in
    when(stub.load()).thenReturn(Settings.default) // SettingsStore's init calls load().
    return MockSettingsStore(path: "settings.json")
}
```

Only mocks of the requested type pick up those stubs; other mocks created in the closure are separate.

The mock of a protocol with associated types is generic over them, as `MockStore<String>` for
`protocol Store { associatedtype Item }`. So a method, subscript or initializer that declares a generic parameter
named like one of those associated types, as `func convert<Item>(_ value: Item)` in `Store`, can't be mocked: Swift
accepts it in the protocol but not in the generic mock, which already declares `Item`. Rename the member's generic
parameter.

Mocks keep the isolation of the type they mock. The mock of a `@MainActor` protocol is `@MainActor`, the mock of
an `actor` protocol is an actor, and the mock of a `Sendable` type is `Sendable`, so the compiler checks how the
test shares it. A protocol that states no isolation of its own takes its parents', as Swift does: the mock of a
protocol refining a `@MainActor` protocol is `@MainActor` too. A parent declared in another module, which the
generator doesn't read, can't pass its isolation on; state it on the protocol you mock.

Verifying reads the arguments a mock recorded, so it runs where the mock does. The verification proxy of a
`@MainActor` mock is `@MainActor`, and so is the proxy of a mock of another global actor: verify such a mock from a
test on that actor, or inside `await MainActor.run { }`. Otherwise a test could read an argument while the mock's
actor still changes it, for example in ``eventually(timeout:pollingInterval:_:)`` while the code under test is
still running. ``verifyNoMoreInteractions(_:fileID:filePath:line:column:isolation:)-(Mock...,_,_,_,_,_)`` takes
mocks of any isolation, so it checks at run time: called off a mock's global actor, it records a failure instead
of reading that mock's calls. The compiler can't check an `actor` mock this way, since its proxy would need `await`
on every `verify`: don't verify an actor mock while a call to it may still be running.

### Stub members

``stub(_:block:)-(M,_)`` hands its block a stubbing proxy with one member for each of the mock's. Pass a call on
that proxy to ``when(_:)``, with matchers for its arguments, and say what the call does:

```swift
let greeter = MockGreeter()
stub(greeter) { stub in
    when(stub.greet(name: any())).then { name in "Hi, \(name)" }
    when(stub.greet(name: "Ann")).thenReturn("Hello, Ann")
    when(stub.load(id: 0)).thenThrow(LoadError.missing)
    when(stub.name.get).thenReturn("Greeter")
    when(stub.name.set(any())).thenDoNothing()
}
```

- `thenReturn(_:_:)` returns its values one per call; the last one repeats. `thenReturn(inOrder:)` takes them as
  an array.
- `then(_:)` runs a closure with the call's arguments and returns its result.
- `thenThrow(_:_:)` throws, for members that throw.
- `thenDoNothing()` returns, for members that return `Void`.
- `thenCallRealImplementation()` calls the superclass's implementation, for class mocks.

Each returns the stub, so actions chain: `when(stub.load(id: 1)).thenReturn("A").thenThrow(LoadError.missing)`
returns `"A"` once, then throws on every later call. The actions a member offers depend on its signature:
`thenThrow` exists only for a throwing member.

Properties are stubbed through `get` and `set`, and subscripts the same way: `when(stub[0].get)`.

When several stubs match a call, the one made last wins. Stub the general case first and the special ones after:

```swift
when(stub.greet(name: any())).thenReturn("Hi")
when(stub.greet(name: "Ann")).thenReturn("Hello, Ann") // Ann gets this one; anyone else gets "Hi".
```

What `thenReturn` accepts follows from the mocked type's isolation, which ``StubSharing`` describes. The mock of a
`Sendable` type can be called from any task, so its stubs return `Sendable` values; a `@MainActor` mock's
closures run on the main actor and can use its state directly. A `nonisolated` member of a `@MainActor` or other
global-actor type can be called from any task too, so its stubs take `Sendable` values like a `Sendable` mock's;
for a value that isn't, return a new one from `then { Token() }`.

### Calls with no stub

A call that no stub matches records a failure that lists the member's stubs and the argument each one rejected.
Then it answers, so the test can go on: a member that throws `any Error` throws ``CuckooError/unstubbedCall(method:)``,
and any other member, a `rethrows` one included, returns a default value from ``CuckooConfiguration/defaultValues`` or
``DefaultValueRegistry``. Optionals and the standard collections default to empty, the integer types, `Float`,
`Double`, `String` and `Bool` to zero, `""` and `false`, and a flat tuple the member spells out to its elements'
defaults.

A mock also builds a default itself for some types that the same Cuckoofile module's sources declare:

- A protocol the module mocks: `any Engine` answers with a new `EngineStub`, the generated type whose members do
  nothing and return default values.
- A struct with an initializer that takes no arguments: `Settings()`. That's an `init()` it declares, its only
  initializer whose parameters all have default values, or the implicit one when every stored property has a
  default value. The call runs that initializer, and the default expressions of the stored properties with it.
- An enum: its first case without associated values.

A class or an actor has no such default, since creating one can do anything: stub the member, or register a
factory for the type.

The members of a generated `…Stub` return the same defaults, so a stub that an unstubbed call returned can be used
further. An optional of such a type stays `nil` and a collection empty. Only a type the generator can be sure of gets such
a default, so these have none:

- a generic type, a protocol with associated types, and a composition such as `any Engine & Sendable`;
- a type declared under `#if` or `@available`, and a type of another module, such as `Foundation.Locale`;
- a protocol with an initializer requirement or a required superclass, and one whose stub the mock can't name,
  because a type nested nearer to the mock has the stub's name;
- a struct or an enum with an attribute that may isolate it, such as `@MainActor`, or nested in such a type (a
  `@MainActor` protocol does get its stub);
- a struct with a conformance other than the standard library's common ones (`Sendable`, `Equatable`, `Hashable`,
  `Codable` and the like), which may isolate it;
- a struct whose initializer is failable, throwing, `async`, `private` or carries an attribute, and one with an
  initializer declared in an extension, which can make `Settings()` ambiguous;
- a struct whose initializer is internal, an implicit one included, in the mock of a `public` type, unless the
  Cuckoofile's `sources` name the struct's module and `testableImports` lists it;
- every struct of a module with `defaultIsolation = "MainActor"`, whose initializers run on the main actor.

Register a value for any other type, a tuple behind a `typealias` or nested in another tuple included, or a call
returning it crashes with a message naming it. A registered value also replaces a default the mock builds, under
the type the member returns: `(any Engine).self` for a protocol.

```swift
@Test(.cuckoo(defaultValues: {
    var values = DefaultValues()
    values.register(User.guest)
    return values
}()))
func showsTheGuest() { … }
```

A type that isn't `Sendable`, such as a class, registers a factory instead, which makes a new value for each
call: `values.register(for: Canvas.self) { Canvas() }`.

A mock keeps the default values of the scope it was created in, so an unstubbed call from a `Task.detached` or a
dispatch queue, which don't see the trait, still gets them. They also fill in for the types an inner scope doesn't
register: the call's scope wins only for the types it has a value for.

``DefaultValueRegistry/register(_:for:)`` registers a value for every test instead, which tests running in
parallel all see. Prefer the trait.

### Default implementations and spies

``Mock/enableDefaultImplementation(_:)`` makes every member without a stub forward to a real implementation, while
the mock still records the calls:

```swift
let greeter = MockGreeter().withEnabledDefaultImplementation(RealGreeter())
stub(greeter) { stub in
    when(stub.load(id: any())).thenThrow(LoadError.offline) // Everything else is RealGreeter's.
}
```

A `struct` passed in is copied once: changes made through the mock stay in the mock's copy, and later changes to
your own variable don't reach it. Pass a class instance to share state with the test. Enable it before the mock's
first call, as the spy below; calling it again later only replaces the implementation. A mock has either a default
implementation or a superclass spy, not both. Actor mocks have no default implementation: forwarding a call's
arguments to another actor would race. Stub their members instead.

The mock of a class can call the class itself. ``ClassMock/enableSuperclassSpy()``, or `withEnabledSuperclassSpy()`
when creating it, makes every unstubbed member call the superclass, so the mock acts as a spy. Enable it before the
mock's first call, or the test stops: a mock that has already answered calls can't change how it answers. A class
whose initializer calls its own members has made calls by then, so enable the spy with
``createMock(_:configuration:)``'s ``MockBuilder/enableSuperclassSpy()``, which applies before the initializer runs.

Each generated mock `MockGreeter` comes with `GreeterStub`, a type with no stubbing or verification whose members
return default values and do nothing else. `MockGreeter().withEnabledDefaultImplementation(GreeterStub())` makes
every unstubbed call of a mock answer quietly, except members a mock can't forward to another implementation:
those with a variadic or `~Copyable` parameter, or that take or return `Self`. Calling one unstubbed stops the
test, so stub those.

### Static members

Static and class members have no instance to hold their stubs, and Swift Testing runs tests in parallel, so their
stubs live in a registry each test gets of its own. The `.cuckoo()` trait gives every test it applies to one:

```swift
@Suite(.cuckoo())
struct ClockTests {
    @Test func usesTheStubbedTime() {
        stub(MockClock.self) { stub in
            when(stub.now.get).thenReturn(.distantPast)
        }
        // …
        verify(MockClock.self).now.get()
    }
}
```

In XCTest, or anywhere else without the trait, wrap the code in ``withStaticStubs(_:)-9n6r1``, or its `async`
version. Tasks started inside the scope see its stubs; a `Task.detached`, a dispatch queue or a notification
doesn't, and its static calls fail as unstubbed. Such a failure belongs to no test, so it goes to XCTest, and Swift
Testing doesn't see it: make static calls inside the test's own tasks.

`reset`, `clearStubs`, `clearInvocations` and `verifyNoMoreInteractions` take mock types too, as in
`verifyNoMoreInteractions(MockClock.self)`, and act on the current scope's stubs and calls.

Operators are static members too. A Swift member can't be named `+`, so the proxies name each operator `operator`
followed by a word for each of its characters: `+` is `operatorPlus`, `==` is `operatorEqualEqual` and `<~>` is
`operatorLessTildeGreater`. A prefix or postfix operator starts with its fixity, as in `prefixOperatorMinus` and
`postfixOperatorPlusPlus`. The words are `Slash`, `Equal`, `Minus`, `Plus`, `Bang`, `Star`, `Percent`, `Less`,
`Greater`, `Amp`, `Pipe`, `Caret`, `Tilde`, `Question` and `Dot`; any other character is its Unicode scalar, such
as `operatorU2295` for `⊕`. Their arguments have no labels:

```swift
stub(MockVector.self) { stub in
    when(stub.operatorPlus(any(), any())).thenReturn(sum)
}
#expect(MockVector() + MockVector() === sum)
verify(MockVector.self).operatorPlus(any(), any())
```

A class's own operators are final, so its mock keeps the real ones. Operators the mocked protocol inherits from
another module, such as `Equatable`'s `==`, aren't mocked, like any member the generator doesn't read.

### Verify calls

``verify(_:_:fileID:filePath:line:column:)->M.CuckooVerification`` checks that the mock received a call, once unless
a call matcher says otherwise:

```swift
verify(greeter).greet(name: "Ann")
verify(greeter, times(2)).load(id: any())
verify(greeter, never()).greet(name: "Bob")
verify(greeter).name.get()
verify(greeter).name.set("New")
verifyNoMoreInteractions(greeter)
```

A failed `verify` lists the calls the member received, each with the first argument that didn't match, or every
call the mock received if the member had none. ``verifyNoMoreInteractions(_:fileID:filePath:line:column:isolation:)-(Mock...,_,_,_,_,_)``
fails if the mock received a call no `verify` checked.

A generic member whose type comes only from its return value needs the type spelled out, on the ``VerifiedCall``
that `verify` returns:

```swift
verify(cache).value(forKey: "a").with(returnType: Int?.self)
```

The `verify` counts only the calls made with that return type, as a stub answers only the calls of its own.

### Order and timing

``inOrder(strict:fileID:filePath:line:column:_:)`` checks that calls happened in the order of the `verify`
calls in its block, across mocks. With `strict: true`, no other call to those mocks may come in between:

```swift
inOrder {
    verify(database).open()
    verify(cache, times(2)).store(any())
    verify(database).close()
}
```

A count means the same as outside `inOrder`: `times(1)` fails on two calls in a row. Each `verify` takes the calls
after the ones the previous `verify` took: all of its matching calls there if its count accepts them, else the first
run of matching calls that no other call to the verified mocks interrupts. So `times(2)` passes on two calls in a
row even when the same call comes again later, for a later `verify` to take.

The block's `verify` calls are checked when it ends, so an ``ArgumentCaptor`` used in one fills only after the
block: read it after `inOrder` returns. A `verifyNoMoreInteractions` inside the block waits too, and sees the calls
the `verify` calls before it took. Keep every `verify` inside the block itself: one in a `Task` the block starts that
runs after the block ends records a failure, since it can no longer be checked. A `Task.detached` or a dispatch
queue isn't part of the block: a `verify` there is checked on its own, outside the order.

``eventually(timeout:pollingInterval:_:)`` retries its block until its `verify` calls pass, for code that calls a
mock from a task it starts:

```swift
viewModel.refresh()
await eventually {
    verify(service).fetch(any())
}
```

It checks that something becomes true. `verify(service, never())` passes on the first try, before the code under
test has run.

### Capture arguments

An ``ArgumentCaptor`` records the arguments a `verify` matches, so the test can look at them:

```swift
let names = ArgumentCaptor<String>()
verify(greeter, times(2)).greet(name: names.capture())
#expect(names.allValues == ["Ann", "Bob"])
#expect(names.value == "Bob")
```

A captor captures only the calls a passing `verify` matched, or, in a stub, the calls that stub answered: a call
another matcher rejected isn't captured. Give a stub and a `verify` captors of their own: one captor in both records
each call twice, once when the stub answers it and once when the `verify` matches it.

A captor can keep a closure argument only if the parameter is `@escaping`. Any other closure can't outlive the call
it was passed to: a `verify` captures a stand-in that crashes when called, and a stub's captor crashes when the
stubbed call returns. Call such a closure from the stub's `then` closure instead.

### Reset a mock

- ``reset(_:)-(Mock...)`` clears a mock's stubs and recorded calls.
- ``clearStubs(_:)-(Mock...)`` clears only the stubs.
- ``clearInvocations(_:)-(Mock...)`` clears only the recorded calls.

Each takes mock types too, for their static members, as described in "Static members" above.

### Where failures go

Failures go to the framework running the test: Swift Testing records an issue, and XCTest an `XCTFail`. A test
that expects one, to check that a mock is misused as it should be, wraps the code in `withKnownIssue { … }` in
Swift Testing, or `XCTExpectFailure { … }` in XCTest on Apple platforms. The expectation catches only failures
inside its own block: a failure in a task the block didn't wait for, such as a `Task.detached`, isn't caught.
Swift Testing records it at its own location, such as a `verify` call's, or, for a failure inside the mock, such as
an unstubbed call, at the test that created the mock. The issue is tied to no test: the run fails, while the test
itself passes. A mock created in that task belongs to no test, so its failures go to XCTest, and Swift Testing
doesn't see them: create mocks in the test.

A failure the mock can't go on from, such as an unstubbed call whose return type has no default value, is reported
to the test's framework and then stops the process, in XCTest and Swift Testing alike: the call has to return a value
it doesn't have. Xcode relaunches the test runner and runs the remaining tests; `swift test` ends the run, unless
it runs with `--parallel`. Register a default value for such a type, or stub the call, and the test fails without
stopping. In an `async` XCTest test, the process may stop before XCTest prints the failure: the crash's message is the
same.
