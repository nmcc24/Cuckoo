#!/usr/bin/env bash
# Checks that the sources are ready to release a version: Generator/Sources/CLI/Version.swift holds it, Getting
# Started installs it (exactly, for a pre-release, since a range never picks one; with `from:` for a release, which leaves no pre-release
# pin behind), and CHANGELOG.md has its section. With no argument it checks the version Version.swift holds.
#
# CI runs it on every pull request, so a version bump that misses one of them fails there, not in the Release
# workflow, which runs it before it builds anything.
#
#   scripts/check-version.sh [<version>]
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then echo "::error::$1"; else echo "error: $1" >&2; fi
  exit 1
}

[[ $# -le 1 ]] || { echo "usage: $0 [<version>]" >&2; exit 2; }
version_file=Generator/Sources/CLI/Version.swift
# An empty argument, such as a release run's empty input, is checked as given, and fails.
if [[ $# -eq 1 ]]; then version=$1; else version="$(sed -nE 's/^let version = "(.*)"$/\1/p' "$version_file")"; fi

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || fail "Not a version: $version"
grep -qxF "let version = \"$version\"" "$version_file" || fail "$version_file doesn't hold $version."
guide=Source/Cuckoo.docc/GettingStarted.md
if [[ "$version" == *-* ]]; then
  grep -qF "exact: \"$version\"" "$guide" || fail "$guide doesn't install $version."
elif grep -qE 'exact: "[0-9]+\.[0-9]+\.[0-9]+-' "$guide"; then
  fail "$guide still installs a pre-release."
else
  grep -qE "\.package\(url: .*, from: \"$version\"\)" "$guide" || fail "$guide doesn't install $version with from:."
fi
scripts/release-notes.sh "$version" >/dev/null || fail "CHANGELOG.md has no section '## $version'."
