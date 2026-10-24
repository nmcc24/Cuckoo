# CLAUDE.md

Guidance for Claude Code sessions working on this repository: the `nmcc24/Cuckoo` fork of `Brightify/Cuckoo`, being modernized into Cuckoo 3 for Swift 6.

## Start here
- Read `docs/SWIFT6_ROADMAP.md` first. It holds the plan, every decision so far (D1–D4) and the current phase's status. Update it when a phase's status or a decision changes.
- Decisions that stand:
  - D1: keep the name Cuckoo.
  - D2: minimum iOS 17 / macOS 14 / tvOS 17 / watchOS 10.
  - D3: drop CocoaPods and the `run` script.
  - D4: the OCMock bridge becomes an opt-in SwiftPM product behind a package trait.
- **Swift 6.2 is the minimum toolchain.** Don't add workarounds for Swift 6.1 or older.

## Working rules agreed with the maintainer
- **A failure on a single Xcode or Swift version: report it and discuss before changing anything.** Give the runner, toolchain, error, likely cause and options. The maintainer decides whether that version's drag is worth accepting. Fix failures that hit every version without waiting.
- **Don't push to a PR branch while its CI is running** unless the push is needed (e.g. a fix). Every push cancels the run in progress. Commit locally and batch the changes. Follow-ups planned for after a merge go on a local branch and are pushed with the next phase.
- **The PR description carries the full changelog,** one entry per commit with its hash. Update it on every push, and check every hash it cites against the branch.
- **Link this fork's PRs with full URLs** (`https://github.com/nmcc24/Cuckoo/pull/N`), in PR descriptions, comments and chat. Issues are disabled on the fork, so GitHub resolves a bare `#N` to `Brightify/Cuckoo`. Write upstream references explicitly, as `Brightify/Cuckoo#N`.
- **Estimates are relative sizes (S/M/L), never durations.** The roadmap's §4 key defines them.
- Small, logical commits.
- **Zero warnings, each fixed at its root.** Treat every warning in our own targets (Source/, Tests/, generated mocks) as a defect. Don't silence one with `@retroactive`, `@preconcurrency`, `nonisolated(unsafe)` or `@unchecked Sendable` unless that's the correct design; if the proper fix is large, put it on the roadmap.

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
- **Linux:** `swift:6.2`, `6.3` (native build system) and `swift:6.4` (`swiftbuild`; SwiftPM 6.4 deprecates `native`), running generator tests and the Swift 6 fixture matrix.
- **swift-syntax range `600.0.0..<605.0.0`.** `Package.resolved` pins the newest release, and one Linux Swift 6.2 job pins 600.0.0. The floor stays low so Cuckoo resolves alongside macro packages that pin older releases. Put newer swift-syntax APIs behind `#if canImport(SwiftSyntax60x)`.
- **macOS:** `macos-26` (Xcode 26.6, Swift 6.3) and `xcode-27` (Xcode 27, Swift 6.4), running the generator jobs (each with its image's default build system) plus the Tuist macOS and iOS test schemes. Keep the macOS job count low: those runners are the slowest to queue. `macos-15` isn't used; its default Swift 6.1 is below the minimum.
- **Use each image's default Xcode.** Picking the newest installed one has selected a beta before.
- **`CI passed` is the single required check.** Any new job must be added to its `needs:` list, or the merge gate won't wait for it.

## Local dev loop (works on Linux)
- `swift test`: generator unit and snapshot tests (`Generator/Tests`), plus the 342 runtime tests (`CuckooTests`), on Linux too. Add `--build-system native` or `--build-system swiftbuild` to pick the build layout.
- `CUCKOO_RECORD_SNAPSHOTS=1 swift test`: re-record the snapshots in `Generator/Tests/Snapshots/`, then review the diff before committing. A missing snapshot is written and fails the test on purpose.
- `scripts/swift6-matrix.sh`: generates mocks for `Fixtures/Swift6/*` and compiles each to SIL in Swift 6 mode. Plain `-typecheck` misses region-isolation ("sending ... risks causing data races") errors. `SWIFT_BUILD_FLAGS` picks the build system, and extra arguments go to `swiftc` (e.g. `-D DEBUG`).
  - Fixtures listed in `Fixtures/Swift6/expected-failures.txt` are expected to fail.
  - The script fails on a new failure or on a listed fixture that now passes. Remove a fixture from the list once its fixture passes.
- No Swift toolchain on the cloud VM: use the official `swift:6.x` Docker images (start `dockerd` if it isn't running). Docker Hub rate-limits the VM, so pull `mirror.gcr.io/library/swift:6.x`. For SwiftPM to fetch packages inside the container, mount the proxy CA bundle and pass the proxy variables (`HTTPS_PROXY`, `GIT_SSL_CAINFO`, `SSL_CERT_FILE`).
- The 342 runtime tests also run through Tuist on macOS: `make`, then `xcodebuild test -scheme Cuckoo-macOS -workspace Cuckoo.xcworkspace`. Roadmap Phase 2 item 0 keeps Tuist in parallel with SwiftPM until both agree.
  - Layout, the same in both: `Tests/Swift/Source` builds as `CuckooTestSources`, the way a user's app code does. `CuckooMocks` holds only the generated mocks and imports it with `@testable`. All targets build in Swift 6 mode and share the package name `Cuckoo`.
  - SwiftPM generates the mocks with `CuckooPluginModular`: one file per dependency of `CuckooMocks`, from the `Cuckoofile.toml` module of the same name. Keep those module names equal to the target names. Tuist runs the generator over the whole `Cuckoofile.toml` into `Tests/Swift/Generated/`.
  - Apple-only fixtures and tests sit inside `#if canImport(ObjectiveC)` or `#if canImport(SwiftUI)`, which the generator mirrors into the mocks.
  - The SwiftUI fixture lives in `Tests/Swift/Source/SwiftUI/` as its own module, `CuckooTestSourcesSwiftUI`, with its own Cuckoofile module, because a single generated file shares one import list (roadmap Phase 4 item 6).
  - Delete `Tests/Swift/Generated/*.swift` before a fresh `make`, so stale mocks aren't compiled.
- **The maintainer's Mac can run the Tuist tests.** When a Remote Control session to it is available, run the macOS and iOS schemes there before pushing changes that touch the runtime, the tests or Tuist. CI stays the final gate.

## Cloud environment notes
- The GitHub proxy blocks some writes, such as deleting branches (`git push --delete` and the REST `DELETE` both fail). Ask the maintainer to do those in the GitHub UI.
- Hosted macOS runners can queue for a long time (arm64 capacity). Read CI results through notice annotations (`gh api .../check-runs/<id>/annotations`) or the GitHub MCP job-log tool. Raw log downloads are blocked.
