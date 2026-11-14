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
``createMock(_:configuration:)`` and ``createMock(for:configuration:)`` stub it first.

Mocks keep the isolation of the type they mock. The mock of a `@MainActor` protocol is `@MainActor`, the mock of
an `actor` protocol is an actor, and the mock of a `Sendable` type is `Sendable`, so the compiler checks how the
test shares it. A protocol that states no isolation of its own takes its parents', as Swift does: the mock of a
protocol refining a `@MainActor` protocol is `@MainActor` too. A parent declared in another module, which the
generator doesn't read, can't pass its isolation on; state it on the protocol you mock.

### Stub members

``stub(_:block:)-(M,_)`` hands its block a stubbing proxy with one member for each of the mock's. Pass a call on
that proxy to ``when(_:)``, with matchers for its arguments, and say what the call does:

```swift
let greeter = MockGreeter()
stub(greeter) { stub in
    when(stub.greet(name: "Ann")).thenReturn("Hello, Ann")
    when(stub.greet(name: any())).then { name in "Hi, \(name)" }
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
closures run on the main actor and can use its state directly.

### Calls with no stub

A call that no stub matches records a failure that lists the member's stubs and the argument each one rejected.
Then it answers, so the test can go on: a member that throws `any Error` throws ``CuckooError/unstubbedCall(method:)``,
and any other member, a `rethrows` one included, returns a default value from ``CuckooConfiguration/defaultValues`` or
``DefaultValueRegistry``. Optionals and the standard collections default to empty, numbers, strings and `Bool`
to zero, `""` and `false`. Register a value for any other type, tuples included, or a call returning it crashes
with a message naming it:

```swift
@Test(.cuckoo(defaultValues: {
    var values = DefaultValues()
    values.register(User.guest)
    return values
}()))
func showsTheGuest() { … }
```

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
your own variable don't reach it. Pass a class instance to share state with the test. Actor mocks have no default
implementation: forwarding a call's arguments to another actor would race. Stub their members instead.

The mock of a class can call the class itself. ``ClassMock/enableSuperclassSpy()``, or `withEnabledSuperclassSpy()`
when creating it, makes every unstubbed member call the superclass, so the mock acts as a spy.

Each generated mock `MockGreeter` comes with `GreeterStub`, a type with no stubbing or verification whose members
return default values and do nothing else. `MockGreeter().withEnabledDefaultImplementation(GreeterStub())` makes
every unstubbed call of a mock answer quietly.

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
doesn't, and its static calls fail as unstubbed.

### Verify calls

``verify(_:_:fileID:filePath:line:column:)->M.Verification`` checks that the mock received a call, once unless
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
call the mock received if the member had none. ``verifyNoMoreInteractions(_:fileID:filePath:line:column:)-(M...,_,_,_,_)``
fails if the mock received a call no `verify` checked.

A generic member whose type comes only from its return value needs the type spelled out:

```swift
verify(cache).value(forKey: "a").with(returnType: Int?.self)
```

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

Capture in `verify` rather than in a stub, where the captor also sees calls the stub is only tried against.

### Reset a mock

- ``reset(_:)-(HasMockManager...)`` clears a mock's stubs and recorded calls.
- ``clearStubs(_:)`` clears only the stubs.
- ``clearInvocations(_:)`` clears only the recorded calls.

``reset(_:)-f6hy`` does the same for a mock type's static members.

### Report failures elsewhere

Failures go to the framework running the test: Swift Testing records an issue, and XCTest an `XCTFail`. A
``CuckooConfiguration`` with a `failureHandler` receives them instead, for one test with
`.cuckoo(failureHandler:)` or for any scope with `CuckooConfiguration.$current.withValue(_:operation:)`.
