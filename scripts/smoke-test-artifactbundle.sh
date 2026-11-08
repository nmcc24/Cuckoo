#!/usr/bin/env bash
# Tests a prebuilt generator `artifactbundle` the way a user gets it (roadmap Phase 5 item 2): a small package
# depends on a copy of this one whose plugins run the bundle, generates mocks with CuckooPlugin and runs a
# test that stubs and verifies one. It fails if the build compiled swift-syntax, which the bundle is there to
# avoid. (SwiftPM may still check swift-syntax out to resolve versions; it doesn't build it.)
#
#   scripts/smoke-test-artifactbundle.sh <CuckooGenerator.artifactbundle>
#   scripts/smoke-test-artifactbundle.sh --tag <version>
#
# With --tag, the package depends on the released tag of this repository instead (GITHUB_REPOSITORY, by default
# nmcc24/Cuckoo), whose commit names the bundle attached to the release.
#
# SWIFT_BUILD_FLAGS adds flags to `swift test`, such as `--build-system native`.
set -euo pipefail

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [[ "${1:-}" == --tag ]]; then
    [[ $# -eq 2 ]] || { echo "usage: $0 <bundle> | --tag <version>" >&2; exit 2; }
    dependency=".package(url: \"https://github.com/${GITHUB_REPOSITORY:-nmcc24/Cuckoo}.git\", exact: \"$2\")"
else
    [[ $# -eq 1 ]] || { echo "usage: $0 <bundle> | --tag <version>" >&2; exit 2; }
    bundle="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    repo="$(cd "$(dirname "$0")/.." && pwd)"
    # The package as committed plus the working tree's changes, without build products.
    mkdir "$work/Cuckoo"
    # A CI container's checkout belongs to another user, which git refuses unless the directory is marked safe.
    git -c safe.directory="$repo" -C "$repo" ls-files -z --cached --others --exclude-standard > "$work/files"
    [[ -s "$work/files" ]] || { echo "No files listed in $repo" >&2; exit 1; }
    (cd "$repo" && tar -cf - --null -T "$work/files") | tar -xf - -C "$work/Cuckoo"
    cp -R "$bundle" "$work/Cuckoo/CuckooGenerator.artifactbundle"
    "$work/Cuckoo/scripts/set-prebuilt-generator.sh" local CuckooGenerator.artifactbundle
    dependency='.package(path: "../Cuckoo")'
fi

consumer="$work/Consumer"
mkdir -p "$consumer/Sources/App" "$consumer/Tests/AppTests"
cat > "$consumer/Package.swift" <<SWIFT
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Consumer",
    platforms: [.macOS("14.0")],
    dependencies: [$dependency],
    targets: [
        .target(name: "App"),
        .testTarget(
            name: "AppTests",
            dependencies: ["App", .product(name: "Cuckoo", package: "Cuckoo")],
            plugins: [.plugin(name: "CuckooPlugin", package: "Cuckoo")]
        ),
    ]
)
SWIFT
cat > "$consumer/Cuckoofile.toml" <<'TOML'
[modules.App]
testableImports = ["App"]
TOML
cat > "$consumer/Sources/App/Greeter.swift" <<'SWIFT'
protocol Greeter {
    func greet(name: String) -> String
}

struct WelcomeScreen {
    let greeter: any Greeter

    var title: String { greeter.greet(name: "Ann") }
}
SWIFT
cat > "$consumer/Tests/AppTests/WelcomeScreenTests.swift" <<'SWIFT'
import Cuckoo
import Testing
@testable import App

@Test(.cuckoo())
func welcomesTheUser() {
    let greeter = MockGreeter()
    stub(greeter) { stub in
        when(stub.greet(name: any())).thenReturn("Hello")
    }

    #expect(WelcomeScreen(greeter: greeter).title == "Hello")
    verify(greeter).greet(name: "Ann")
}
SWIFT

cd "$consumer"
# shellcheck disable=SC2086 # SWIFT_BUILD_FLAGS holds several flags.
swift test ${SWIFT_BUILD_FLAGS:-}
# SwiftPM on macOS also downloads swift-syntax's prebuilt macro support into .build/prebuilts, since swift-syntax
# stays in the package graph; that's a download, not a build.
if [[ -n "$(find .build -path .build/prebuilts -prune -o -name 'SwiftSyntax.swiftmodule' -print -quit)" ]]; then
    echo "The build compiled swift-syntax, so the plugins didn't use the prebuilt generator." >&2
    exit 1
fi
echo "The prebuilt generator works, and swift-syntax wasn't built."
