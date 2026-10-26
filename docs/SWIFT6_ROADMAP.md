# Cuckoo for Swift 6: analysis and roadmap

Status: draft, 2026-10-22. Branch `nmcc24/swift6-roadmap` on `nmcc24/Cuckoo` (fork of `Brightify/Cuckoo` at `7cef639`, v2.4.0).

Goal: make Cuckoo (or a successor) fully Swift 6 compliant on Swift 6.2–6.4, able to mock `@MainActor`, global-actor and `Actor` protocols, and broaden what can be mocked. Swift 5 language mode support is dropped.

---

## 1. Where things stand (measured, not guessed)

Toolchain used: Xcode 27.1, Swift 6.4 (`swiftlang-6.4.0.34.1`), macOS 27 SDK.

### 1.1 Existing test suite
- `xcodebuild test -scheme Cuckoo-macOS` passes all **342 tests**, but only with `MACOSX_DEPLOYMENT_TARGET=12.0`. Xcode 27 rejects the project's 10.15 deployment target (minimum is 12.0).
- `swift test` doesn't work. The test target needs the Tuist-generated `CuckooMocks` framework (a pre-build script runs the generator), so only the Tuist workspace can run tests.
- The OCMock bridge tests (`Tests/OCMock`) don't run anywhere: the Tuist project has OCMock and those sources commented out.
- The generator has **one** unit test (`OrderedSetTest`). It has no golden-file or snapshot tests. *(Phase 0 added snapshot tests that `swift test` runs; see Phase 0 status.)*

### 1.2 Swift 6 feature matrix
Run `scripts/swift6-matrix.sh` to reproduce. It generates mocks for each file in `Fixtures/Swift6/` and typechecks the result with `-swift-version 6`.

| Fixture | Errors | Root cause |
|---|---|---|
| 01 `@MainActor protocol` | 4 | Mock conforms to `Cuckoo.Mock`, `HasMockManager` (nonisolated requirements) while inheriting MainActor isolation → `#ConformanceIsolation` |
| 02 `protocol P: Actor` | 12 | Generator always emits `class`; actors need `actor`. Also emits `XStub` as class. **Fixed in Phase 3.** |
| 03 `@MainActor class` | 4 | Same as 01 |
| 04 custom `@globalActor` protocol | 4 | Same as 01 |
| 05 `Sendable` protocol + `@Sendable` closures | 0 | ok (compiles; runtime is not actually thread-safe, see 1.3) |
| 06 `@MainActor` protocol with `nonisolated` member | 8 | Same as 01, plus `nonisolated` is dropped from members |
| 07 `sending` parameter / result | 14 | `sending` copied into tuple and generic positions where it's illegal |
| 08 `isolated (any Actor)?` parameter | 0 | compiles (semantics untested) |
| 09 `nonisolated(nonsending)` / `@concurrent` | 0 | compiles, but the attributes are dropped silently (the crawler only keeps `@available`) |
| 10 per-member `@MainActor` | 0 | compiles, but isolation is dropped from the mock members |
| 11 `some Collection<Int>` parameter | 8 | `some` copied into matcher generic constraints |
| 12 subscript requirement | 4 | Subscripts are not crawled at all |
| 13 `static func` requirement | 4 | Static members are skipped, so the protocol can't be satisfied |
| 14 parameter packs (`each T`) | 58 | Not modeled |
| 15 `~Copyable` + `consuming`/`borrowing` | 48 | Matchers and recorded calls require `Copyable` |
| 16 typed throws | 0 | ok |
| 17 `AsyncSequence<Int, Never>` (protocol marked `@available(macOS 15, iOS 18, …)`) | 0 | ok. Cuckoo copies `@available` onto the mock and the stub. (An earlier version of this fixture lacked the annotation and failed in its own source, not in the mock.) |
| 18 plain protocol | 0 | ok |
| 18 with `-default-isolation MainActor` | 0 | compiles; the mock becomes MainActor-bound implicitly (untested at runtime) |

### 1.3 Runtime concurrency audit (`Source/`)
- `MockManager` is a non-Sendable `class`. Every generated mock is marked `@unchecked Sendable` to silence the compiler. That's the root of failures 01/03/04/06: if the manager were genuinely `Sendable`, mocks could hold it as `nonisolated let`.
- Locking is partial. `stubCalls` appends go through a `DispatchQueue`, but these don't:
  - `stubs.insert` (`createStub`);
  - the stub lookup in `call*Internal`;
  - `verify` reading `stubCalls` and rewriting `unverifiedStubCallsIndexes`;
  - `clearStubs`;
  - the `isSuperclassSpyEnabled` / `isDefaultImplementationEnabled` flags.

  These race under Swift Testing's parallel execution.
- Global mutable state that is shared across tests:
  - `MockManager.fail` (`nonisolated(unsafe) static var`);
  - `DefaultValueRegistry.registeredTypes` (`nonisolated(unsafe) static var`);
  - `preconfiguredManagerThreadLocal`, which is thread-local, not task-local. A task can hop threads, so a manager set this way can be lost or end up on the wrong task.
