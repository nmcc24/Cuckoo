# Migrating from Cuckoo 2

Move a test suite from Cuckoo 2 to Cuckoo 3, which is built for Swift 6's data-race safety.

## Overview

Cuckoo 3 keeps the generator, the Cuckoofile and the Mockito-style API, so most tests compile unchanged. What
changes comes from Swift 6: mocks now keep the isolation and `Sendable`-ness of the types they mock, per-test
settings replace global ones, and a call with no stub fails the test instead of crashing it. A few options that
only CocoaPods or Xcode projects used are gone.

Work through the sections in order: first the setup, so the mocks generate, then the compiler errors in the
tests, then the behaviour changes, which show up as test failures.

### Requirements and installation

- Swift 6.2 or later (Xcode 26 or later). The Swift 6 language mode is recommended, and it's what brings the
  isolation checks below; the mocks also compile in the Swift 5 mode, which CI doesn't test.
- iOS 17, macOS 14, tvOS 17 or watchOS 10, up from iOS 13 and macOS 10.15.
- SwiftPM only. The podspec and the `run` script, which downloaded or built the generator for build-phase
  scripts, are gone. Add the package and the build plugin as <doc:GettingStarted> shows. To run the
  generator from a script anyway, see "Running the generator yourself" in <doc:Cuckoofile>.
- The plugin of a release runs a prebuilt generator, so your build no longer compiles swift-syntax, and a release
  doesn't depend on swift-syntax at all: your macro packages can use any version. A dependency on a branch or a
  commit still builds the generator from source, with swift-syntax `602.0.0..<605.0.0`.

### The Cuckoofile

- The `xcodeproj` table is removed. List the target's files with `sources` globs, or, with the build plugin, leave
  `sources` out to mock the files of the target the plugin generates for. A leftover `xcodeproj` table fails with
  the `sources` line to write; <doc:Cuckoofile> shows the change.
- The two build plugins are now one, `CuckooPlugin`. Replace `CuckooPluginModular` with it, as is. With
  `CuckooPluginSingleFile`, the plugin generates one file per dependency, from the entry with that dependency's
  name, plus one from the entry named after the test target, instead of every entry into one file. Rename entries
  to match, and move an entry that lists files from several modules to the test target's name. The tests don't
  change: the mocks land in the same test module either way.
- With the build plugin, a module without `sources` mocks the target's own files, which the plugin lists. Entries
  that list `sources` work as before.
- New keys: `regex` also takes an array of patterns, `sources` takes a table by Swift module, and the options
  `mockPrefix`, `mockSuffix` and `defaultIsolation`. Set `defaultIsolation = "MainActor"` for a module built with
  MainActor default isolation, or its mocks won't match its types.

### Mocks follow the mocked type's isolation

Cuckoo 2 marked every mock `@unchecked Sendable` and left the rest to the compiler. In Cuckoo 3 a mock is `Sendable`
exactly when the mocked type is, and has its isolation: the mock of a `@MainActor` protocol is `@MainActor`, and
the mock of an `actor` protocol is an actor. Errors this brings to light are races the old mocks hid:

- Passing the mock of a non-`Sendable` type to another task or actor no longer compiles. Make the protocol
  `Sendable`, or keep the mock in one isolation domain, as the real type would have to be.
- A `@MainActor` mock is created, stubbed and verified on the main actor. Mark the test `@MainActor`.
- `thenReturn` on the mock of a `Sendable` type takes `Sendable` values, and its `then` closures are `@Sendable`.
  A `@MainActor` mock's closures are `@MainActor`, so they can use main-actor state directly.
- An actor mock's `then` closures receive the mock itself, `isolated`, before the call's arguments:
  `then { mock, entry in … }`. Actor mocks have no default implementation; stub their members instead.

Mocks and the `<Type>Stub` classes are `final`. Subclass the mocked class, not the mock, if a test needs its own
behaviour on top.

### API changes

- `MockManager.fail` is gone. To receive failures yourself, set a ``CuckooConfiguration`` with a
  `failureHandler`, for one test with `.cuckoo(failureHandler:)` or for any scope with
  `CuckooConfiguration.$current.withValue(_:operation:)`.
- ``DefaultValueRegistry/register(_:for:)`` takes `Sendable` values. It still applies to every test; for
  values only some tests need, register them in `DefaultValues` through `.cuckoo(defaultValues:)`, which tests
  running in parallel don't share.
