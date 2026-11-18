# Changelog

## Unreleased

### Added
- An unstubbed call returning a protocol that the same Cuckoofile module mocks, `any Engine` or a bare `Engine`,
  records its failure and answers with a new `EngineStub`, the generated do-nothing implementation, so the test goes
  on; it used to stop the process, as a call whose return type has no default value does. A default registered for
  `(any Engine).self`, with `DefaultValueRegistry` or `.cuckoo(defaultValues:)`, still wins, and `(any Engine)?`
  and `[any Engine]` keep `nil` and the empty array. Protocols whose stub a plain `init()` can't always create have
  no such default: a generic one or one with associated types, one with an initializer requirement or a required
  superclass, and one declared under `#if` or an attribute such as `@available`.
- An unstubbed call returning a struct or an enum that the same Cuckoofile module's sources declare records its
  failure and answers with a value the mock builds, instead of stopping the process: `Type()` for a struct with an
  initializer that takes no arguments (a declared `init()`, the only initializer whose parameters all have
  defaults, or the implicit one of a struct whose stored properties all have defaults), and an enum's first case
  without associated values. That runs the struct's initializer and its stored properties' default expressions. A
  class or an actor gets no such default: no real class or actor initializer runs unasked. A registered default
  still wins. Types the generator can't be sure of keep having none: a generic type, one under `#if` or an attribute
  such as `@MainActor` or `@available`, a struct with a conformance outside the standard library's common ones, one
  whose initializer is failable, throwing, `async`, `private` or attributed, one with an initializer declared in an
  extension, and every struct of a module with `defaultIsolation = "MainActor"`. An internal initializer counts in
  the mock of an internal type, or when `sources` names the type's module and `testableImports` lists it. See
  "Calls with no stub" in the stubbing guide.
- The members of a generated `…Stub` return those defaults too, where they used to stop the process: a stub's
  member returning a mocked protocol answers with that protocol's stub, and one returning a type of the sources
  with a value of it. `DefaultValueRegistry.defaultValue(for:generated:)` is what they call.

### Fixed
- A requirement naming its associated type through `Self`, as `func first() -> Self.Item?` or
  `Self.Item.Element`, in a parameter, a result, an initializer, a variadic parameter or a constraint, gave a mock
  that didn't compile: inside the mock, which is generic over `Item`, `Self.Item` names nothing. It's written `Item`
  there.
- A parameter whose type is a parent's associated type bound to a function type, as `Input` in
  `protocol Formatter: Transforming<(Int) -> String>`, is a non-escaping closure, which the mock recorded as it was
  and didn't compile. The mock now makes it escaping to record it, as it does any closure parameter, in methods and
  subscripts, with `sending`, and inside a closure's own parameters, whether the parent's argument writes the
  function type out or names it through a typealias, found as a parameter's is. A parenthesized closure parameter,
  `((Int) -> String)`, is a closure parameter too.
- A member with an `isolated` parameter didn't compile in a `@MainActor` protocol when it returned a non-`Sendable`
  value, or in an `Actor` protocol: its stubs ran on the protocol's actor, while the member runs on the actor its
  parameter names. Its stubs are nonisolated and shared now, so they take `Sendable` values: return a non-`Sendable`
  one from `then { … }` rather than `thenReturn`.
- The matcher of an optional parameter written with a specifier, such as `isolated (any Actor)?`,
  `sending Ticket?` or `inout Int?`, was constrained to the optional type rather than its wrapped type: a `Sendable`
  mock's stubbing proxy didn't compile, and neither did a value matcher such as `when(stub.update(1))`. It's matched as any
  optional parameter is now, so `nil` is matched with `isNil()`, as for a plain `Int?` parameter.
- A type whose parent names a module, as `protocol Error: Swift.Error` or `class Thread: Foundation.Thread`,
  crashed the generator with a stack overflow, and so did invalid source such as `class A: A` or a protocol without a
  name. A module-qualified parent is declared outside the sources, and the generator now stops at a cycle.
- Types nested in a `final` class weren't mocked, and types declared in a body, a closure, a `deinit` or a macro's
  closure, such as `#Preview { … }`, were, giving mocks of types nothing else can name.
- A mock nested in an extension didn't repeat the extension's `@available` or `where` clause, and didn't compile
  where it needed them.
- A mock of a backticked type, such as `` class `Type` ``, didn't parse: its mock, stub and proxies are now named
  without the backticks.
- An `@available` message with a comma in it, as in `message: "old, unavailable soon"`, was read as several
  arguments, so a deprecated requirement could be taken for an unavailable one and left out of the mock.
- A protocol that isn't mocked, because a requirement returns a `~Copyable` type, also left out every protocol with
  its name elsewhere, and those refining them; it's known by its qualified name now.
- A subclass's `final` or unavailable override was dropped, so the mock overrode the superclass's member and didn't
  compile. The mock now leaves it alone.
- A requirement of a parent with no global actor became isolated to a refining protocol's global actor, so the
  mock's conformance to the parent crossed into that actor. It's `nonisolated` in the mock now, as a conforming
  type's witness has to be.
- With `defaultIsolation = "MainActor"`, a class whose superclass is `nonisolated`, a protocol refining a
  `nonisolated` one, and a type nested in a `nonisolated` type took the default isolation instead of Swift's
  inferred `nonisolated`, and their mocks didn't compile.
- A protocol fixing a parent's associated type, as `where Item == String` or `Store<String, Int>`, left that name
  in the other associated types' constraints, as `Keys: Collection<Key>`, which the mock couldn't name.
- A subclass of a generic class in the sources, `class Child: Base<Int>`, got a mock that silently didn't override
  the superclass's members. The mock now lists them as not mocked, and the generator warns.
- A requirement a child protocol restates with other spellings, such as another generic parameter name, a `where`
  clause instead of an inline constraint, or `Swift.Int` for `Int`, was declared twice in the mock.
- A typealias of a closure typealias, `typealias Chained = Handler`, wasn't seen as a closure, and a generic closure
  typealias applied to itself, `Transform<Transform<Int>>`, gave the wrong parameter type; neither mock compiled.
- `Self.Type` in a requirement wasn't rewritten in the mock, which didn't compile.
- A property initialized with a capitalized function's or static method's call, as `var kind = Kind.Make()`, got
  that call's name as its type. It now gets the "add a type annotation" warning, as any type the generator can't
  infer does.
- A subscript with a `_modify` accessor was read as read-only, and an `@objc optional var` requirement's default
  implementation was read without unwrapping it; neither mock compiled.
- A member taking an `isolated` parameter and a non-escaping closure, such as
  `func run<T>(isolation: isolated (any Actor)?, _ body: () async throws -> T) async rethrows -> T`, didn't
  compile. A protocol's mock now stubs it and records a failure if it's forwarded to a default implementation; a
  class's mock keeps the real implementation, with a warning.
- A settable closure-typed property or subscript in a protocol with an associated type didn't compile in the type
  eraser, and a generic requirement taking a non-escaping closure over an associated type, as
  `func map<T>(_ transform: (Element) -> T) -> [T]`, got a cast that always failed.