- Failure reporting calls both `XCTFail` and `Issue.record` whenever both modules can be imported. With the XCTest/Swift Testing interop in Swift 6.4 this risks double-reporting, or reporting into the wrong framework.
- An unstubbed call runs `failAndCrash`, which raises `NSException` and then `fatalError`. That kills the **whole test process**, including every other parallel test (upstream issue #105).
- Rethrowing paths re-throw via `DispatchQueue(label: "No-care?").sync`. It's a workaround with no purpose under typed throws.
- Stub actions are non-`@Sendable` closures stored in a shared object, and recorded arguments are stored without any isolation story.
- `enableSuperclassSpy` / `enableDefaultStubImplementation` guard on `stubCalls.isEmpty` (calls already made), not on stubs, so the error message is misleading.

### 1.4 Generator audit (`Generator/Sources/`)
- **Parser is outdated:** pinned to swift-syntax **601.0.1** (the Swift 6.1 grammar), and the allowed range `600.1.0..<603.0.0` excludes 603 (Swift 6.3) and 604 (Swift 6.4). Upstream #596. *(Fixed in Phase 1: the range is `600.0.0..<605.0.0`, pinned to 604.0.0.)*
- **Attributes are discarded:** only `@available` is kept (`Crawler.attribute(from:)`). Isolation attributes (`@MainActor`, custom global actors, `nonisolated`, `nonisolated(nonsending)`, `@concurrent`), `@objc`, `@_spi` and `@preconcurrency` are all lost.
- **Container kinds are hard-coded:** the templates always emit `class` (`MockTemplate`, `NopImplStubTemplate`).
- **`#if` is ignored:** both branches are parsed, which produces duplicates. Upstream #471.
- **Unknown property types crash:** a stored property whose type can't be inferred hits `fatalError` and aborts the whole run.
- **Documented options that don't work** *(fixed in Phase 0)*:
  - `keepDocumentation` is parsed but never read. The crawler also dropped doc comments on every indented declaration, so mocks never had docs;
  - `StubbingProxyTemplate` uses `method.isThrowing` inside the property loop (dead code).
- **Version mismatch** *(fixed in Phase 0)*: `Version.swift` is stuck at `2.0.10`. The release lane writes it but never commits it, so the `run` script rebuilds the generator on every build. Upstream #601.
- **Not portable to Linux** *(fixed in Phase 0)*: `Glob` uses `glob_t.gl_matchc`, FileKit doesn't compile on Linux, and `OrderedSet` (backed by `NSMutableOrderedSet`) doesn't dedupe there, which repeats imports in generated files. This also blocks working on the generator from Linux cloud sessions.
- **Stencil templates:** untyped and hard to debug. Signatures are spliced in by string-replacing filters (`genericSafe`, `removeClosureArgumentNames`).
- **Xcode project support:** XcodeProj source discovery doesn't handle `PBXFileSystemSynchronizedRootGroup`, which is the default in Xcode 16+ projects (upstream #524).

### 1.5 Open upstream issues this roadmap absorbs
#601 version mismatch · #599 `unavailable` regression · #596 Swift 6.3 · #594 Swift 6 test targets · #531 Swift 6 features · #513 `@MainActor @Sendable` closures · #457 Actor protocols · #470 `some` + throws · #521 `class func` · #520 typed throws · #524 synchronized groups · #471 compiler flags / `#if` · #576 parent protocol associated types · #560 protocol conformances · #564 mock prefix · #561 `@_spi` · #535 regex array · #447/#376 class-constrained protocols · #362 generic init · #337 `inout` · #304 `Self` · #105 don't crash on unstubbed calls · #277 verify with delay · #556 never-returning async stubs · #34 `inOrder` · #26 Linux.

### 1.6 Landscape (for positioning)
- **Macro-based libraries** (`@Mockable`-style: Kolos65/Mockable, yysskk/swift-mockable, DanielCardonaRojas/swift-mocking) are zero-config and Swift 6 aware. They can only mock declarations you annotate, though, so not third-party protocols or classes, and not inherited class members.
- **Generator-based libraries** (Cuckoo, Mockolo) can mock anything in a source set, including classes. Today Cuckoo is the only one with Mockito-style matchers, spies and default implementations, but it lags on Swift 6.
- **Cuckoo's edge to keep:** whole-source scanning, class mocking with spies, matchers. **Gap to close:** concurrency correctness, modern syntax, parallel-test safety.

---

## 2. Strategy decision

**Recommendation: build "Cuckoo 3" as a new major version in this fork.** Keep the architecture (source generator, Mockito DSL), but rewrite the runtime core and the code-generation layer. Upstream individual fixes to Brightify where they fit 2.x.

Why not a brand-new project?
- The crawler, the inheritance merging, the generics and associated-type handling, and 342 behavioural tests are years of edge-case work.
- What's broken is concentrated in three places: the runtime's isolation model, the attribute/kind handling, and the old parser. All three are replaceable in place.

A brand-new name or repo is still an option at the end of Phase 3 if the API diverges enough. Decision **D1** below.

Breaking changes accepted in 3.0:
- Swift 6 language mode only; Swift 6.2 toolchain minimum (needed for `nonisolated(nonsending)` and isolated conformances); tested on 6.2, 6.3 and 6.4.
- Minimum OS: iOS 17, macOS 14, tvOS 17, watchOS 10 (parameter-pack generic types need this runtime). Newer OS and compiler versions unlock extra features on top (§3.4). Decision **D2**.
- SwiftPM only. CocoaPods trunk is moving to read-only, and the `run` script and podspec go away. Decision **D3**.
- The OCMock bridge moves to an optional separate package, or is dropped. Decision **D4**.

---

## 3. Target design (3.0)

### 3.1 Runtime
1. **`MockManager` becomes `final class MockManager: Sendable`.** All state lives in a single `Locked<State>`, a small lock wrapper based on `NSLock` (portable to Linux, no OS-version floor; `Synchronization.Mutex` would need iOS 18 / macOS 15).
   - Recorded arguments and stub actions sit in an internal `@unchecked Sendable` box. The boxing is honest: every access is under the lock.
2. **Protocol requirements are `nonisolated`.** The requirements of `Mock`, `HasMockManager`, `StubbingProxy` and `VerificationProxy` become `nonisolated` and `Sendable`-friendly, and mocks store `nonisolated let cuckoo_manager`. This alone fixes the `#ConformanceIsolation` errors for MainActor and global-actor mocks.
3. **Per-test state is task-local.**
   - `@TaskLocal` configuration replaces the global `fail` handler, the global `DefaultValueRegistry` overrides and the thread-local preconfigured manager.
   - A Swift Testing trait sets it per test or suite: `@Suite(.cuckoo(defaultValues: …))`.
4. **Failure routing.** Failures go to `Issue.record` when `Test.current != nil`, otherwise `XCTFail`, never both. Source locations are preserved.
5. **An unstubbed call never takes the process down.** It records an issue, then returns a registered default value, or throws `CuckooError.unstubbedCall` for members that throw `any Error`. It crashes only when no value can be produced. There is no lenient or crash mode (decided 2026-10-24): a lenient mode hides real bugs, "don't care" collaborators are stubbed with `any()` or use `enableDefaultImplementation`, and a crash mode brings back the problem this fixes.
   - Result: tests no longer take down the whole process.
6. **Stub closures match the mock's isolation** (done in Phase 3). The generator picks each stub's closure type, and a `StubSharing` marker decides what `thenReturn` takes:
   - nonisolated, non-`Sendable` mocks (`Confined`): plain closures and any value, as in 2.x;
   - `Sendable` nonisolated mocks (`Shared`): `@Sendable` closures, `Sendable` values;
   - `@MainActor` and global-actor mocks (`Isolated`): `@MainActor @Sendable` (or that actor) closures, which can use the actor's state directly; `thenReturn` takes a `sending` value;
   - actor mocks (`Shared`): `@Sendable` closures that receive `isolated MockX` first, then the call's arguments.
   - Async members get async closures; nonisolated ones are `nonisolated(nonsending)`. The runtime never calls user closures itself: the mock passes an `invoke` closure, formed in its own isolation.
7. **New verification features:**
   - `inOrder { verify(a).x(); verify(b).y() }` (#34);
   - `verify(mock, .times(1), within: .seconds(1))` and `await eventually { … }` for async code paths (#277);
   - `verifyNoMoreInteractions(a, b)`;
   - a `Sendable`, typed `ArgumentCaptor`.
8. **New stubbing features:**
   - `thenNeverReturn()` for async members, which suspends until cancelled (#556);
   - `thenReturn(after: .milliseconds(…), value)`;
   - `thenCallRealImplementation()` for default-implementation mocks;
   - `inout` mutation (#337).
9. **Typed throws end to end.** The `"No-care?"` queue hack goes away. `then` closures use `throws(E)`.
10. **Swift Testing integration:**
    - a `.cuckooMocks` trait that resets the given mocks after each test;
    - `confirmation`-style helpers;
    - `#expect`-quality failure messages that show the closest stub's argument diff.

### 3.2 Generated code shape
| Source declaration | Generated mock |
|---|---|
| `protocol P` | `nonisolated final class MockP: P, nonisolated Cuckoo.ProtocolMock`, `Sendable` exactly when `P` is. Explicit `nonisolated` keeps it independent of the module's default isolation. |
| `@MainActor protocol P` | `@MainActor final class MockP: P, nonisolated Cuckoo.ProtocolMock` with `nonisolated let cuckoo_manager`; proxies `nonisolated` |
| `@SomeGlobalActor protocol P` | same as above with that actor |
| `protocol P: Actor` | `actor MockP: P, Cuckoo.ProtocolMock` with `nonisolated let cuckoo_manager`. Sync requirements are actor-isolated and record synchronously; `enableDefaultImplementation` forwards async requirements only, and a sync one reached that way crashes with a message saying so. |
| `nonisolated func` in an isolated protocol | `nonisolated func` in the mock |
| `@MainActor func` in a plain protocol | member-level `@MainActor` preserved |
| `nonisolated(nonsending)` / `@concurrent` / `sending` / `isolated` | preserved on the mock signature; stripped from matcher, tuple and generic positions |
| `@MainActor class C` | `@MainActor class MockC: C, Cuckoo.ClassMock` |
| `some P` parameter | mock keeps `some P`; proxies take `M: Matchable` with `MatchedType == any P` |
| `each T` parameter packs | recorded as one `Cuckoo.ParameterPack` (its values as `[Any]`), matched with `anyPack()`, `equal(toPack:)` or a closure; a class's pack methods aren't mocked, because Swift can't override them |
| `~Copyable` / `consuming` / `borrowing` | call recorded with a placeholder; parameter matchable only with `any()` or a `borrowing` predicate closure |
| `subscript` | `subscript` mocks with `stub.subscript(key).get/.set` and verify equivalents |
| `static` / `class` members | supported through a per-type static manager that is task-local and reset per test (#521) |
| `@available`, `#if` | availability propagated to every generated member; `#if` mirrored into the output, not evaluated |

### 3.3 Generator
- Move to swift-syntax `600.0.0..<605.0.0` and follow pointfree's "flexible dependence" guidance. Use the SwiftPM swift-syntax prebuilts to cut build time.
- **Replace Stencil with typed codegen:** SwiftSyntaxBuilder, or a small typed `CodeWriter` over the token model. That gives compile-time-checked templates, `swift-format`-clean output, and drops the Stencil/PathKit dependencies.
- **Model isolation explicitly:** `Isolation = .nonisolated | .mainActor | .globalActor(String) | .actorInstance` on containers and members, plus `kind = .class | .actor`.
- **Attribute pass-through allow-list:**
  - isolation attributes;
  - `@preconcurrency`;
  - `@_spi(X)` (#561);
  - `@objc` / `@objcMembers` (when NSObject-based);
  - `@available`, including `unavailable` handling (#599).
- **Diagnostics instead of crashes:**
  - Unsupported constructs produce a structured warning (`file:line: warning: cuckoo: …`) that SwiftPM and Xcode surface, and the member is skipped or emitted as `fatalError` with a `#warning`.
  - `fatalError` disappears from the crawler.
- **Small fixes:**
  - `keepDocumentation` actually works;
  - `mockPrefix` / `mockSuffix` options (#564);
  - `regex` accepts an array (#535);
  - `class`-constrained protocols (#447/#376);
  - `Self` (#304), generic init (#362), parent protocol associated types (#576);
  - conformances respected (#560).
- **Xcode projects:** XcodeProj is dropped (decided 2026-10-25): the Cuckoofile `xcodeproj` option is gone, and the build plugins will hand the generator the target's exact file list, which also covers `PBXFileSystemSynchronizedRootGroup` (#524).
- **Linux:** make the generator build there (`gl_pathc` instead of `gl_matchc`, `FileManager`-based globbing).
- **Mock dependency types by module name:** let a Cuckoofile entry say `dependencies = ["Alamofire"]` (or `sources = ["@Alamofire/**"]`). The build plugin resolves the module's source files from the SwiftPM or Xcode package graph, so nobody has to hard-code `.build/checkouts` or DerivedData paths. Only protocols and `open` classes from another module can be mocked, because Swift forbids subclassing `public` non-`open` classes across modules.
- **Mocks from `.swiftinterface` files:** parse the textual interfaces of binary `.xcframework`s, so closed-source Swift SDKs can be mocked too (protocols and `open` classes). Swift interfaces are ordinary Swift syntax, so the existing crawler mostly applies.
- **Distribution:** ship the generator as a prebuilt `artifactbundle` `binaryTarget`, so consumers stop compiling swift-syntax. Fix `Version.swift` (#601) by generating it at build time from a single source of truth.
- **Performance:** cache crawl results by file content hash in the plugin work directory, and emit one file per input when requested.

### 3.4 Capability tiers (newer Swift and OS versions unlock more)
The baseline must be complete on its own. Newer tiers only **add** APIs or faster paths; they never change behaviour, so a test means the same thing on every tier.

**Compiler tiers (the Swift version that builds the tests).**
- The runtime guards newer language features with `#if compiler(>=6.3)` / `#if compiler(>=6.4)`. Example: Swift 6.4's `~Sendable` marker for types that must never cross threads, such as recorded-call buffers.
- The generator emits syntax the consumer's compiler understands. The build plugin passes the toolchain version in, or the generated code wraps newer syntax in `#if compiler(>=…)`.
- Mocks for source that uses 6.3/6.4-only syntax work automatically, because that source only builds on those compilers anyway.

**Runtime/OS tiers (the OS the tests run on).**
- Extra runtime APIs are marked `@available(iOS 18, macOS 15, tvOS 18, watchOS 11, *)` or newer, for example:
  - typed storage for non-copyable (`~Copyable`) arguments;
  - `Mutex`-based internals where they measurably help;
  - Swift 6.2-runtime (iOS 26) helpers for isolated conformances.
  - typed-throws `then` closures: a typed-throws function type used as a generic argument needs the iOS 18 / macOS 15 / tvOS 18 / watchOS 11 runtime. At the D2 baseline the stub's closure type throws untyped errors and the mock narrows them back to the member's error type (Phase 3). With a higher minimum, or for mocks of declarations already available only there, the closure type could keep `throws(E)`, so the compiler checks the error type a stub throws. To consider if D2 rises.
- Generated mocks inherit the `@available` of the declaration they mock (already true today; fixture 17). A mock for an iOS 18-only protocol can therefore use iOS 18-only runtime helpers without extra checks.
- If a mocked declaration needs a feature above its availability, the generator falls back to the baseline form, such as `any()`-only matching for that parameter, and emits a diagnostic saying which OS unlocks the full form.

**Testing.**
- CI runs the suite at the lowest tier (iOS 17 / macOS 14 deployment target) and the highest (newest OS and toolchain).
- Fixtures cover each tier boundary.
- Whether iOS 17 simulator runtimes are available on the CI image needs checking. If they aren't, cover the lowest tier by building with that deployment target and running tests on the newest simulator.

### 3.5 Optional macro front-end (Phase 5)
- A `@Mockable` attached macro that reuses the same token model and code writer. It gives zero-config mocks for first-party protocols that opt in.
- The build plugin stays for third-party and unannotated types. Both produce identical APIs.

---

## 4. Phased plan

Legend: ☁️ can be done entirely in a Linux cloud session (code plus Linux build/tests); 🍎 needs macOS, so it's validated through GitHub Actions on the fork (push a branch, read CI).

**Sizes are relative, not durations.** An earlier draft gave week estimates that weren't based on anything.
- **S:** isolated changes that existing tests or snapshots fully check.
- **M:** touches the generator's model across many templates; snapshot output changes widely and needs review.
- **L:** rewrites a core piece (runtime or codegen), or adds many features that each need fixtures. Regressions show up in the 342 runtime tests or on specific toolchains, so it takes several CI and review rounds.

What makes a phase big:
- **Phase 1:** the attribute/specifier model touches every template.
- **Phase 2:** a runtime rewrite that must keep the 342 tests green on every image.
- **Phase 3:** new container kinds (actors) and isolation-aware proxies.
- **Phase 4:** many independent features, each with fixtures.
- **Phase 5:** replacing Stencil, plus release tooling.

**Phase 0 actuals, for calibration:**
- **First pass:** the first Phase 0 commit landed at 2026-10-22 10:19 UTC, and every CI job was green at 11:05 UTC, about 45 minutes. Most of it was spent waiting on the macOS runner queue.
- **Review rounds:** two rounds over the next day (xcode-27 runners, a job per macOS image, both 6.4 build systems, syncing `master` with upstream) took most of the remaining elapsed time.
- **CI runs:** 15 on the branch, 10 of them cancelled by follow-up pushes.

Elapsed time is driven by review rounds and the macOS runner queue more than by writing code.

### Phase 0: Foundations and dev loop (S)
1. ☁️ Make the generator build and run on Linux (Glob fix; check FileKit, XcodeProj and TOMLKit on Linux; add `#if canImport(Darwin)` where needed).
2. ☁️ Make the runtime `Cuckoo` target build on Linux (XCTest/Testing imports, `NSException` already guarded).
3. ☁️ Golden-file test harness for the generator: `Generator/Tests/Snapshots/*.swift`, with input fixtures → expected mock output, run by `swift test --filter CuckooGeneratorTests`. Seed it with `Fixtures/Swift6/`.
4. ☁️ Add `scripts/swift6-matrix.sh` to CI (already in the repo). On Linux it typechecks against the Linux-built runtime.
5. 🍎 CI matrix:
   - Linux (Swift 6.2/6.3/6.4 containers): generator tests and matrix;
   - macOS on the newest available Xcode: Tuist test schemes;
   - raise the Tuist deployment targets to the D2 minimums.
6. ☁️ Fix the version-bump bug (#601) and the dead `keepDocumentation` / template code.

Exit criteria: CI is green on Linux and macOS; a cloud session can change the generator and see snapshot and matrix results without a Mac.

**Status (2026-10-22): all six items done.**
- Linux: the generator and the runtime build on Swift 6.2, 6.3 and 6.4. FileKit was replaced by a small Foundation `Path`/`TextFile`, Glob reads `gl_pathc`, and `OrderedSet` is now a pure-Swift value type.
- `swift test` runs `CuckooGeneratorTests` (Generator/Tests):
  - one snapshot per `Fixtures/Swift6` file;
  - a snapshot of the runtime test sources (mirroring the `Cuckoo` module in `Cuckoofile.toml`);
  - a documentation snapshot and a version check.

  Re-record with `CUCKOO_RECORD_SNAPSHOTS=1 swift test`. The SwiftPM `CuckooTests` target was removed because it never built; Tuist still runs those tests.
- `scripts/swift6-matrix.sh` reads `Fixtures/Swift6/expected-failures.txt`. It fails on a new failure, or on a listed fixture that now passes. `SWIFT_BUILD_FLAGS` passes a build system to `swift build` (`--build-system native` or `--build-system swiftbuild`).
- CI (`.github/workflows/test.yml`):
  - Linux jobs in `swift:6.2`/`6.3`/`6.4` containers;
  - macOS generator jobs on each runner image;
  - the existing Tuist jobs, now at the D2 deployment targets;
  - `workflow_dispatch`.
- **Toolchain coverage.** Each macOS job (generator, Tuist macOS tests, Tuist iOS tests) runs on `macos-26` (Xcode 26.6, Swift 6.3.3) and `xcode-27` (macOS 27, Xcode 27, Swift 6.4). Each uses the image's default Xcode and prints it as an annotation.
  - `macos-15` was tried and dropped: its default is Xcode 16.4 / Swift 6.1.2, below the 6.2 minimum, and fixture 09 (`nonisolated(nonsending)`) can't compile there.
  - Swift 6.2 is therefore covered on Linux only. `xcode-27` is selected by Xcode label, not a `macos-NN` label; GitHub made it generally available on 2026-10-15. The iOS jobs use whichever iPhone simulator the image ships.
- **Build systems.** Swift 6.4 builds with `swiftbuild` by default, while 6.2 and 6.3 use `native`. Linux tests 6.4 with `swiftbuild` only, because SwiftPM 6.4 deprecates `native`, which stays covered on 6.2 and 6.3. On macOS, each image runs only its default build system (`native` on `macos-26`, `swiftbuild` on `xcode-27`), because macOS runners queue far longer than Linux ones.
- **Merge gate.** A final `CI passed` job depends on every other job and fails if any of them failed, was cancelled or was skipped. `master`'s ruleset requires only that check, so matrix changes don't need ruleset edits. The ruleset also requires a PR and an up-to-date branch, and blocks force-pushes and deletion.

### Phase 1: Parser and syntax modernization (M)
1. ☁️ swift-syntax range `600.0.0..<605.0.0`, CI-tested at both ends. Replace deprecated API uses.
   - The floor stays low on purpose. SwiftPM resolves one swift-syntax version per dependency graph, so a narrow range would conflict with macro packages that pin an older release. (`600.1.0` was never released; the 600 line ends at 600.0.1.)
   - The risky combination is a Swift 6.2+ toolchain with swift-syntax 600/601, whose parser predates 6.2 syntax such as `nonisolated(nonsending)` and `@concurrent`. CI tests exactly that pairing. Code that needs a newer swift-syntax API goes behind `#if canImport(SwiftSyntax602)` (or the matching marker module).
   - **Done:** `Package.resolved` pins 604.0.0. A Linux Swift 6.2 job pins 600.0.0, and its snapshots match 604's output, including fixture 09. There were no deprecated swift-syntax APIs to replace at 604.
2. ☁️ Attribute and specifier model:
   - isolation, `sending`, `isolated`, `nonisolated(nonsending)`, `@concurrent`, `consuming`, `borrowing`, `inout`, `some`;
   - strip correctly from matcher, tuple and generic positions (fixtures 07, 09, 10, 11).
   - **Done so far:**
     - Types in generic positions (stubbing and verification proxies, matcher tuples, the stub's default value) drop `sending`, `borrowing`, `consuming`, `inout` and `isolated`, and `some P` becomes `any P`. Fixtures 07 and 11 compile.
     - The mock records an opaque argument as `any P`, so stubs and verifications match it.
     - A `sending` argument is forwarded to the default implementation or superclass through `Cuckoo.__SendingArgument`, a documented `@unchecked Sendable` box: the mock keeps the argument for verification, so it can't stay disconnected.
     - `scripts/swift6-matrix.sh` compiles to SIL instead of only typechecking, so region-isolation errors count. That exposed fixture 08: its async `defaultCall` closure is isolated to the `isolated` parameter and is sent to `MockManager`'s `@concurrent` `call`. It's an expected failure until Phase 2 makes the runtime's async calls run on the caller's isolation (`nonisolated(nonsending)`).
   - **Left for Phase 3 item 3:** member-level isolation is still dropped from mock members. Fixture 09's mock loses `nonisolated(nonsending)` and `@concurrent`, and fixture 10's loses `@MainActor`. The mocks compile, but they don't keep the protocol's isolation. Modelling isolation (`Isolation` in §3.3) belongs with the code that emits it.
3. ☁️ Mirror `#if` into the output (#471). Fix `@available(..., unavailable)` handling (#599); container-level availability already propagates (fixture 17).
   - **Done:**
     - Members inside `#if`/`#elseif`/`#else`, nested too, are wrapped in the same condition everywhere they're generated: the mock, both proxies, the no-op stub and the type-erasing default implementation caller (fixture 20). A whole type inside `#if` gets its mock and stubs in the same condition, nested types carry their enclosing types' conditions, and an import inside `#if` keeps its condition (fixture 20, done in Phase 2 item 0).
     - `@available(*, unavailable)` members aren't mocked, because they can't be overridden. Platform unavailability with a `message:` is recognised, `macCatalyst` maps to `targetEnvironment(macCatalyst)`, and app-extension platforms are skipped. The platform `#if` now also covers the mock body and the verification proxy's properties (fixture 19).
4. ☁️ Replace the crawler's `fatalError`s with diagnostics.
   - **Done:** a property whose type can't be inferred is skipped, with a `file:line:column: warning: cuckoo: …` diagnostic on standard error. `TypeGuesser` no longer turns function calls or literals into bogus types. `var x, y: Int` no longer crashes, and bare `Array`/`Dictionary` types are kept as written. `CrawlerDiagnosticsTests` covers these. The remaining `fatalError`s are internal invariants (a member without a parent), not input problems.

Exit criteria: fixtures 07, 09, 10 and 11 compile, with snapshot tests for each.

### Phase 2: Concurrency-correct runtime (L)
0. ☁️ **Run the runtime test suite with SwiftPM, keeping Tuist in parallel.** Do this first, so the runtime rewrite has a regression suite that runs on Linux.
   - **Done:** `swift test` runs the suite on Linux (341 XCTest tests; the NSObjectProtocol one is Apple-only) and macOS (342), with mocks from `CuckooPluginModular`. CI also runs it on the iOS simulator through `xcodebuild`. Tuist and SwiftPM report the same counts. The generator now mirrors `#if` around whole types and imports, which the SwiftUI and Objective-C fixtures needed on Linux. A shared `CuckooTests` scheme builds only the runtime side for the simulator (`Cuckoo-Package` also builds the generator, and XcodeProj doesn't build for tvOS or watchOS), and CI runs it on the iOS simulator and builds it for tvOS and watchOS (build-only: the runtime is plain Swift, so what can break there is compile-time).
   - **Layout:** a plain target holding `Tests/Swift/Source`, and a test target that depends on it and on `Cuckoo`. `CuckooPluginSingleFile` generates the mocks, the same way users consume Cuckoo. This also gives the build plugin CI coverage, which it doesn't have today.
   - **Runs:** `swift test` on Linux, and `xcodebuild test` on the package per platform (macOS and the iOS/tvOS/watchOS simulators) in CI.
   - **Keep the Tuist schemes running alongside.** Compare test counts and results between the two setups until they agree on every image. Only then decide whether to remove Tuist, mise, `build_generator` and the generated workspace.
   - **Watch for:**
     - plugin output differing from the `Cuckoofile.toml` run (`exclude`, `testableImports`);
     - runtime tests that assume Apple-only behaviour (the `NSException` path in `failAndCrash`), which need `#if` guards or stay macOS-only.
   - **OCMock bridge tests:** they stay disabled until D4's package trait exists.
1. ☁️ `Sendable` `MockManager` with `Locked<State>`, `nonisolated` protocol requirements, honest `Sendable` mocks (drop `@unchecked`).
   - **Done:** `MockManager` is a checked `Sendable` final class whose state sits in one `Locked<State>`; user code (matchers, stub implementations, superclass and default calls) runs outside the lock. Its async calls are `nonisolated(nonsending)`, so a global-actor mock's autoclosures stay on the caller's actor. Mocks keep the default implementation in a `Cuckoo.DefaultImplementation` `let`, and `enableDefaultImplementation` is `nonisolated`. Mocks and nop stubs are `final` and drop `@unchecked Sendable`: a mock is `Sendable` exactly when the mocked type is. Fixtures 01, 03, 04, 06 and 08 now compile.
   - **Documented exceptions:** `__SendingArgument` (forwards `sending` values, now results too), and the type-erased default implementation of generic protocols, whose closures read the stub through an `UnsafeMutablePointer` (Phase 5 item 8).
2. ☁️ TaskLocal configuration, the Swift Testing trait, failure routing, and the unstubbed-call policy.
   - **Done:** `CuckooConfiguration` is a `@TaskLocal` holding default values and an optional failure handler; it replaces `MockManager.fail`. The `.cuckoo(defaultValues:failureHandler:)` trait sets it per test or suite. An unstubbed call records a failure, then throws `CuckooError.unstubbedCall` or returns a default value; an unfinished stub (no `then…` yet) is reported the same way and skipped, so a call racing a stub's registration falls back to an older stub. `createMock` hands its manager over through a task-local instead of a thread-local. `DefaultValueRegistry` takes only `Sendable` values, behind the lock box.
3. ☁️ Stress tests: 1,000 concurrent calls, stubs and verifications on one mock, run under TSan in CI (🍎 for TSan on Apple platforms; ☁️ TSan on Linux).
   - **Done (Linux):** `ConcurrencyStressTest.swift` runs 1,000 concurrent calls, stubs, verifications and clears on one mock, and checks that queued answers go to exactly one call each. A Linux CI job runs the runtime tests with `--sanitize=thread`; it's clean. TSan on Apple platforms isn't in CI yet, to keep the macOS job count low.
4. 🍎 Run the existing 342 tests under the new runtime and fix the regressions.
   - **Done:** with items 1 and 2 in, the suite passes unchanged except `testThreadSafety`, which now uses a mock of a `Sendable` protocol: 342/342 through Tuist on macOS and the iOS simulator and through `swift test` on macOS, 341 on Linux (the NSObjectProtocol test is Apple-only).
5. ✅ Optional-property stubbing no longer constrains `Self`: `ToBeStubbedOptionalProperty` declares a `WrappedType` associated type, which cleared the "will be an error in a future Swift language mode" warning without changing call sites.
6. ☁️ Zero warnings: once our own targets build without warnings, CI treats warnings in them as errors (dependencies excluded).
   - **Done:** `Package.swift` (tools version 6.2) gives our targets `.treatAllWarnings(as: .error)`, and both Tuist projects set `SWIFT_TREAT_WARNINGS_AS_ERRORS`. SwiftPM ignores the setting in packages fetched by URL, so projects that depend on Cuckoo aren't affected; a local path dependency is.

Exit criteria: no `nonisolated(unsafe)` or `@unchecked Sendable` left in `Source/` except the documented lock box; TSan clean; all legacy tests green.

### Phase 3: Isolation-aware code generation (L)
1. ☁️ `@MainActor` and global-actor protocols and classes (fixtures 01, 03, 04, 06), with isolation-matching stubbing and verification proxies.
2. ☁️ `Actor` protocols, generating `actor` mocks and stubs (fixture 02, #457).
3. ☁️ Member-level isolation and `nonisolated` pass-through.
4. ☁️ The `-default-isolation MainActor` mode: generate explicit `nonisolated` where needed so mocks stay usable from nonisolated tests, and add a fixture variant for it.
5. 🍎 Behavioural tests in the Tuist suite: stubbing, verifying and spying on MainActor and actor mocks from Swift Testing and XCTest.

Exit criteria: fixtures 01–06 typecheck and have behavioural tests; also typecheck in default-MainActor mode.

**Status (2026-10-25): items 1–5 done.** The Tuist macOS and iOS schemes, `swift test` on macOS and the package on the iOS simulator pass with 345 runtime XCTest tests, 69 Swift Testing tests and no warnings.
- **Items 1 and 3:** stub closures carry the mock's isolation (§3.1 item 6). The crawler records global actors (any `@globalActor` declared in the scanned files, plus `MainActor`), member-level `@MainActor`/`nonisolated`, and `nonisolated(nonsending)`/`@concurrent`, and the mocks keep them.
- **Item 2:** `Actor` protocols get `actor` mocks and stubs. Fixture 02 compiles and left the expected-failures list.
- **Item 4:** the generator states isolation wherever the module default would otherwise decide it (mocks and stubs of protocols without isolation, the proxies, the type-erased default implementation, the conformance to the Cuckoo protocols). CI runs the matrix with `-default-isolation MainActor` too, against `Fixtures/Swift6/expected-failures-default-mainactor.txt`. Two known gaps there:
  - a subclass of a class that relies on its implicit `init` doesn't compile in that mode, with or without Cuckoo (`class Base {}; final class Sub: Base {}`, Swift 6.2–6.4), so class mocks of such classes fail (fixtures 07, 19, 20, 21);
  - the type-erased default implementation of a generic protocol (fixture 05) is nonisolated, but the module's default makes the protocol MainActor-isolated, which the generator can't see. A Cuckoofile option naming the source module's default isolation would fix it; not started.
- **Item 5:** `Tests/Swift/IsolationTest.swift` (Swift Testing) and `IsolationXCTest.swift` stub, verify and spy on MainActor, global-actor, actor and `Sendable` mocks, including from concurrent tasks. They run in `swift test` and in the Tuist schemes.
- **API change:** stub function types gained two generic parameters (closure type and sharing), so code that names one to pick an overload writes `as ClassStubNoReturnFunction<(Int?, String), _, _>`.
- **Typed throws:** the closure type throws untyped errors, and the mock narrows them back to the member's error type, because a typed-throws function type as a generic argument needs the iOS 18 / macOS 15 runtime (§3.4).

### Phase 3.5: Swift 7 readiness (M)
Projects can already turn on the upcoming features that the Swift 7 language mode makes the default, and generated mocks compile in the user's module with the user's settings. Done before Phase 4, so every new template is checked against them from the start.
1. ☁️ Our own targets adopt the features that only change what compiles: `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault` and `ImmutableWeakCaptures` (Package.swift and both Tuist projects).
2. ☁️ Mocks compile under every feature:
   - untyped throws are spelled `any Swift.Error`, and nop stubs keep `async`/`throws` on getters;
   - an output that holds a public mock imports Cuckoo, the testable imports and the sources' public imports with `public import`; others keep plain imports, because an unused public import is a warning;
   - an async method's non-escaping closures are made escaping in local functions, `nonisolated(nonsending)` for nonisolated members, instead of closures, which run concurrently under `NonisolatedNonsendingByDefault` ("sending 'self' risks causing data races");
   - Swift 6.2 treats an async local function as `@concurrent` under that feature, so the type-erased default implementation's `openExistential` has a `nonisolated(nonsending)` copy behind `#if compiler(<6.3) && hasFeature(NonisolatedNonsendingByDefault)` (fixture 07). **Remove it when Swift 6.2 support ends.**
3. ☁️ CI job `swift7_linux` (Swift 6.2 and 6.4): `swift test` with every feature on (`CUCKOO_UPCOMING_FEATURES`), and the fixture matrix with every feature on and as a new Xcode 26 project (default MainActor isolation plus `InferIsolatedConformances` and `NonisolatedNonsendingByDefault`). Both configurations fail exactly where `generator_linux` does, so they share its expected-failure lists.

Not covered: the runtime suite under default MainActor isolation. Its test sources and XCTest cases subclass classes that rely on an implicit `init`, which that mode rejects with or without Cuckoo (Phase 3 item 4). The fixture matrix covers the mocks in that mode.

Exit criteria: `swift7_linux` is green, with no expected failures beyond the ones `generator_linux` has.

**Status (2026-10-25):** done, merged in https://github.com/nmcc24/Cuckoo/pull/15. Phase 4 must pass all three configurations.

### Phase 4: Coverage expansion (L)
API decisions for items 1–3 (2026-10-25):
- subscripts mirror properties: `stub[key].get`, `stub[key].set(value)`, `verify(mock)[key].get()`;
- static members are stubbed in a task-local registry, so parallel tests don't see each other's stubs;
- a parameter pack is matched as one value (`anyPack()` or a closure over the whole pack);
- a `~Copyable` argument isn't recorded at first, then is borrowed into `then` closures (item 3b);
- an `inout` parameter's `then` closure can write back to the caller.

PRs, in order: subscripts (with an opaque-parameter test), statics, then one each for packs, `~Copyable` and `inout`, then the small items of 3 together, then items 4 and 5, and 3b last, because item 4 reshapes the same `MockManager` generics.

1. ☁️ Subscripts (12) and static/class members (13, Brightify/Cuckoo#521).
   - **Subscripts: done** (https://github.com/nmcc24/Cuckoo/pull/16). A subscript's accessors are recorded as `subscript(…) -> T#get` and `#set`, like a property's. The proxies get a generic subscript that returns a small generated struct with `get` and `set(_:)`, built on the method stub types, so every isolation, effect and class/protocol variant comes for free. Static subscripts came with the static members.
   - **Static and class members: done** (https://github.com/nmcc24/Cuckoo/pull/17).
     - A protocol's `static` requirements and a class's `class` members are mocked. A class's `static` members are final and stay unmocked.
     - Their stubs and calls live in a task-local `StaticStubs` registry, one manager per mock type. The `.cuckoo()` trait starts a fresh registry for each test and each parameterized case, and `withStaticStubs { }` starts one for any other scope, such as an XCTest method. Outside a scope, a static member records a failure that names the fix.
     - Tests use `stub(MockX.self)`, `verify(MockX.self)`, `reset(MockX.self)` and `verifyNoMoreInteractions(MockX.self)`.
     - In the proxies' stub types, `Self` is the mock, so `static func make() -> Self` can be stubbed.
2. ☁️ Opaque parameters (11, Brightify/Cuckoo#470), parameter packs (14) and `~Copyable` parameters (15).
   - Opaque parameters already work: the generator records `some P` as `any P`. The subscripts PR adds a runtime test.
   - **Parameter packs: done on the branch.**
     - A pack argument is recorded as one `Cuckoo.ParameterPack`, whose `values` are the pack's values as `[Any]`. Tests match it with `anyPack()`, `equal(toPack: 1, "a")` for `Equatable` values, or a `ParameterMatcher` closure, and a `then` closure receives the `ParameterPack`.
     - The proxies leave out a pack that Swift couldn't infer from their signature. A stubbing proxy keeps a pack that the return type uses, so `when(stub.combine(anyPack())).thenReturn((1, "a"))` infers it from the stubbed value.
     - A class's methods with a pack aren't mocked and keep the real implementation, because Swift can't override them (Swift 6.2–6.4 report that the override overrides nothing). Protocols are unaffected.
     - Swift 6.2 rejects a non-Sendable argument to a synchronous actor-mock method ("sending ... risks causing data races"), and a `ParameterPack` is never Sendable; 6.3 accepts both. This predates packs. Fixtures 14 and 22 sit in `expected-failures-swift-6.2.txt`. Next: find out whether the actor-mock template can satisfy 6.2 without changing what 6.3 and later generate.
3. ☁️ `inout` stubbing (Brightify/Cuckoo#337), `Self` (Brightify/Cuckoo#304), generic init (Brightify/Cuckoo#362), class-constrained protocols (Brightify/Cuckoo#447, Brightify/Cuckoo#376), parent associated types (Brightify/Cuckoo#576).
   - 3b. ☁️ `~Copyable` arguments borrowed into `then` closures (L): needs `~Copyable` suppression through `MockManager`'s generics.
4. ☁️ `inOrder`, `within:` / `eventually`, `thenNeverReturn`, delayed returns, and closest-match failure diffs.
5. ☁️ Config options: prefix/suffix, regex array, `@_spi`.
6. ☁️ Import isolation in single-file output (M). A single generated file merges every source file's imports, so a name one import declares (e.g. `SwiftUI.Namespace`) makes same-named source types ambiguous in all mocks once they live outside the source module. The runtime tests work around it with a separate `CuckooSwiftUI` Cuckoofile module.
   - Fix: the generated file declares an alias for each top-level source type (`typealias Namespace = CuckooTestSources.Namespace`), with the mocks' access level. A module-level declaration beats imports, and mock bodies stay unchanged. Verified with swiftc.
   - Needs the Swift module of each source file: from the SwiftPM plugins, which know it, or a new Cuckoofile option. Without it, output stays as today.
   - Watch for: a module containing a type with its own name (`Foo.Foo`), where `Foo.Bar` resolves to the type, not the module; nested and generic types.
   - Fixtures: a SwiftUI-importing file next to a `Namespace` type, the module-named type, and sources from two modules in one output.
7. ☁️ Generic methods whose return type alone uses a non-primary associated type (`func convert<T>(value: T) -> Output` on `protocol P<Input>`). The type-erased default implementation returns `Any` where `Output` is expected, so the mock doesn't compile.

Exit criteria: all 18 matrix fixtures at 0 errors; new fixtures for every item above.

### Phase 5: Codegen rewrite, distribution, docs (L)
1. ☁️ Replace Stencil with a typed code writer, output formatted with `swift-format`. Snapshot tests guard against output drift.
2. 🍎 Prebuilt `artifactbundle` for the generator, released by GitHub Actions (replaces fastlane). Plugin consumers no longer compile swift-syntax.
3. ☁️ **Plugins pass their file lists to the generator (#524).** The plugins already compute each target's source files, including Xcode 16 synchronised folders, but only hand them to the build system as `inputFiles`; the generator still reads the Cuckoofile's `sources` globs. Add a `--sources-list <file>` option (one path per line), have each plugin write the files it computed and pass it, and use that list instead of `sources` (with `exclude` and `regex` still applied). Plugin users then need no `sources` at all, and target membership is exact again. Snapshot-test the option; the SwiftPM runtime suite covers it through `CuckooPluginModular`.
   - **Done first (2026-10-25):** the `xcodeproj` option and the XcodeProj dependency (with AEXML and xcode-project-format) are removed. A leftover `xcodeproj` table fails with a message giving the `sources` line to write; the README has a migration note. Until this item lands, that message doesn't mention the plugins, which still read `sources`.
4. ☁️ DocC documentation, a migration guide from 2.x, and a cookbook (MainActor view models, actors, Swift Testing).
   - The migration guide should mention that under `MemberImportVisibility` (on by default in Swift 7), a type relying on `ObservableObject`'s default `objectWillChange` needs `import Combine`: SwiftUI's re-export doesn't make Combine's extension members visible.
   - The README still documents CocoaPods, the `run` script and the 2.x platforms. The podspec, Gemfile and fastlane lane were removed in Phase 2 (D3); the `run` script goes with this rewrite.
5. ☁️ Optional `@Mockable` macro front-end that shares the model (§3.5).
6. 🍎 Bring the OCMock bridge (`OCMock/`, `OCMockWrapper/`, `Tests/OCMock/`) back as an opt-in SwiftPM product, e.g. `CuckooOCMock`:
   - Gate the OCMock dependency behind a **package trait** (SwiftPM traits, Swift 6.1+), so only consumers that enable `.traits(["OCMock"])` resolve and download it. If traits turn out not to fit, fall back to a small companion package.
   - Check that OCMock's own SwiftPM support works on current Xcode. Upstream removed the bridge from SwiftPM in 2.x ("Temporarily omit OCMock from SPM"), so find out why first.
   - Re-enable the commented-out OCMock targets in `Project.swift` and run `Tests/OCMock` in CI.
   - Update the API for Swift 6: `Sendable`-correct `objcStub`/`objcVerify`, MainActor-safe use with UIKit classes, and typed helpers to reduce the untyped `args[0] as! T` casts.
7. ☁️ One source of truth for the generator's dependencies: have the Tuist `Generator` project consume the root package instead of re-declaring its packages, so `Generator/Project.swift` can't drift from `Package.swift` (a 9.9.0 vs 9.14.0 XcodeProj pin broke CI in Phase 2), and drop its separate lockfile.
8. ☁️ Rebuild the type-erased default implementation (`DefaultImplCaller`) for generic protocols on a `Sendable` box instead of closures over an `UnsafeMutablePointer`, so it can drop its documented `@unchecked Sendable`. The pointer-based `enableDefaultImplementation(mutating:)` API needs rethinking with it; the non-mutating overload also points at a local copy.
9. ☁️ To discuss: drop Rainbow. The generator uses only its `.bold` (26 times, in log and error messages), which a ~10-line internal helper can replace, keeping its plain output when stdout isn't a terminal. Only `Generator.swift` imports Rainbow; `Module.swift` and `GenerateCommand.swift` see `.bold` through leaked extension members, which the upcoming `MemberImportVisibility` feature turns into errors. With Stencil gone too, the generator would depend only on swift-syntax, swift-argument-parser and TOMLDecoder.
10. 🍎 To decide: drop Tuist. Phase 2 item 0 kept it alongside SwiftPM until both agreed; they do (342/342). What only Tuist covers: the generator run over the whole Cuckoofile into one combined file (what `CuckooPluginSingleFile` and build-script users get, and the only place merged-import bugs like the SwiftUI `Namespace` clash show up), and an Xcode-project build with framework targets. If Tuist goes, replace the first with a SwiftPM test target using `CuckooPluginSingleFile`, or a matrix run into one file. Removing Tuist drops two macOS jobs per image, mise, the Makefile, `build_generator` and `Generator/Project.swift` with its separate lockfile, which makes item 7 moot. Size M.

### Phase 6: Release and upstreaming (S)
- 3.0.0-beta tags on the fork.
- Offer Brightify the independent fixes (#601, the swift-syntax range, the Linux Glob fix, `keepDocumentation`) as separate small PRs.
- Propose the 3.0 branch upstream, or publish under a new name (D1).

---

## 5. Decisions
- **D1 (decided 2026-10-22):** keep the name **Cuckoo**. 3.0 is a major version of the same package, developed in the fork and offered upstream.
- **D2 (decided 2026-10-22):** baseline **iOS 17 / macOS 14 / tvOS 17 / watchOS 10**, with newer compiler and OS versions unlocking extra features (§3.4). A higher floor isn't needed for fixture 17: projects annotate APIs like `any AsyncSequence<_, Never>` with `@available`, and Cuckoo propagates that.
- **D3 (decided 2026-10-22):** drop CocoaPods, the podspec and the `run` script. SwiftPM build-tool plugins plus a prebuilt generator binary are the only distribution.
- **D4 (decided 2026-10-22):** **keep the OCMock bridge** for mocking Objective-C third-party dependencies, which Cuckoo's Swift-only generator can't read. It moves from CocoaPods to SwiftPM as an opt-in product, so projects that don't use it never download OCMock (Phase 5, item 6).

## 6. Working remotely
- Cloud sessions run on Linux: no Xcode, no Apple simulators.
- Phase 0 exists so most work (generator, runtime, snapshots, matrix) is ☁️ and verifiable on Linux.
- Apple-only verification (Tuist test schemes, iOS simulator, TSan on Darwin) runs in GitHub Actions on `nmcc24/Cuckoo`. Push a branch, then read the workflow results with `gh run view`.

## Sources
- Swift 6.4 overview: https://www.avanderlee.com/concurrency/swift-6-4-whats-new-in-concurrency/ and https://www.infoq.com/news/2026/09/swift-6-4-released/
- Swift 6.3 release: https://swift.org/blog/swift-6.3-released/
- swift-mocking announcement: https://forums.swift.org/t/introducing-swift-mocking-a-testing-framework-based-on-parameter-packs/83463
- Upstream issues: https://github.com/Brightify/Cuckoo/issues
