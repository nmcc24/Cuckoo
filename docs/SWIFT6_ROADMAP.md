# Cuckoo for Swift 6: analysis and roadmap

Status: draft, 2026-10-22. Branch `nmcc24/swift6-roadmap` on `nmcc24/Cuckoo` (fork of `Brightify/Cuckoo` at `7cef639`, v2.4.0).

Goal: make Cuckoo (or a successor) fully Swift 6 compliant on Swift 6.2–6.4, able to mock `@MainActor`, global-actor and `Actor` protocols, and broaden what can be mocked. Swift 5 language mode support is dropped.

---

## 1. Where things stand (measured, not guessed)

Toolchain used: Xcode 27.1, Swift 6.4 (`swiftlang-6.4.0.34.1`), macOS 27 SDK.

### 1.1 Existing test suite
- `xcodebuild test -scheme Cuckoo-macOS` passes all **342 tests**, but only with `MACOSX_DEPLOYMENT_TARGET=12.0`. Xcode 27 rejects the project's 10.15 deployment target (minimum is 12.0).
- `swift test` doesn't work. The test target needs the Tuist-generated `CuckooMocks` framework and OCMock, so only the Tuist workspace can run tests.
- The generator has **one** unit test (`OrderedSetTest`). It has no golden-file or snapshot tests.

### 1.2 Swift 6 feature matrix
Run `scripts/swift6-matrix.sh` to reproduce. It generates mocks for each file in `Fixtures/Swift6/` and typechecks the result with `-swift-version 6`.

| Fixture | Errors | Root cause |
|---|---|---|
| 01 `@MainActor protocol` | 4 | Mock conforms to `Cuckoo.Mock`, `HasMockManager` (nonisolated requirements) while inheriting MainActor isolation → `#ConformanceIsolation` |
| 02 `protocol P: Actor` | 12 | Generator always emits `class`; actors need `actor`. Also emits `XStub` as class. |
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
| 17 `AsyncSequence<Int, Never>` | 2 | Availability not propagated (`Failure` needs macOS 15) |
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
- **Parser is outdated:** pinned to swift-syntax **601.0.1** (the Swift 6.1 grammar), and the allowed range `600.1.0..<603.0.0` excludes 603 (Swift 6.3) and 604 (Swift 6.4). Upstream #596.
- **Attributes are discarded:** only `@available` is kept (`Crawler.attribute(from:)`). Isolation attributes (`@MainActor`, custom global actors, `nonisolated`, `nonisolated(nonsending)`, `@concurrent`), `@objc`, `@_spi` and `@preconcurrency` are all lost.
- **Container kinds are hard-coded:** the templates always emit `class` (`MockTemplate`, `NopImplStubTemplate`).
- **`#if` is ignored:** both branches are parsed, which produces duplicates. Upstream #471.
- **Unknown property types crash:** a stored property whose type can't be inferred hits `fatalError` and aborts the whole run.
- **Documented options that don't work:**
  - `keepDocumentation` is parsed but never read;
  - `StubbingProxyTemplate` uses `method.isThrowing` inside the property loop (dead code).
- **Version mismatch:** `Version.swift` is stuck at `2.0.10`. The release lane writes it but never commits it, so the `run` script rebuilds the generator on every build. Upstream #601.
- **Glob is macOS-only:** `Glob` uses `glob_t.gl_matchc`, so the generator doesn't build on Linux. This also blocks working on it from Linux cloud sessions.
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
- Minimum OS: iOS 16, macOS 13, tvOS 16, watchOS 9 (primary associated types, `any P<T>`). Decision **D2**.
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
   - A Swift Testing trait sets it per test or suite: `@Suite(.cuckoo(strictness: .lenient, defaults: …))`.
4. **Failure routing.** Failures go to `Issue.record` when `Test.current != nil`, otherwise `XCTFail`, never both. Source locations are preserved.
5. **Unstubbed-call policy is configurable.**
   - `.strict` (default) records an issue, then returns a registered default value, or throws `CuckooError.unstubbed` for throwing members. It crashes only when no value can be produced.
   - `.lenient` returns defaults silently.
   - `.crash` is the legacy behaviour.
   - Result: tests no longer take down the whole process.