- A type nested two levels deep, as `Feature.Screen.ViewModel`, got a mock that couldn't name the types of
  `Feature`. The mock and stub now declare typealiases for the ones the type uses.
- A subscript labelled `p0` lost its label, a closure key next to a generic subscript was forwarded to the generic
  one, and a class with a sync and an async overload of the same method got two identical verification members.
  `await verify(mock).value()` now verifies the async overload. In an async context a plain `verify(mock).value()`
  picks the async one too: verify the sync overload from a synchronous closure. `inOrder` can't verify the async
  one, as its block is synchronous, and stubbing either needs the stub's type spelled out, as it did before.
- A member taking an `inout sending` or `inout some P` parameter, or a closure over a parameter pack, gave a mock
  that didn't compile. Its protocol isn't mocked, and a class's mock keeps the real implementation, with a warning
  either way.
- A release build could deadlock in `reset`, `clearStubs`, `clearInvocations`, `DefaultValueRegistry.register` and
  `reset`, and when replacing a default implementation: the optimizer released the removed values inside the lock,
  where a `deinit` that uses the mock waits for it. They're released after the lock in every build now.
- `verify` of a generic member counted its calls with every return type, so
  `verify(cache).value(forKey: "a").with(returnType: Int?.self)` passed for a call returning `String?`, and
  `never()` failed. It counts only the calls with the verified return type, as a stub answers only those. A test
  from Cuckoo 2 that named a supertype or an existential there verifies no calls now: name the call's return type.
- A generated `…Stub` used as a default implementation ignored the default values of the scope its mock was created
  in, when called from a task outside it, such as a `Task.detached`. A default implementation runs with them now, as
  an unstubbed call does.
- In an XCTest test on Apple platforms, a failure the mock can't go on from, such as an unstubbed call whose return
  type has no default value, was reported twice, as an `XCTFail` and as an Objective-C exception, and the exception
  unwound past Swift's cleanup, leaving `inOrder`, `withStaticStubs`, `createMock` or a default-values scope open for
  the thread's next tests. Cuckoo raises no exception now: the failure is reported once and the process stops, as it
  does in Swift Testing. Xcode relaunches the test runner for the remaining tests.
- In an Xcode project with several test targets, each one's build warned that the others' Cuckoofile entries named
  no target. Every target of the project counts now.
- The build plugin passed a C, C++ or Objective-C target's files to the generator, which mocked a C++ class and
  broke the build. It passes Swift files only.
- A folder whose name has a pattern character, as `glob [v2]` or `Feat{A}`, made a `sources` pattern match nothing
  in it, without a warning when other files matched: the Cuckoofile's own folder and the folders a `**` walks into
  are matched as they are now. A `**` that isn't a whole folder name, as in `Sources/**.swift`, is a `*`.
- An entry named after a target whose module is named otherwise, `[modules.My-Core]` for the module `My_Core`, was
  said to name no target: the warning says to name it after the module.
- A value of the wrong type in the Cuckoofile, as `sources = "Sources/*.swift"`, was reported as a syntax error. The
  error names the key and the type it takes.
- Run by hand, an entry without `sources`, or with an empty list, generated an empty file without a word: it's a
  warning now.
- The build plugin missed the entries of a `modules` table written on one line, read a `\"` in a quoted key as
  its end, and took three quotes inside a one-line string, as `'"""'`, for the start of a multi-line one.
- A requirement naming a typealias through `Self`, as `func find(_ id: Self.ID) -> Self.ID?` with
  `typealias ID = Int` in the protocol, a parent or an extension, gave a mock that didn't compile, as `Self.Item`
  did for an associated type. Any `Self.Name` but `Self`'s metatype is written `Name` in the mock now, in the
  typealiases it repeats too, and a function typealias named through `Self` is the closure parameter it stands for.
- A settable property or subscript whose type is a typealias of a function type, as `var handler: Handler { get set }`,
  or an implicitly unwrapped optional, as `((Value) -> Void)!` or `Value!`, didn't compile in the type eraser of a
  protocol with an associated type.
- Stubbing a method with a sync and an async overload of the same signature was ambiguous: `when(stub.value())`
  needed the stub's type spelled out. The async overload's stubbing member is `async` now, as its verification
  member is, so a call picks one as Swift picks a call's overload: `when(stub.value())` in the `stub` block stubs
  the sync one, and `when(await mock.cuckooStubbingProxy().value())` the async one. `inOrder` still can't verify
  the async one, as its block is synchronous.
- With `defaultIsolation = "MainActor"`, a `nonisolated` class's member that implements a requirement of a
  global-actor protocol, as `show()` of a default-isolated `Showing` in `class Screen: Plain, Showing` with a
  `nonisolated` superclass, was mocked as nonisolated. Swift gives it the requirement's actor, and so does the mock,
  which didn't compile before.
- A settable `@objc optional` property, or an `@objc optional` subscript, gave a mock that didn't compile: read
  through its protocol, an optional requirement is an immutable optional value. The getter of a subscript unwraps
  it, as a property's does, and a setter forwarded to a default implementation records a failure saying to stub it.

### Changed
- The argument a generated mock passes its manager for an unstubbed call's default is `unstubbedDefault`, renamed
  from `unstubbedTuple`: it carries a stub or a value as well as a tuple's default. Regenerate the mocks with this
  version's generator, as for any release.
- The stand-in a `verify` or an `ArgumentCaptor` gets for a closure parameter that isn't `@escaping` says, when
  called, that such a closure can't be called after its call, and to call it from a `then` closure. The
  documentation says so too.
- Documentation: an optional collection parameter is matched with `equal(to:)`, not a plain value; a literal such
  as `1.5` doesn't match a `Float` parameter; only a flat tuple has a default value; and `reset`, `clearStubs` and
  `clearInvocations` run from any isolation.

### Removed
- The build warning that the test target's entry without `sources` mocks only its own package's targets: every
  test that depended on another package's library got it. The documentation says how to mock those.

## 3.0.0-beta.5

Fixes and removals from two independent reviews of beta.4: failure messages name calls as a test writes them,
`inOrder` counts calls as Mockito does, `eventually` and the reset functions no longer lose failures or deadlock, a
mock keeps its test's default values from any task, and members a mock can't return are skipped with a warning
instead of breaking the build. The Cuckoo 2 shims, the `any*`-typed matchers and the Cuckoofile options `glob`,
`omitHeaders` and `enableInheritance` are gone. Breaking changes are listed first; the
[migration guide](Source/Cuckoo.docc/MigratingFromCuckoo2.md) covers each.

To try it:

```swift
.package(url: "https://github.com/nmcc24/Cuckoo.git", exact: "3.0.0-beta.5"),
```

