#!/usr/bin/env bash
# Installs the CuckooTests scheme, which runs the runtime tests (`CuckooTests` and `CuckooSingleFileTests`) with
# `xcodebuild` without building the generator and its tests for the destination, as `Cuckoo-Package` would.
#
#   scripts/install-scheme.sh
#   xcodebuild test -scheme CuckooTests -skipPackagePluginValidation -destination ...
#
# It lives here rather than in `.swiftpm/xcode/xcshareddata/xcschemes/`, because Xcode lists a package's shared
# schemes in every project that depends on it, where this one has nothing to build. The installed copy is ignored.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$repo/.swiftpm/xcode/xcshareddata/xcschemes"
cp "$repo/scripts/CuckooTests.xcscheme" "$repo/.swiftpm/xcode/xcshareddata/xcschemes/CuckooTests.xcscheme"