- A failure handler's ``SourceLocation`` has no `file`: read `filePath`, a `StaticString`, which is the full path
  Xcode needs. The checks no longer take a `file:` argument.
- `hasLength(inRange:)` is deprecated in favour of ``hasLength(in:)``, whose range means what it says. With a
  half-open range, `inRange:` kept including the upper bound, as `inclusive: true` did by default: `inRange: 1..<3`
  matches 3, and so does `in: 1...3`, while `in: 1..<3` doesn't. Move each call to `in:` with the range you mean.
- `enableDefaultImplementation(mutating:)` is removed: it kept a pointer to your variable after the call returned.
  A `struct` default implementation is copied once and keeps the changes made through the mock; pass a class
  instance to share state with the test.
- A `then` closure that spells out an `inout` parameter's type needs `inout`, as in `{ (value: inout Int) in … }`.
  What the closure writes now reaches the caller. Closures that let Swift infer the types are unaffected.
- The stub function types that `when` returns, such as `ProtocolStubFunction`, have more generic parameters. Code
  that names them, rather than letting `when` infer them, needs updating.
- Deprecated, with a warning that names the replacement: `register(value:forType:)` for
  ``DefaultValueRegistry/register(_:for:)``, and `equal(to:)` on a class that isn't `Equatable`, which compared
  identities, for ``sameInstance(as:)->SendableMatcher<T>``. `equal(to:)` on an `Equatable` class now compares with `==`.
- Conforming your own types to `Matchable` or `OptionalMatchable` is deprecated. Replace `extension User: Matchable { … }` with
  `equal(to: user)` where you pass the value, which takes any `Equatable` type; for other types use
  `equal(to:equalWhen:)` or a matcher of your own. See <doc:Matching>.
- The stubs of a `Sendable` or actor mock take only ``SendableMatcher``s, since the mock can be called from any task.
  A matcher that keeps a non-`Sendable` value doesn't compile there. In a project that isolates code to the main
  actor by default, make the value's conformance `nonisolated Equatable` for such a mock.
- `any()`, `anyInt()`, `anyString()`, `isNil()`, `notNil()`, `anyClosure()`, `hasLength` and `sameInstance(as:)`
  return a ``SendableMatcher``. Code that names their type as `ParameterMatcher<…>` needs `SendableMatcher<…>`, or
  `.matcher` for a `ParameterMatcher`.
- The Objective-C bridge (`objcStub`, `objcVerify` and the OCMock dependency) is removed. Put a small Swift
  protocol in front of an Objective-C dependency and mock that, or use OCMock directly in those tests.

### Behaviour changes

- A call with no matching stub records a failure, then answers so the test can go on: a member that throws
  `any Error` throws ``CuckooError/unstubbedCall(method:)``, and any other, a `rethrows` one included, returns a
  default value. Cuckoo 2
  crashed the test process. A test that relied on a mock answering with defaults, without stubs, now fails: stub
  those calls with `any()`, or make the mock answer quietly with
  `withEnabledDefaultImplementation(GreeterStub())`.
- Failures go to the framework running the test only: Swift Testing records an issue, XCTest an `XCTFail`.
  Cuckoo 2 reported each failure to both.
- A failed `verify` leaves the calls it looked at unverified, so a later `verifyNoMoreInteractions` still reports
  them.
- `enableSuperclassSpy()` on a protocol mock, which has no superclass, records a failure.
- Failure messages list the calls a member received, and the argument each stub or `verify` rejected.

### Swift 7 features

Under the `MemberImportVisibility` upcoming feature, a type that relies on `ObservableObject`'s default
`objectWillChange` needs `import Combine` in its file: importing SwiftUI doesn't make Combine's extension members
visible. The generated mocks copy each source file's imports, so adding it to the source fixes both.

### New in Cuckoo 3

Once the suite compiles, these can replace workarounds:

- Static and class members can be mocked: `stub(MockClock.self) { … }`, inside a `.cuckoo()` test or
  `withStaticStubs { }`.
- ``inOrder(strict:fileID:filePath:line:column:_:)`` and ``eventually(timeout:pollingInterval:_:)`` verify
  call order and calls made from another task.
- Typed throws, `inout`, `~Copyable` arguments and parameter packs can be stubbed.

See <doc:StubbingAndVerification> and <doc:Matching> for all of them.