### Breaking changes
- The names a mock declares for Cuckoo carry its prefix, so they no longer hide yours: `Mock`'s `MocksType`, `Stubbing`
  and `Verification`, and `StaticMock`'s `StaticStubbing` and `StaticVerification` are `CuckooMocksType`,
  `CuckooStubbing`, `CuckooVerification`, `CuckooStaticStubbing` and `CuckooStaticVerification`; `cuckoo_manager`,
  `cuckoo_staticManager`, `cuckoo_hasSuperclass` and `cuckoo_globalActor` are `cuckooManager`, `cuckooStaticManager`,
  `cuckooHasSuperclass` and `cuckooGlobalActor`; `getStubbingProxy()` and `getVerificationProxy(_:sourceLocation:)` are
  `cuckooStubbingProxy()` and `cuckooVerificationProxy(_:sourceLocation:)`. Generated mocks spell them; code that names
  them changes, and the migration guide lists each. Names starting with `Cuckoo`, `cuckoo` or `__` are reserved for
  mocks.
- `verify`'s result, `__DoNotUse`, is `VerifiedCall`, documented: its `with(returnType:)` names a generic member's
  return type. Code rarely names the type itself. An optional property's verified getter is
  `VerifiedCall<Void, T?>`, typed with the property's value, not `VerifiedCall<Void, T>`.
- `MockManager.enableDefaultStubImplementation()` is `enableDefaultImplementation()`, the name the rest of the API
  uses for what an unstubbed call forwards to. Generated mocks call it; code that calls it directly changes.
- `Mocked` and `createMock(for:configuration:)` are removed: call `createMock(MockPerson.self) { … }` with the mock's
  type instead, which is all they saved.
- Inside `inOrder`, a call matcher counts as it does outside it. A `verify` took the fewest calls its matcher
  accepted, so `times(1)` passed on two calls in a row and `atLeast(2)` took two of three calls, leaving the third
  for `strict` to reject. It now takes all its matching calls after the previous `verify` if its matcher accepts
  them all, else the first run of matching calls no other call to the block's verified mocks interrupts, as
  Mockito does. The block's `verify` calls are checked when it ends, and so is a `verifyNoMoreInteractions` inside
  it, which sees the calls the `verify` calls before it took. A `verify` in a `Task` the block starts that runs after
  it ends records a failure; a `Task.detached` or a dispatch queue isn't part of the block. A captor in the block
  fills when it ends.
- `MockManager.preconfiguredManager`, which only generated mocks used, is now `preconfiguredManager(for:)`.
- `verify` on the mock of a `@MainActor` type, or of another global actor's, needs that actor: the verification
  proxy takes the mock's isolation. A test off the actor could read a recorded argument while the actor still
  changed it, which Swift 6's checking didn't catch. `verifyNoMoreInteractions` records a failure off a mock's
  global actor instead of reading its calls. It takes a new last parameter, `isolation`, which defaults to the
  caller's, and mocks conform to the new `HasGlobalActor`, which names their actor.
- A `nonisolated` member of a `@MainActor` or other global-actor type gets `Sendable` stubs, since it can be called
  from any task at once: `thenReturn` and `equal(to:)` take only `Sendable` values there. For a value that isn't,
  return a new one from `then { Token() }`.
- A throwing property's stubbing handles, `ProtocolToBeStubbedThrowingProperty` and
  `ClassToBeStubbedThrowingProperty`, take the getter's error type: `<MOCK, T, ERROR, GET, SHARING>`. Generated
  mocks spell it; only code that names these types itself changes.

### Changed
- The Cuckoofile option `enableInheritance` is removed: set to `false`, it gave a mock of `protocol B: A` that didn't
  conform to `A`. Mocks always repeat inherited members, and a Cuckoofile that still sets it gets a warning.
- The Cuckoofile option `glob` is removed: `sources` are always globs, its default, and `?` matches a file name's
  glob character. A Cuckoofile that still sets it gets a warning.
- The Cuckoofile option `omitHeaders` is removed: each source file's mocks start with the comment that names the
  file, as by default. A Cuckoofile that still sets it gets a warning.
- `clearStubs`, `clearInvocations` and `verifyNoMoreInteractions` take mocks of different types:
  `verifyNoMoreInteractions(database, cache)` compiles.
- Failure messages name a call as a test writes it: `No stub for count(characters:) with ("b")`, not
  `No stub for method \`count(characters p0: String) -> Int\` using parameters ("b")`, and `No stub for the getter
  of name`. The lists of a mock's calls show a property's as `name` and `name = 1`, not `name#get` and
  `name#set(1)`. A stub that has no answer yet says to give it one, such as `thenReturn(_:)`.
- `verify`'s result is `Sendable`.
- A Cuckoofile module can list the global actors its types use from other modules, in `globalActors`.
- The comment above each file's mocks names the mocked file by its path from the Cuckoofile, not from wherever
  the generator ran, so a build plugin's mocks no longer show `../../../..` paths. `--help` names the command
  `CuckooGenerator`, and a build log shows "Generate Cuckoo mocks for …" instead of "Run Cuckoonator for …".
- A class mock no longer repeats the class's typealiases: it inherits them, as the class's stub already did. The
  copies read their names in the mock's scope, so one naming a nested type didn't compile.

### Added
- `clearStubs`, `clearInvocations` and `verifyNoMoreInteractions` take mock types, as `reset` does, for their static
  members: `verifyNoMoreInteractions(MockClock.self, MockStore.self)`.
- Operator requirements are mocked. A protocol with `static func + (lhs: Self, rhs: Self) -> Self` had a mock that
  didn't conform. The proxies name an operator `operator` and a word for each character, such as
  `stub.operatorPlus(any(), any())` and `stub.prefixOperatorMinus(any())`.
- `DefaultValueRegistry.register(for:factory:)` and `DefaultValues.register(for:factory:)` give a type that isn't
  `Sendable`, such as a class, or a tuple a default value for unstubbed calls; the factory makes a new value for
  each call.

### Removed
- `MockManager.crashOnSelfDefaultImplementationCall(_:)`: a member taking or returning `Self` now records a failure
  through the mock's manager instead of crashing. Generated mocks call it; code that calls it directly changes.
- `HasMockManager` and `HasSuperclass`: their requirements, `cuckooManager` and `cuckooHasSuperclass`, are `Mock`'s
  own. `reset` takes `any Mock`, as `clearStubs` does. `MockManager.callOrCrash`, which nothing called, is removed
  too.
- The `equal(to:)` overloads for arrays, sets and dictionaries: the general `equal(to:)` matches them, since they're
  `Equatable` when their elements are. Calls don't change.
- The deprecated Cuckoo 2 names: `hasLength(inRange:)` and `hasLength(inRange:inclusive:)` (write `hasLength(in:)`
  with the range you mean: `inRange: 1..<3` matched 3, `in: 1..<3` doesn't), `register(value:forType:)` (write
  `register(_:for:)`), `equal(to:)` on a class that isn't `Equatable` (write `sameInstance(as:)`), and the
  `Matchable` and `OptionalMatchable` aliases (pass `equal(to:)`, which takes any `Equatable` value).
