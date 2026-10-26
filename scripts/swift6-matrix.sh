#!/usr/bin/env bash
# Generates mocks for every fixture in Fixtures/Swift6 and compiles each fixture + its
# mock to SIL in Swift 6 language mode. Prints one line per fixture. SIL, not -typecheck,
# because region-based isolation errors ("sending ... risks causing data races") are
# only diagnosed on SIL.
#
# Usage: scripts/swift6-matrix.sh [extra swiftc flags, e.g. -default-isolation MainActor]
# Fixtures listed in Fixtures/Swift6/expected-failures.txt are expected to fail. SWIFT6_MATRIX_EXPECTED
# names another list, e.g. Fixtures/Swift6/expected-failures-default-mainactor.txt for that mode.
# Fixtures/Swift6/expected-failures-swift-X.Y.txt adds the fixtures that fail only on Swift X.Y, in every mode.
# Exit code: 0 if every fixture behaves as expected, 1 on a new failure or an
# expected failure that now passes (remove it from the list), 2 if the build fails.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${SWIFT6_MATRIX_WORK:-$ROOT/.build/swift6-matrix}"
mkdir -p "$WORK/gen" "$WORK/logs"

for args in "--product CuckooGenerator" "--target Cuckoo"; do
  # shellcheck disable=SC2086
  if ! swift build --package-path "$ROOT" ${SWIFT_BUILD_FLAGS:-} $args > "$WORK/logs/build.log" 2>&1; then
    cat "$WORK/logs/build.log"
    exit 2
  fi
done
BIN="$(swift build --package-path "$ROOT" ${SWIFT_BUILD_FLAGS:-} --show-bin-path)"
GEN="$BIN/CuckooGenerator"

# Module search paths differ between build systems. Search only the directory holding
# Cuckoo.swiftmodule: the native build system also keeps every target's module map under
# $BIN, and duplicates (CTOML and CTOML-tool) fail with "redefinition of module".
MOD_DIR="$(find "$BIN" -maxdepth 2 -name Cuckoo.swiftmodule -print -quit)"
if [[ -n "$MOD_DIR" ]]; then
  MOD_FLAGS=(-I "$(dirname "$MOD_DIR")" -F "$BIN")
else
  MOD_FLAGS=(-I "$BIN" -I "$BIN/Modules" -F "$BIN")
fi
if [[ -d "$ROOT/.build/out/Products/Debug" ]]; then
  MOD_FLAGS+=(-I "$ROOT/.build/out/Products/Debug" -F "$ROOT/.build/out/Products/Debug")
fi
if command -v xcrun >/dev/null; then
  # Name the SDK explicitly: an inherited SDKROOT can point at a Command Line Tools SDK that
  # doesn't exist, and then the platform path (with Testing and XCTest) can't be resolved.
  SDK="$(xcrun --sdk macosx --show-sdk-path)" || exit 2
  P="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer" || exit 2
  SWIFTC=(xcrun --sdk macosx swiftc -sdk "$SDK")
  MOD_FLAGS+=(-F "$P/Library/Frameworks" -I "$P/usr/lib" -target "$(uname -m)-apple-macos14")
else
  SWIFTC=(swiftc)
fi

EXPECTED_FAILURES="$(grep -v '^#' "${SWIFT6_MATRIX_EXPECTED:-$ROOT/Fixtures/Swift6/expected-failures.txt}" 2>/dev/null || true)"
SWIFT_VERSION="$("${SWIFTC[@]}" --version 2>&1 | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -1)"
VERSION_EXPECTED="$ROOT/Fixtures/Swift6/expected-failures-swift-$SWIFT_VERSION.txt"
if [[ -f "$VERSION_EXPECTED" ]]; then
  EXPECTED_FAILURES+=$'\n'"$(grep -v '^#' "$VERSION_EXPECTED" || true)"
fi

status=0
for f in "$ROOT"/Fixtures/Swift6/*.swift; do
  n="$(basename "$f" .swift)"
  cat > "$WORK/Cuckoofile.toml" <<EOF
[modules.Fix]
imports = ["Foundation"]
sources = ["$f"]
output = "$WORK/gen/$n.mock.swift"
EOF
  "$GEN" --configuration "$WORK/Cuckoofile.toml" > "$WORK/logs/$n.gen.log" 2>&1
  "${SWIFTC[@]}" -wmo -emit-sil -o /dev/null -swift-version 6 "${MOD_FLAGS[@]}" -module-name Fix "$@" \
    "$f" "$WORK/gen/$n.mock.swift" > "$WORK/logs/$n.tc.log" 2>&1
  errors="$(grep -c "error:" "$WORK/logs/$n.tc.log")"
  if grep -qx "$n" <<< "$EXPECTED_FAILURES"; then
    if [[ "$errors" == "0" ]]; then result="XPASS"; status=1; else result="xfail"; fi
  else
    if [[ "$errors" == "0" ]]; then result="ok"; else result="FAIL"; status=1; fi
  fi
  first="$(grep -m1 "error:" "$WORK/logs/$n.tc.log" | sed -E 's/.*error: //' | cut -c1-90)"
  printf "%-5s %-36s errors=%-3s %s\n" "$result" "$n" "$errors" "$first"
done
echo "Logs: $WORK/logs"
exit $status