6. **Stub closures match the mock's isolation.**
   - Nonisolated mocks use `@Sendable` closures.
   - `@MainActor` and global-actor mocks generate proxies whose `then` closures are `@MainActor` (or that actor) and non-`Sendable`, so tests can capture view models freely.
   - Actor mocks use `@Sendable` closures that receive `isolated MockX`.
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
| `protocol P` | `final class MockP: P, Cuckoo.ProtocolMock, Sendable` (truly `Sendable` now) |
| `@MainActor protocol P` | `@MainActor final class MockP: P, Cuckoo.ProtocolMock` with `nonisolated let cuckoo_manager`; proxies `@MainActor` |
| `@SomeGlobalActor protocol P` | same as above with that actor |
| `protocol P: Actor` | `actor MockP: P, Cuckoo.ActorMock` with `nonisolated let cuckoo_manager`. Sync requirements are actor-isolated and record synchronously; default implementations are supported for async requirements only (documented). |
| `nonisolated func` in an isolated protocol | `nonisolated func` in the mock |
| `@MainActor func` in a plain protocol | member-level `@MainActor` preserved |
| `nonisolated(nonsending)` / `@concurrent` / `sending` / `isolated` | preserved on the mock signature; stripped from matcher, tuple and generic positions |
| `@MainActor class C` | `@MainActor class MockC: C, Cuckoo.ClassMock` |
| `some P` parameter | mock keeps `some P`; proxies take `M: Matchable` with `MatchedType == any P` |
| `each T` parameter packs | recorded as a type-erased `[Any]` with pack-aware matchers (`any()`, custom predicate) |
| `~Copyable` / `consuming` / `borrowing` | call recorded with a placeholder; parameter matchable only with `any()` or a `borrowing` predicate closure |
| `subscript` | `subscript` mocks with `stub.subscript(key).get/.set` and verify equivalents |
| `static` / `class` members | supported through a per-type static manager that is task-local and reset per test (#521) |
| `@available`, `#if` | availability propagated to every generated member; `#if` mirrored into the output, not evaluated |

### 3.3 Generator
- Move to swift-syntax `600.1.0..<605.0.0` and follow pointfree's "flexible dependence" guidance. Use the SwiftPM swift-syntax prebuilts to cut build time.
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
- **Xcode projects:** support `PBXFileSystemSynchronizedRootGroup` (#524), or drop XcodeProj in favour of plugin-provided file lists.
- **Linux:** make the generator build there (`gl_pathc` instead of `gl_matchc`, `FileManager`-based globbing).
- **Distribution:** ship the generator as a prebuilt `artifactbundle` `binaryTarget`, so consumers stop compiling swift-syntax. Fix `Version.swift` (#601) by generating it at build time from a single source of truth.
- **Performance:** cache crawl results by file content hash in the plugin work directory, and emit one file per input when requested.

### 3.4 Optional macro front-end (Phase 5)
- A `@Mockable` attached macro that reuses the same token model and code writer. It gives zero-config mocks for first-party protocols that opt in.
- The build plugin stays for third-party and unannotated types. Both produce identical APIs.

---

## 4. Phased plan

Legend: ☁️ can be done entirely in a Linux cloud session (code plus Linux build/tests); 🍎 needs macOS, so it's validated through GitHub Actions on the fork (push a branch, read CI).

### Phase 0: Foundations and dev loop (≈1 week)
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

### Phase 1: Parser and syntax modernization (≈1 week)
1. ☁️ swift-syntax range `600.1.0..<605.0.0`, CI-tested at both ends. Replace deprecated API uses.
2. ☁️ Attribute and specifier model:
   - isolation, `sending`, `isolated`, `nonisolated(nonsending)`, `@concurrent`, `consuming`, `borrowing`, `inout`, `some`;
   - strip correctly from matcher, tuple and generic positions (fixtures 07, 09, 10, 11).
3. ☁️ Mirror `#if` into the output (#471). Propagate `@available` (fixture 17, #599).
4. ☁️ Replace the crawler's `fatalError`s with diagnostics.

Exit criteria: fixtures 07, 09, 10, 11 and 17 typecheck, with snapshot tests for each.

### Phase 2: Concurrency-correct runtime (≈2 weeks)
1. ☁️ `Sendable` `MockManager` with `Locked<State>`, `nonisolated` protocol requirements, honest `Sendable` mocks (drop `@unchecked`).
2. ☁️ TaskLocal configuration, the Swift Testing trait, failure routing, and the unstubbed-call policy.
3. ☁️ Stress tests: 1,000 concurrent calls, stubs and verifications on one mock, run under TSan in CI (🍎 for TSan on Apple platforms; ☁️ TSan on Linux).
4. 🍎 Run the existing 342 tests under the new runtime and fix the regressions.

Exit criteria: no `nonisolated(unsafe)` or `@unchecked Sendable` left in `Source/` except the documented lock box; TSan clean; all legacy tests green.

### Phase 3: Isolation-aware code generation (≈2 weeks)
1. ☁️ `@MainActor` and global-actor protocols and classes (fixtures 01, 03, 04, 06), with isolation-matching stubbing and verification proxies.
2. ☁️ `Actor` protocols, generating `actor` mocks and stubs (fixture 02, #457).
3. ☁️ Member-level isolation and `nonisolated` pass-through.
4. ☁️ The `-default-isolation MainActor` mode: generate explicit `nonisolated` where needed so mocks stay usable from nonisolated tests, and add a fixture variant for it.
5. 🍎 Behavioural tests in the Tuist suite: stubbing, verifying and spying on MainActor and actor mocks from Swift Testing and XCTest.

Exit criteria: fixtures 01–06 typecheck and have behavioural tests; also typecheck in default-MainActor mode.

### Phase 4: Coverage expansion (≈2–3 weeks)
1. ☁️ Subscripts (12) and static/class members (13, #521).
2. ☁️ Opaque parameters (11, #470), parameter packs (14) and `~Copyable` parameters (15).
3. ☁️ `inout` stubbing (#337), `Self` (#304), generic init (#362), class-constrained protocols (#447/#376), parent associated types (#576).
4. ☁️ `inOrder`, `within:` / `eventually`, `thenNeverReturn`, delayed returns, and closest-match failure diffs.
5. ☁️ Config options: prefix/suffix, regex array, `@_spi`.

Exit criteria: all 18 matrix fixtures at 0 errors; new fixtures for every item above.

### Phase 5: Codegen rewrite, distribution, docs (≈2–3 weeks)
1. ☁️ Replace Stencil with a typed code writer, output formatted with `swift-format`. Snapshot tests guard against output drift.
2. 🍎 Prebuilt `artifactbundle` for the generator, released by GitHub Actions (replaces fastlane). Plugin consumers no longer compile swift-syntax.
3. ☁️ Synchronized-group Xcode project support (#524), or a documented plugin-only path.
4. ☁️ DocC documentation, a migration guide from 2.x, and a cookbook (MainActor view models, actors, Swift Testing).
5. ☁️ Optional `@Mockable` macro front-end that shares the model (§3.4).

### Phase 6: Release and upstreaming
- 3.0.0-beta tags on the fork.
- Offer Brightify the independent fixes (#601, the swift-syntax range, the Linux Glob fix, `keepDocumentation`) as separate small PRs.
- Propose the 3.0 branch upstream, or publish under a new name (D1).

---

## 5. Decisions needed from you
- **D1:** Stay "Cuckoo 3" in the fork and offer it upstream, or publish under a new package name?
- **D2:** Minimum OS: iOS 16 / macOS 13 (recommended), or iOS 17 / macOS 14 to simplify further?
- **D3:** Drop CocoaPods and the `run` script entirely (recommended)?
- **D4:** OCMock bridge: separate optional package, or drop?

## 6. Working remotely
- Cloud sessions run on Linux: no Xcode, no Apple simulators.
- Phase 0 exists so most work (generator, runtime, snapshots, matrix) is ☁️ and verifiable on Linux.
- Apple-only verification (Tuist test schemes, iOS simulator, TSan on Darwin) runs in GitHub Actions on `nmcc24/Cuckoo`. Push a branch, then read the workflow results with `gh run view`.

## Sources
- Swift 6.4 overview: https://www.avanderlee.com/concurrency/swift-6-4-whats-new-in-concurrency/ and https://www.infoq.com/news/2026/09/swift-6-4-released/
- Swift 6.3 release: https://swift.org/blog/swift-6.3-released/
- swift-mocking announcement: https://forums.swift.org/t/introducing-swift-mocking-a-testing-framework-based-on-parameter-packs/83463
- Upstream issues: https://github.com/Brightify/Cuckoo/issues