- `DefaultValueRegistry.defaultValue(for:)`'s overloads for `Set`, `Array`, `Dictionary` and `Optional`. Calls
  compile unchanged and get the same value from the generic one.
- `MockBuilder.enableDefaultStubImplementation()`. A mock that `createMock` configured with it forwarded unstubbed
  calls to a default implementation it didn't have, so the first unstubbed call crashed the test process. Call
  `enableDefaultImplementation(_:)` on the mock once it exists.
- `CuckooConfiguration.failureHandler`, `CuckooConfiguration.FailureHandler` and the `.cuckoo(failureHandler:)`
  trait argument. Failures go to the framework running the test, which has its own way to expect one:
  `withKnownIssue` in Swift Testing and `XCTExpectFailure` in XCTest on Apple platforms. The handler also couldn't
  give an unstubbed call a location in the test, so it pointed into Cuckoo's own source.
- `anyInt()`, `anyString()`, `anyClosure()`, `anyThrowingClosure()`, their async variants and
  `anyOptionalThrowingClosure()`, about 110 functions. `any()` takes its type from the parameter and covers them.
  On an optional parameter they didn't match `nil`, so a test that relies on that writes `notNil()`.
- The `CuckooGenerator` executable product. The plugin depends on the generator's target, and a release's manifest
  already left the product out. `swift run CuckooGenerator` from a clone still runs the generator.

### Fixed
- An unstubbed call whose return type has no default value reported its failure twice, once as a failure and once
  in the crash. It now crashes with one message, which lists the member's stubs as the failure did.
- A mock that a task started in `createMock`'s closure created after `createMock` returned shared the new mock's
  manager, stubs and calls. Only mocks created while the closure runs share it now.
- Replacing a default implementation, or a value in `DefaultValueRegistry` (by `register` or `reset`), released the
  old one while holding the lock, so a `deinit` that read it back deadlocked, and for the registry every later
  unstubbed call hung too. The old value is now released after the lock.
- A return or property type naming a closure with a `borrowing`, `consuming`, `isolated`, `sending`, `__owned` or
  `__shared` parameter made the generated `Stub` class fail the whole module.
- The type eraser of a protocol with associated types didn't compile for async members isolated otherwise than the
  protocol (`@MainActor`, `nonisolated(nonsending)`, `@concurrent`), for isolated, `Self` or typed-throws
  subscripts, or for members with `~Copyable` or `isolated` parameters: they record a failure saying to stub them.
  `nonisolated(nonsending)` and `@concurrent` members of a `@MainActor` type are stubbed as nonisolated, which they
  are, and an `inout` `~Copyable` argument compiles.
- A member returning a `~Copyable` or `~Escapable` value gave a mock that didn't compile. A class's mock leaves it to
  the real implementation, a protocol with one isn't mocked, and either gets a warning.
- A parent protocol's generic arguments with a closure type, `Parent<(Int) -> String, Int>`, split at the wrong
  comma, and the mock failed to generate.
- A member taking or returning `Self` crashed when forwarded to a default implementation; it records a failure and
  returns a default value, as the type eraser's members do.
- `consuming sending` parameters, raw identifiers in a protocol with associated types, `throws(Never)` (which crashed
  Swift 6.3) and a class property with only a `_read` accessor gave mocks that didn't compile.
- An unstubbed member returning a tuple crashed unless the tuple type had a registered default: the manager's
  generic return type can't name its elements. Mocks now pass the tuple's element types, so it returns each
  element's default. A tuple behind a `typealias` still needs a registered default. The generated `Stub` classes
  crashed on a labeled tuple, such as `(count: Int, name: String?)`, and now default it the same way.
- An unstubbed call from a `Task.detached` or a dispatch queue ignored the `.cuckoo(defaultValues:)` of the test
  that created the mock. A mock now keeps the default values of the scope it was created in, for the types the
  call's own scope doesn't register.
- A failure from a task that `eventually`'s block started, recorded after the block returned, was lost. It's
  now reported to the test.
- A `deinit` that called a mock, of a value a stub or a recorded call held, hung `reset`, `clearStubs` or
  `clearInvocations`, which released the value under the mock's lock. They now release it after.
- When the task waiting in `eventually` is cancelled, its failures say so, rather than that the timeout passed.
- A failure that `eventually` reported after its timeout lost the test that created the mock, so from a task outside
  the test, such as a `Task.detached`, it went to XCTest, which ignores it under Swift Testing.
- A call to a generic member that had stubs only for other type arguments said the mock had no stub for it. The
  failure now lists those stubs' types next to the call's, and names a generic member without its generic
  parameters, as `parse(_:)`.
- A `String` argument that started with "(" and held a comma, such as `"(a, b)"`, was shown without its quotes, as
  if it were several arguments. One argument is now always quoted, and the "No stub" message quotes it too.
- `createMock` handed its manager to every mock created in its closure, so a mock passed to the new one shared its
  stubs and calls. Only the requested mock type takes it now.
- An `ArgumentCaptor` captured every argument its matcher saw: from calls another matcher of the same `verify`
  rejected, from a `verify` that failed, and, in a stub, from calls an older stub answered. It now captures only
  from the calls a passing `verify` or the answering stub takes.
- A failure from a task outside a Swift Testing test, such as an unstubbed call in a `Task.detached`, went to
  XCTest, which ignores it there, so the test passed. A mock created in a Swift Testing test now reports it to
  Swift Testing.

Mocks that didn't compile, or that differed from the mocked declaration:
- A parameter written `sending @escaping` or `@isolated(any)`, a typed-throws getter (`get throws(E)`), typed throws
  through a non-escaping closure, a closure parameter written through a typealias, `consuming` and `borrowing`
  parameters, and a `-> ()` result.
