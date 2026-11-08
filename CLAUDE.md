# CLAUDE.md

Guidance for Claude Code sessions working on this repository: the `nmcc24/Cuckoo` fork of `Brightify/Cuckoo`, being modernized into Cuckoo 3 for Swift 6.

## Start here
- Read `docs/SWIFT6_ROADMAP.md` first. It holds the plan, every decision so far (D1–D4) and the current phase's status. Update it when a phase's status or a decision changes.
- Decisions that stand:
  - D1: keep the name Cuckoo.
  - D2: minimum iOS 17 / macOS 14 / tvOS 17 / watchOS 10.
  - D3: drop CocoaPods and the `run` script.
  - D4 (reversed 2026-11-05): the OCMock bridge is removed.
- **Swift 6.2 is the minimum toolchain.** Don't add workarounds for Swift 6.1 or older.

## Working rules agreed with the maintainer
- **A failure on a single Xcode or Swift version: report it and discuss before changing anything.** Give the runner, toolchain, error, likely cause and options. The maintainer decides whether that version's drag is worth accepting. Fix failures that hit every version without waiting.
- **Don't push to a PR branch while its CI is running** unless the push is needed (e.g. a fix). Every push cancels the run in progress. Commit locally and batch the changes. Follow-ups planned for after a merge go on a local branch and are pushed with the next phase.
- **The PR description carries the full changelog,** one entry per commit with its hash. Update it on every push, and check every hash it cites against the branch.
- **Link this fork's PRs with full URLs** (`https://github.com/nmcc24/Cuckoo/pull/N`), in PR descriptions, comments and chat. Issues are disabled on the fork, so GitHub resolves a bare `#N` to `Brightify/Cuckoo`. Write upstream references explicitly, as `Brightify/Cuckoo#N`.
- **Estimates are relative sizes (S/M/L), never durations.** The roadmap's §4 key defines them.
- Small, logical commits.
- **Zero warnings, each fixed at its root.** Treat every warning in our own targets (Source/, Tests/, generated mocks) as a defect. Don't silence one with `@retroactive`, `@preconcurrency`, `nonisolated(unsafe)` or `@unchecked Sendable` unless that's the correct design; if the proper fix is large, put it on the roadmap.
- **Use the modern Swift APIs, not the Objective-C-era ones** (nmcc24, 2026-11-07). Swift `Regex`, standard-library string operations (`split`, `replacing`, `contains`, `firstRange(of:)`, `trimming` helpers) and `URL(filePath:)`/`appending(path:)`, never `NSRegularExpression`, `NSString`/`NSRange` bridging, `components(separatedBy:)`, `replacingOccurrences` or `CharacterSet` trimming. On Linux those link ICU's 44 MB data into the prebuilt generator. Keep `NSLock` (`Mutex` needs iOS 18) and `NSException` in the runtime, which are deliberate.

## Git and merge rules
- `master` is protected by the "Merge to master" ruleset:
  - a PR is required;
  - the `CI passed` check must pass, with the branch up to date with `master`;
  - rebase merging only;
  - signed commits required;
  - no force-pushes or deletion.
- `master` started from upstream `Brightify/Cuckoo` 2.4.0 (`7cef639`). Bring in later upstream changes through a PR that merges upstream `master`; never reset `master` again.
- After a PR merges, restart the working branch from the new `master` and carry over any unmerged local commits. Never stack new work on merged history.
- Never open PRs or push to `Brightify/Cuckoo` without asking.

