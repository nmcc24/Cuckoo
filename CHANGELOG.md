# Changelog

## Unreleased

### Changed
- `SourceLocation` loses `file`: it's `(fileID:filePath:line:column:)`, with `filePath` a `StaticString`, and
  `verify`, `verifyNoMoreInteractions`, `inOrder` and the `MockManager` methods that took a `file:` argument no longer
  do. A failure handler that read `sourceLocation.file` reads `filePath` instead.
- `hasLength(in:)` matches the counts its range contains: `1..<3` matches 1 or 2. `hasLength(inRange:)` is
  deprecated and, with a half-open range, includes its upper bound again, as in Cuckoo 2: beta.2 had changed what
  `inRange: 1..<3` matched without any warning, so code moved from Cuckoo 2 kept compiling but stopped matching 3.

### Fixed
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