- A typed-throws getter's `thenThrow` stub was never found: the getter looked its stub up with its own error type.
- A class mock dropped the default argument values of its methods and subscripts, so a call through the mock's type had
  to pass every argument. A default that names a `private` or `fileprivate` declaration, which the mock can't see, is
  still left out, as is one using a member of a `private extension`, a type nested in one, or a call of a type whose
  init is `private` or `fileprivate`, written `Token(…)`, `Box<Int>(…)`, `Token.init(…)` or `.init(…)` (one whose type
  isn't known, inside an array or an argument, counts whenever the module has such an init). A default that only names
  such a type, as in `Config.shared`, stays.
- A class member whose type is opaque (`some P`) can't be overridden; it's now left out with a comment in the mock,
  instead of making the mock fail to compile. `some` nested in a protocol requirement's parameter is handled.
- A non-escaping closure parameter written with `sending`, `borrowing` or `inout` made the generator fail for the
  whole module. Such methods and requirements are now mocked, written directly or through a typealias, a generic
  one (`sending Handler<Int>`) included.
- A closure typealias's function type was written into the mock with the names of the type that declared it, such
  as `(Receipt) -> Void` for `Uploader.Receipt`. It's now qualified from the scope the typealias was found in, a
  superclass's included, generic arguments too.
- Keyword and backticked argument labels, a label named like the mock's own parameter names (`p0`), and generic
  parameters named like the proxies' matcher generics (`M1`).
- The mock of a protocol with associated types warned that the protocol's deprecated requirements were deprecated:
  its type eraser forwards to them. With Swift 6.4 the eraser says so with `@diagnose`, and the mock has no warning;
  Swift 6.2 and 6.3 have no way to, so the warning stays there.
- The type eraser of a protocol with associated types forwards async and throwing getters, and a member it can't forward
  (an `inout` or `sending` argument, `Self`, a member isolated otherwise than the protocol, a `where` clause naming an
  associated type) records a failure saying to stub it, for the test that created the mock, and returns the default
  value an unstubbed call would, even when the member throws. Such a protocol's mock didn't compile. A `borrowing` or
  `consuming` argument of a non-`Sendable` type is copied once in the mock, which also didn't compile, and a backticked
  method name no longer stops generation.
- Protocols with associated types: an actor protocol's mock named a type eraser that actor mocks don't declare, a
  static method returning nothing didn't compile in the type eraser, and a generic subscript naming an associated
  type couldn't be forwarded to the default implementation; its setter now keeps a value-type default
  implementation's change. A generic member whose `where` clause names an associated type, as in
  `where C.Element == Key`, can't be forwarded at all: its mock compiles, and calling it on a default
  implementation stops with a message saying to stub it.
- A class's `where` clause wasn't repeated on its mock, and the mock and stub of an `@unchecked Sendable` class, or
  of a protocol bound to one, didn't restate it, which Swift warns about; an extension's `@unchecked Sendable`
  counts too. A protocol bound to a generic class, `protocol P: Repository<Int>`, got a mock that didn't subclass it;
  its arguments are qualified from the protocol that wrote them, so a protocol inheriting it elsewhere gets the same.
- A public class with internal members that use internal types got a public mock whose overrides made those
  members public, which doesn't compile next to the class. Its mock is now internal, and says why.
- A `nonisolated` member of a `@MainActor` or global-actor protocol got non-`Sendable` stubs, so it couldn't be
  stubbed or called from another isolation.
- `@_Concurrency.MainActor` wasn't recognised, and a type nested in an actor, or in an extension of one, took the
  module's default isolation.
- A protocol whose parent was reached through an enclosing scope, a typealias, a composition typealias
  (`P = A & B`) or an extension written with the module's name lost that parent's requirements. A parent that only
  a protocol nested in an unrelated scope is named like, such as Swift's `Error` next to a `Net.Error`, took that
  protocol's requirements: it's now a parent from outside the sources, as it is to Swift.
- An unannotated property's type is inferred from array and dictionary literals of one kind and
  `Array(repeating:count:)`, but no longer from a failable initializer such as `URL(string:)` or `Int("3")`, or a
  generic type without its arguments, which gave a mock with the wrong type.

- A `**` in `sources` walked into hidden directories, so `Sources/**/*.swift` next to a `.build` folder mocked the
  dependencies' checked-out sources too. It skips hidden directories now, as a shell's globstar does.

- A `package` protocol or class got an internal mock, and a public mock's stubbing and verification proxies were
  internal, so neither could be used from another module without `@testable`, which only debug builds allow. A
  `package` type's mock is now `package`, and a public or package mock's proxies and protocol initializer have the
  mock's access (an `@_spi` member's proxies stay internal). A public or package protocol's stub gets that
  initializer too. A class whose only initializer is its implicit, internal `init()` can't be created from another
  module, and neither can its mock: give the class a `public init()`.

- An `associatedtype` declared under `#if` was missed, so the mock didn't compile in the build that declares it.
  The mock now takes it as a generic parameter, constrained only in that build, for any combination of the
  conditions it's declared under. One declared in both an `#if` and its `#else` is in every build, with each
  clause's constraints.

- A property named `callMatcher` or `sourceLocation` clashed with the verification proxy's own, and a backticked
  property such as `` `default` `` in a protocol with an associated type stopped generation for the whole module.
  A generic parameter, associated type, nested type or typealias named like one of the mock's own (`Stubbing`,
  `Verification`, `MocksType`, `DefaultImplCaller`, `M1`, a protocol property `reference`), declared, inherited or
  used, gave a mock that couldn't compile. The mock's own names now carry Cuckoo's prefix, so these are mocked.

- Two sources declaring the same type, such as `A/User.swift` and `B/User.swift`, gave two `MockUser` and only an
  info line. It's now a warning that names both files. A protocol bound to a class (`protocol P: Base`) is found by
  scope, so a same-named protocol elsewhere no longer stands in for it.

- `protocol P: Identifiable where ID == String` got a mock with a `where` clause on a non-generic class, which
  doesn't compile. A same-type requirement on an outside parent's associated type becomes a typealias in the mock.

Build plugin:
- In a package, a target whose Cuckoofile entries matched none of its modules got no mocks without a word; it's
  now a build warning naming the entries. The entry named after the target itself is generated for any target, not
  only test targets, as in an Xcode project.
- A release still declared the package's test targets and its test-only plugin, so Xcode compiled that plugin in
  every project using Cuckoo. A release declares only the runtime, the plugin and the prebuilt generator.
- In an Xcode project, Getting Started's Cuckoofile generated no mocks, without a word: Xcode doesn't tell the
  plugin which of the project's own targets a test target depends on. An Xcode project's entry is named after the
  test target and lists its `sources`, as in Cuckoo 2, and a test target with no entry of its own, or one whose entry
  lists no `sources`, now fails with a message saying what to write. Getting Started and the Cuckoofile article say so.
- A Cuckoofile key in quotes, such as `[modules."My App"]`, lost its spaces and dots, so it named no target, and a
  multi-line string closed by `\\"""` or `""""` hid the entries after it.
- A test target's dependency on an executable target got no mocks.
- An entry named after the test target, without `sources`, also mocked the package products of other packages the
  test target depends on. It mocks the package's own targets; an entry lists another package's files to mock them.
  A build warning names the modules it leaves out. In an Xcode project, such an entry fails with the message saying
  to list `sources`, even when the test target depends on package products.
- A Cuckoofile entry for a module that the test target reaches only through another module generated nothing,
  without a warning: the unused-entry warning counted every target's name and dependencies. It now counts the
  targets that depend on Cuckoo and their direct dependencies, and says to make the module a direct dependency.
- A missing Cuckoofile gave an unclear failure; the plugin now says where it looked and what to add.
- The generator logged the Cuckoofile's path with a double slash.

### Warnings
- A Cuckoofile key Cuckoo doesn't read, such as `testableImport`, `[module.App]` or `options.protocolOnly`, was
  ignored without a word. It's now a warning naming the keys Cuckoo knows there, and a Cuckoofile with no modules
  says so. The plugins' runs for one module warn only about that module's keys and the file's own. An entry no
  target can use, such as a misspelled `[modules.Netwrk]`, is a build warning naming it: the plugin checks the
  entries against every target of the package or Xcode project and the modules they depend on.