## CI (`.github/workflows/test.yml`)
- **Triggers:** `pull_request`, `push` to `master` only, and `workflow_dispatch`. A PR runs once, and a new push cancels its run in progress; runs on `master` always finish. A branch without a PR gets CI only by hand (`workflow_dispatch`) or by opening a draft PR.
- **Linux:** `swift:6.2`, `6.3` (native build system) and `swift:6.4` (`swiftbuild`; SwiftPM 6.4 deprecates `native`), running `swift test` (generator and runtime tests) and the Swift 6 fixture matrix.
- **Swift 7 features (`swift7_linux`, Swift 6.2 and 6.4):** `swift test` with every upcoming feature on, and the fixture matrix with every feature on and as a new Xcode 26 project. Our targets already adopt the four that only change what compiles; `CUCKOO_UPCOMING_FEATURES=A,B` adds others to every target locally. New templates must pass both configurations (roadmap Phase 3.5).
- **Documentation (`docs_linux`, Swift 6.3):** `scripts/build-docs.sh` builds the runtime's DocC catalog (`Source/Cuckoo.docc`) from SwiftPM's symbol graph with the toolchain's `docc`, no package dependency, and fails on any docc warning. Document every new public symbol, and curate it on the catalog's landing page. The usage docs are the catalog's articles (the README is an overview); `CuckoofileTests.documentationExamples` parses every TOML example in `GettingStarted.md` and `Cuckoofile.md`, so update its counts when adding one.
- **Prebuilt generator (`bundle_linux`, Swift 6.3):** builds the generator's `artifactbundle` for Linux with `scripts/build-artifactbundle.sh` and runs `scripts/smoke-test-artifactbundle.sh`, which builds a small consumer package against it and fails if swift-syntax got compiled. The `Release` workflow (`.github/workflows/release.yml`, run by hand on master) builds the macOS and Linux parts, tags a commit off master that sets `prebuiltGenerator` in `Package.swift`, and publishes the release; master always builds the generator from source.
- **Linux TSan:** `swift test --sanitize=thread --filter CuckooTests` on `swift:6.3`, run through `docker run` on the host runner (it lowers `vm.mmap_rnd_bits` first, which a container job can't). `Tests/Swift/ConcurrencyStressTest.swift` holds the stress tests it's there for.
- **Dependency requirements:** up to the next major release for 1.x+ packages, up to the next minor for 0.x ones, in `Package.swift`. `Package.resolved` is the only lockfile, and Dependabot (`.github/dependabot.yml`) updates it. Its `originHash` is derived from the manifest: after changing `Package.swift`, run `swift package resolve` and commit the new hash. On Linux, `swift package resolve` in an empty directory holding only `Package.swift` gives it too.
- **swift-syntax range `602.0.0..<605.0.0`.** `Package.resolved` pins the newest release, and Linux jobs pin the first release of every older major (602.0.0 on Swift 6.2, 603.0.0 on 6.3); add one when the upper bound rises. The floor is the Swift 6.2 release (raised from 600 on 2026-11-06): the generator parses its own output, and 600 and 601 can't parse syntax the mocks use, such as `nonisolated(nonsending)`. Keep it as low as that allows, so Cuckoo resolves alongside macro packages that pin older releases. Put newer swift-syntax APIs behind `#if canImport(SwiftSyntax60x)`.
- **macOS:** `macos-26` (Xcode 26.6, Swift 6.3) and `xcode-27` (Xcode 27, Swift 6.4), running the SwiftPM jobs (each with its image's default build system), the package's runtime tests on the iOS simulator plus a build-for-testing for tvOS and watchOS (Xcode 26.6 also builds the generator's dependencies for the destination, so they must all build for tvOS and watchOS), in one job per image. Keep the macOS job count low: those runners are the slowest to queue. `macos-15` isn't used; its default Swift 6.1 is below the minimum.
- **Use each image's default Xcode.** Picking the newest installed one has selected a beta before.
- **Linux jobs pin `ubuntu-24.04`,** not `ubuntu-latest`, which GitHub moves to Ubuntu 26 from 2026-10-19. The TSan job runs `docker run` on the host and lowers `vm.mmap_rnd_bits`, so a new host image is a deliberate change, tried in its own PR: roadmap Phase 5 item 12 moves them back to `ubuntu-latest` once it serves Ubuntu 26.
- **`CI passed` is the single required check.** Any new job must be added to its `needs:` list, or the merge gate won't wait for it. It also reads the run's job list and fails on any leg that didn't succeed, because `needs` reports a matrix job as successful even when some of its legs were cancelled (a macOS leg that never got a runner, for example).

## Local dev loop (works on Linux)
- `swift test`: generator unit and snapshot tests (`Generator/Tests`), plus the runtime tests (`CuckooTests`), on Linux too. The runtime tests use Swift Testing, except `IsolationXCTest` and the Apple-only `XCTestFailureTest`, which keep the XCTest route covered; write new tests in Swift Testing. Add `--build-system native` or `--build-system swiftbuild` to pick the build layout.
- `CUCKOO_RECORD_SNAPSHOTS=1 swift test`: re-record the snapshots in `Generator/Tests/Snapshots/`, then review the diff before committing. A missing snapshot is written and fails the test on purpose.
- `scripts/build-docs.sh`: builds the documentation into `.build/docs/Cuckoo.doccarchive`, failing on any docc warning. A link to an overloaded symbol needs docc's disambiguation suffix, such as ``` ``stub(_:block:)-(M,_)`` ```; the warning suggests it.
- `scripts/swift6-matrix.sh`: generates mocks for `Fixtures/Swift6/*` and compiles each to SIL in Swift 6 mode. Plain `-typecheck` misses region-isolation ("sending ... risks causing data races") errors. `SWIFT_BUILD_FLAGS` picks the build system, and extra arguments go to `swiftc` (e.g. `-D DEBUG`).
  - Fixtures listed in `Fixtures/Swift6/expected-failures.txt` are expected to fail. `expected-failures-swift-X.Y.txt` adds the ones that fail only on Swift X.Y, in every mode; delete it when that version's support ends.
  - The script fails on a new failure or on a listed fixture that now passes. Remove a fixture from the list once its fixture passes.
- No Swift toolchain on the cloud VM: use the official `swift:6.x` Docker images (start `dockerd` if it isn't running). Docker Hub rate-limits the VM, so pull `mirror.gcr.io/library/swift:6.x`. For SwiftPM to fetch packages inside the container, mount the proxy CA bundle and pass the proxy variables (`HTTPS_PROXY`, `GIT_SSL_CAINFO`, `SSL_CERT_FILE`).
- Runtime test layout (Tuist was dropped in Phase 5; SwiftPM is the only build):
  - `Tests/Swift/Source` builds as `CuckooTestSources`, the way a user's app code does. `CuckooMocks` holds only the generated mocks and imports it with `@testable`. All targets build in Swift 6 mode and share the package name `Cuckoo`.
  - SwiftPM generates the mocks with `CuckooPluginModular`: one file per dependency of `CuckooMocks`, from the `Cuckoofile.toml` module of the same name. Keep those module names equal to the target names. `CuckooPluginSingleFile` generates every module into one file for `CuckooSingleFileMocks`, which `CuckooSingleFileTests` (`Tests/SingleFile`) compiles: the only place merged-import bugs, like the SwiftUI `Namespace` clash, show up. `CuckooPluginTestSources` (`Tests/Plugin`) has a Cuckoofile module without `sources`, covering `--sources-list`.
  - To run the package's tests with `xcodebuild`, use the shared `CuckooTests` scheme (`.swiftpm/xcode/xcshareddata/xcschemes/`) with `-skipPackagePluginValidation`. `Cuckoo-Package` would also build the generator and its tests for the destination, which the runtime tests don't need. The scheme runs `CuckooTests` and `CuckooSingleFileTests`.
  - Apple-only fixtures and tests sit inside `#if canImport(ObjectiveC)` or `#if canImport(SwiftUI)`, which the generator mirrors into the mocks.
  - `Cuckoofile.toml` names the sources' Swift module (`sources = { CuckooTestSources = [...] }`), so the mocks import each source type by name and SwiftUI's `Namespace` doesn't clash with the fixture's.
- **The maintainer's Mac runs the Apple checks.** When a Remote Control session to it is available, run macOS `swift test` and the `CuckooTests` scheme on an iOS simulator there before pushing changes that touch the runtime, the tests, the plugins or the generator. CI stays the final gate.
  - The Linux checks run there too, in Docker (`swift:6.2`, `6.3`, `6.4`): `swift test` and the fixture matrix, with the features off, all on, and Xcode 26 defaults. Use the cloud VM's Docker only when the Mac is offline.
  - On the Mac's arm64 Docker, multi-core XCTest runs hang at random (a swift-corelibs run-loop race; a plain package without Cuckoo hangs too). Build with all cores, then run the tests on one: `swift build --build-tests …`, then `taskset -c 0 swift test --skip-build …` under `timeout 300`, retrying on a timeout (exit 124). Pinning makes the hang rare, not impossible, and a hang there is that race, not a test failure. Run containers detached (`docker run -d`) under `caffeinate`.

## Cloud environment notes
- The GitHub proxy blocks some writes, such as deleting branches (`git push --delete` and the REST `DELETE` both fail). Ask the maintainer to do those in the GitHub UI.
- Hosted macOS runners can queue for a long time (arm64 capacity). Read CI results through notice annotations (`gh api .../check-runs/<id>/annotations`) or the GitHub MCP job-log tool. Raw log downloads are blocked.