- A type marked with an attribute that isn't a known global actor gets a comment in its mock, and a warning when
  the name ends in `Actor`. A parent protocol declared outside the sources gets a comment in the mock.


## 3.0.0-beta.4

Fixes from a full review of beta.3: mocks of protocols that inherit an actor's isolation, variadic parameters and
associated-type `where` clauses now compile, and a release no longer declares swift-syntax, so projects whose
macros pin an older one can resolve Cuckoo. The [migration guide](Source/Cuckoo.docc/MigratingFromCuckoo2.md)
covers moving from Cuckoo 2.

To try it:

```swift
.package(url: "https://github.com/nmcc24/Cuckoo.git", exact: "3.0.0-beta.4"),
```

### Changed
- `SourceLocation` loses `file`: it's `(fileID:filePath:line:column:)`, with `filePath` a `StaticString`, and
  `verify`, `verifyNoMoreInteractions`, `inOrder` and the `MockManager` methods that took a `file:` argument no longer
  do. A failure handler that read `sourceLocation.file` reads `filePath` instead.
- `hasLength(in:)` matches the counts its range contains: `1..<3` matches 1 or 2. `hasLength(inRange:)` is
  deprecated and, with a half-open range, includes its upper bound again, as in Cuckoo 2: beta.2 had changed what
  `inRange: 1..<3` matched without any warning, so code moved from Cuckoo 2 kept compiling but stopped matching 3.

### Fixed
- A release still declared the generator's dependencies, so its swift-syntax range, `602.0.0..<605.0.0`, kept a
  package whose macro packages pin an older swift-syntax from resolving Cuckoo, which the prebuilt generator was
  meant to allow. A release now declares only the runtime, the plugin and the bundled generator. Its manifest no
  longer has the `CuckooGenerator` product: build it from a branch to run the generator yourself.
- A protocol that refines a `@MainActor`, global-actor, `Actor` or `Sendable` protocol, and states no isolation
  itself, got a `nonisolated` mock that didn't compile: the generator took the parent's members but not its
  isolation. The mock now takes the parent's isolation, actor-ness and `Sendable`-ness, through any number of
  levels, as Swift does for the protocol.
- Variadic parameters, `func log(_ messages: String...)`, lost their `...` in the mock, which then didn't conform.
  The mock keeps them variadic and records the argument as an array, which matchers, captors and `then` closures
  receive. Such a member can't call its real or default implementation, which Swift can't pass an array to.
- A `where` clause on an associated type, as in `associatedtype Element where Element: Equatable`, was dropped, so
  the mock didn't conform. Its requirements now constrain the mock as the protocol's own `where` clause does, and a
  requirement on a nested type, such as `Items.Element == Int`, written on either, goes in the mock's and stub's
  `where` clause instead of being dropped or written as an invalid typealias.
- An unstubbed `rethrows` member called with a closure that doesn't throw crashed the test process: it threw
  `CuckooError.unstubbedCall` into a call that had no `try`. It now records the failure and returns a
  default value, as any non-throwing member does.
- XCTest failures from `verify`, `verifyNoMoreInteractions` and `inOrder` point at the failing line. They carried a
  module-relative path, the one `#file` gives in a Swift 6 module, so Xcode couldn't place them.

## 3.0.0-beta.3

Matchers that `Sendable` mocks can keep, so their stubs are safe to call from any task, and the deprecation of
your own `Matchable` conformances in favour of `equal(to:)`. The
[migration guide](Source/Cuckoo.docc/MigratingFromCuckoo2.md) covers moving from Cuckoo 2.

To try it:

```swift
.package(url: "https://github.com/nmcc24/Cuckoo.git", exact: "3.0.0-beta.3"),
```

### Changed
- `SendableMatcher` is a `ParameterMatcher` whose closure is `@Sendable`. The mock of a `Sendable` type or an actor
  can be called from any task, so its stubs only take `SendableMatcher`s and the built-in values. A matcher that
  keeps a non-`Sendable` value, or a `ParameterMatcher`, is a compile error there. Other mocks, and `verify`, take
  either kind.
- Each matcher function returns a `SendableMatcher` when the values it keeps are `Sendable`, and a
  `ParameterMatcher` otherwise. The matchers that keep nothing (`any()`, `anyInt()`, `anyString()`, `isNil()`,
  `notNil()`, `anyClosure()`, `hasLength`) always return a `SendableMatcher`, and so does `sameInstance(as:)`, for
  any class. `or`, `and` and `not` keep the kind, and an `ArgumentCaptor` of `Sendable` values captures with one.
- Conforming your own types to `Matchable` or `OptionalMatchable` is deprecated: pass `equal(to:)`, which takes any
  `Equatable` value. The protocols are now `_Matchable` and `_OptionalMatchable`, the names the generated mocks
  use, and Cuckoo 4 will hide them from your code.
- A property stub's `set` takes `Sendable` matchers for a `Sendable` mock, like its other stubs.

## 3.0.0-beta.2

The rest of the code audit's fixes: runtime and generator bugs, tighter tests, and a few API changes. The
[migration guide](Source/Cuckoo.docc/MigratingFromCuckoo2.md) covers moving from Cuckoo 2.

To try it:

```swift
.package(url: "https://github.com/nmcc24/Cuckoo.git", exact: "3.0.0-beta.2"),
```

### Changed
- `equal(to:)` on an `Equatable` class compares with `==`. The identity overloads of `equal(to:)` for classes are
  deprecated: use `sameInstance(as:)` to match the same instance.
- `DefaultValueRegistry.register(_:for:)` registers a default value, matching `DefaultValues.register(_:for:)`.
  `register(value:forType:)` is deprecated.
- `ClassConcreteStub` and `MockBuilder` are `final`.

### Fixed
- `containsAllOf` with `Hashable` elements matches a sequence that holds an element more often than it was passed,
  as the `Equatable` overload does. `containsAllValuesOf` is fixed with it.
- `hasLength(inRange:)` takes any range and matches the counts it contains: `1..<3` no longer matches 3.
  `hasLength(inRange:inclusive:)` is deprecated.
- A failed `verify` leaves its calls unverified, so `verifyNoMoreInteractions` still reports them.
- Calling `enableDefaultImplementation(_:)` again after the mock's first call replaces the default implementation
  instead of crashing, and calling `enableSuperclassSpy()` again is allowed too.
- `enableSuperclassSpy()` on a protocol mock records a failure instead of making every unstubbed call crash.
- The zero-argument optional `@Sendable` `anyClosure()` matchers no longer match `nil`.
- A generated `Stub` returning a tuple gives optional and collection elements their empty values, and tuples of
  any size work. A mock's unstubbed call still needs a stub or a registered value for a tuple.
- Under Swift Testing, an unstubbed call's failure points at the test instead of into Cuckoo's sources.
- Failure messages say "1 time", and "after the mock's first call" where they said "after stubbing".
- A directory `output` keeps same-named sources apart (`A_User.swift` and `B_User.swift`) instead of writing one
  over the other.
- An unannotated property's type is read from its initializer's syntax: `Style.default`, `UUID().uuidString` and
  `0xbeef` no longer get a wrong type, and properties whose type isn't named get the "add a type annotation"
  warning.
- Value generics (`<let N: Int>`) keep their `let`, types nested in an actor are mocked inside it, and a type in a
  `public extension` is public in its mock.
- A `sources` pattern that matches no file is a warning.
- With the build plugin, an entry that sets `sources` is regenerated when any of the project's source files changes.
- A release dry run works when the version is already tagged.

## 3.0.0-beta.1

Cuckoo 3 is built for Swift 6: mocks keep the isolation and `Sendable`-ness of the types they mock, and the
generator runs as a prebuilt binary from one build plugin. This beta adds fixes from a code audit to
3.0.0-alpha.1. Existing suites need the changes in the
[migration guide](Source/Cuckoo.docc/MigratingFromCuckoo2.md).

To try it:

```swift
.package(url: "https://github.com/nmcc24/Cuckoo.git", exact: "3.0.0-beta.1"),
```

### Requirements
- Swift 6.2 or later (Xcode 26 or later). The Swift 6 language mode is recommended; the mocks also compile in
  the Swift 5 mode, which CI doesn't test.
- iOS 17, macOS 14, tvOS 17 or watchOS 10, or Linux.
- SwiftPM only: the podspec and the `run` script are removed.

### Swift 6 concurrency
- Mocks of `@MainActor` and global-actor types are isolated to that actor, mocks of `actor` protocols are actors,
  and a mock is `Sendable` exactly when the mocked type is. Member-level isolation, `nonisolated`, `sending`,
  `nonisolated(nonsending)` and `@concurrent` carry over to the mock.
- A Cuckoofile `defaultIsolation = "MainActor"` option for modules built with MainActor default isolation.
- The runtime is data-race safe: per-test state is task-local, and a `.cuckoo()` Swift Testing trait sets a test's
  configuration, failure handler and default values.

### Generator and plugin
- One build plugin, `CuckooPlugin`, generating one file per module the test target depends on, so an edit
  regenerates and recompiles only that module's mocks. `CuckooPluginModular` is renamed; `CuckooPluginSingleFile`
  is removed.
- Releases run a prebuilt generator (macOS, Linux x86_64 and arm64), so builds don't compile swift-syntax. From a
  branch or a commit, the plugin builds it from source (swift-syntax `602.0.0..<605.0.0`).
- The plugin passes the target's files to the generator: a Cuckoofile module without `sources` mocks them.
- Code is generated with swift-syntax instead of Stencil, and is formatted. Generating the runtime's own test mocks
  went from 23 s to under a second.
- Mocks are written only when they change, so unchanged mocks aren't recompiled.
- New Cuckoofile options: `regex` arrays, `sources` by Swift module, `mockPrefix` and `mockSuffix`; testable imports get the `@_spi` groups the mocked declarations use.
- The generator reports its release with `--version` (Brightify/Cuckoo#601).

### Mocking more
- Subscripts, static and class members, opaque (`some`) parameters, parameter packs, `~Copyable` arguments,
  `inout` stubbing that reaches the caller, `Self`, generic initializers, class-constrained protocols and
  parent associated types.
- Verification: `inOrder` (relaxed and strict), `eventually` for calls made from another task, a `Sendable`
  `ArgumentCaptor`, and failure messages that list the calls a member received and the argument that didn't match.

### Breaking changes
- The `xcodeproj` Cuckoofile table, `MockManager.fail`, `enableDefaultImplementation(mutating:)` and the OCMock
  bridge (`objcStub`, `objcVerify`) are removed.
- A call with no stub records a failure and returns a default value or throws `CuckooError.unstubbedCall`, instead
  of crashing the test process. Failures go only to the framework running the test.
- Mocks and their stub classes are `final`; `DefaultValueRegistry` takes `Sendable` values.

### Documentation
- A DocC catalog with the API reference, getting started, the Cuckoofile, stubbing and verification, matching, a
  cookbook and the migration guide.

### Fixed since 3.0.0-alpha.1
- The generator exits with an error when a mock can't be generated or written, or a source file can't be read,
  instead of reporting success. A relative `--configuration` path resolves against the project directory, and a
  missing configuration is an error.
- Typed throws keep any error type, such as `throws(Network.Failure)` or `throws(Wrapped<Int>)`, also in closure
  types, and variadic closure parameters keep their `...`. On Apple platforms, a closure parameter with typed throws
  can only be mocked from macOS 15, iOS 18, tvOS 18 or watchOS 11, which the requirement's `@available` must say:
  the mock keeps the closure's type at runtime, and older runtimes don't support typed-throws function types.
- A `sources` glob with a wildcard before `**`, such as `Modules/*/Sources/**/*.swift`, finds files in every
  matching directory.
- Xcode no longer lists Cuckoo's own `CuckooTests` scheme in projects that depend on it.

## 3.0.0-alpha.1

The first pre-release, for trying the package integration. Everything in it is described under 3.0.0-beta.1.

## 2.4.0 and earlier

- Revert exact versions in CuckooGenerator dependencies.
- Expose CuckooGenerator as executable product
- Ignore LLM files.

- Add CuckooPluginPerModule for per-module mock generation
- Address compilation warnings

- Set exact versions for dependencies to prevent future compile errors.

- Fix protocol DefaultImpl with associated types + generic functions
- fix(podspec): remove sub.source_files = [] which caused OCMock subspec to fetch no source files

- Update README stub instructions.
- Fix typed throws

- Update Cocoapods and change Ruby version.
- Update SwiftSyntax.
- Update Xcodeproj to 9.0.0
- Update contribution instructions.

- Integrate Mise.
- Fix typed-throws compilation issue with Swift 6.2
- Add support for typed-throws methods
- Allow passing an array of values to stub

- Fix macOS support post swift-format dependency range increase
- Remove SwiftFormat dependency for now.

- Loosen dependency requirements to make updating cuckoo versions easier

- Fix Path-related warnings from CuckooPluginFile
- Run GHA for pull requests.
- Fix swiftlang dependencies

- Fix crash when stubbing function that takes Sendable closure
- Make `make` more reliable.
- Fix errors when using Swift 6 strict concurrency checking

- Add back Generator.xcodeproj for local building.

- Downgrade SwiftPM version.

- Temporarily omit OCMock from SPM.

- Fix podspec.
- Improve code readability.
- Add GitHub test action.
- docs: update README.md for contribute section
- Add public imports to configuration
- Update Tuist.
- Automatically prepend changelog.
- Remove Carthage support.
- Simplify project and add watchOS support.
- Fixed typeErasure template when method.isThrowing
- Fix automatic version file generation during release.
- Update Version.swift
- Fix OCMock integration not working properly.

## 1.4.1
- Sidestep `SourceKit`'s off-by-one bug when parsing generic parameter inheritance.
- Fix incorrect `where` clause parsing.

## 1.4.0
- Add tvOS targets and schemes.
- Integrate `tuist`, fixing Carthage issues.
- Fix type equality check to rule out whitespace inconsistencies.

## 1.3.2
- Fix `image not found` error for iOS 13 and beyond.

## 1.3.1
- **Swift Package Manager support**
- Added tvOS target (thanks @rodrigoff).
- Fixed accessibility to match enclosing container.
- Restructured README.

## 1.3.0
- Fix closure generation where explicit return type is required in `withoutActuallyEscaping` since swift 5.1 (XCode 11)
- Switch swift_version to 5.0 for Cocoapods

## 1.2.0
#### Features
- Objective-C mocking! Mock system classes/protocols as well as dynamic Swift classes. This is an optional subspec `Cuckoo/OCMock`.
- Convenience matchers for sequences and dictionaries. No need to use `equal(to:)` anymore, passing the `Array`/`Set`/`Dictionary` itself is enough from now on!

## 1.1.1
- Fix property, initializer, and function accessibility in public protocols.

## 1.1.0
#### Features:
- Add a simple type guesser based on assigned value.

#### Fixes:
- Fix accessibility problems.

## 1.0.6
- Fix a bug where adding a private name to a function made it generate twice and fail the compilation.

## 1.0.5
- Fix generic protocol generation and type erasure with multiple methods of same name.
- Fix a bug concerning empty public name methods with no private ones.
- Exit `run` script with error if it fails to get generator download URL.

## 1.0.4
- The `run` script doesn't use `realpath` command anymore because it's not available by default on Mac OS.
- Remove redundant stubbing of optional classes.

## 1.0.3
- Add support for optional read-only properties.

## 1.0.2
- Fix `where` clause that doesn't work in Swift 4.
- Fix some `run` script bugs.

## 1.0.1
- Fix `any()` not working anymore by itself with optional parameters in functions.

## 1.0.0
#### Features:
- **Generics** is now fully supported! This includes generic classes, protocols and methods.
- `Dictionary` matching out of the box.
- Better closure matching. Now allowing up to 7 parameter closures.
- `rethrows` functions now work properly.
- Allow non-optional values to be passed as matchers for `Optional`s just like in normal Swift code.
- Add support for inout method parameters.

#### Fixes:
- Update the `build_generator` script to work with Swift 5.
- Fix not being able to put `Optional` into functions accepting `Optional`s.
- Accessibility of variables and functions in `public` classes are now `public` as well.

## 0.13.0
- Updated for **Xcode 10.2** and **Swift 5**.

## 0.12.1
- Add class accessibility support.
- Add support for attributes (e.g. `@available`).
- Add support for subimport (e.g. `import struct UICat.Food`).
- Add `--clean` option to the run script to always build or download the generator (promptly forget to add its documentation to `README.md`).
- Ignore `final` classes (because we mock by inheritance).
- Smaller fixes and improvements in the whole project.

## 0.12.0
- Add first draft of a new Mock initialization DSL.
- Add `enableDefaultImplementation` to protocol `Mock`.
- Reintroduce support for pre-0.11.0 Cuckoo spies.
- Add **regular expression** `class` and `protocol` matching.
- Add **glob** switch that parses input paths as globs enabling for easier project scaling.
- Build generator by default. Download using `--download [VERSION]` option.
- Modify the `run` bash script to allow the user to build rather than download the `cuckoo_generator`.
- Add a debug flag that generates general info above methods when used.
- Fix escaping closure (crashing in Xcode 10).

## 0.11.0
- Added contribution guide.
- **BREAKING CHANGE**: Spies were reworked. They now use superclasses as their victims if enabled. Please see the Readme for more information.
- **BREAKING CHANGE**: Verification of properties' `get` is now a method you have to call, instead of a property. This change was made to remove the "unused result" warning.  [bug #141](https://github.com/Brightify/Cuckoo/issues/141)

## 0.10.2
- Double the maximum parameters in `call` and `callThrows` methods. [bug #145](https://github.com/Brightify/Cuckoo/issues/145)
- Make the generator deterministic by sorting input files.
    - [bug #157](https://github.com/Brightify/Cuckoo/issues/157)
    - [PR #158 - kudos to IanKeen](https://github.com/Brightify/Cuckoo/pull/158)
- Add `equalTo` for `Array` and `Set` where `Element` is `Equatable`.

## 0.10.1
- Fixed some errors with getters [bug #151](https://github.com/Brightify/Cuckoo/issues/151)

## 0.10.0
- Updated for **Swift 4** (Xcode 9 GM)

## 0.9.2
- Fixed crash when source files were using non-ASCII characters - [bug #126](https://github.com/Brightify/Cuckoo/issues/126)
- Added `--exclude` parameter to explicitly exclude some types from mocking - [PR #112](https://github.com/Brightify/Cuckoo/pull/112) - (thanks to nxtstep for the feature)
- Fixed compile errors when generating stubs where inner types were returned - [bug #118](https://github.com/Brightify/Cuckoo/issues/118)
- Added possibility to reset multiple mocks with different types at once - [but #103](https://github.com/Brightify/Cuckoo/issues/103)

## 0.9.1
- Fixed "too complex to resolve in reasonable time" error in generator
- Fixed directory names for case sensitive file systems - [PR #114](https://github.com/Brightify/Cuckoo/pull/115) - (thanks to sundance2000 for the fix)
- Moved repository from `SwiftKit` to `Brightify` organization on GitHub.

## 0.9.0
- Rewritten Generator to use Stencil
- Use Swift PM for generator binary (results in faster builds)
- This release works with Swift 3.1

## 0.8.4
- Added support for inheritance mocking.

## 0.8.3
- Added support for `fileprivate` (thanks to lvdstam for implementation).
- Added support for default values (thanks to lvdstam for implementation).
- Fixed wrongly generated code where public class had internal members.

## 0.8.2
- Show error in generator in build log.
- Fixed crash of generator when instance variable type is not explicitly set.
- Fixed support of closures and unwrapped optionals.

## 0.8.1
- Set "Reflection Metadata" to "None" to fix #72

## 0.8.0
- Support for **Swift 3**
- Added --no-class-mocking parameter to generator
- Added Stub objects

## 0.7.0
- Updated documentation
- Added more automated tests
- Added --file-prefix parameter to generator
- `and` and `or` methods can now be used with `Matchable` (literals)
- Using of custom `Matchable`, `ParameterMatcher` and `CallMatcher` is now easier
- Improved fail messages
- Merged generator and runtime repositories, making updating easier.
- Added support for named arguments in methods.
- Added support for classes with custom initializers.
- Changed usage of spies. Instead of `init(spyOn:)` use `init().spy(on:)`.

## 0.6.0
- Added release notes
- Added stub resetting
- Added `thenCallRealImplementation`
- Added argument capturing
- Added `verifyNoMoreInteractions`
- Added on going stubbing
- Added `thenDoNothing`
