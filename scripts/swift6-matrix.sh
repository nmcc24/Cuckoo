#!/usr/bin/env bash
# Generates mocks for every fixture in Fixtures/Swift6 and typechecks each
# fixture + its mock in Swift 6 language mode. Prints one line per fixture.
#
# Usage: scripts/swift6-matrix.sh [extra swiftc flags, e.g. -default-isolation MainActor]
# Fixtures listed in Fixtures/Swift6/expected-failures.txt are expected to fail.
# Exit code: 0 if every fixture behaves as expected, 1 on a new failure or an
# expected failure that now passes (remove it from the list), 2 if the build fails.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${SWIFT6_MATRIX_WORK:-$ROOT/.build/swift6-matrix}"
mkdir -p "$WORK/gen" "$WORK/logs"

for args in "--product CuckooGenerator" "--target Cuckoo"; do
  # shellcheck disable=SC2086
  if ! swift build --package-path "$ROOT" $args > "$WORK/logs/build.log" 2>&1; then
    cat "$WORK/logs/build.log"
    exit 2
  fi
done
BIN="$(swift build --package-path "$ROOT" --show-bin-path)"
GEN="$BIN/CuckooGenerator"

# Module search paths differ between the Xcode build system (macOS) and the native one (Linux).
MOD_FLAGS=(-I "$BIN" -I "$BIN/Modules" -F "$BIN")
if [[ -d "$ROOT/.build/out/Products/Debug" ]]; then
  MOD_FLAGS+=(-I "$ROOT/.build/out/Products/Debug" -F "$ROOT/.build/out/Products/Debug")
fi
if command -v xcrun >/dev/null; then
  SWIFTC=(xcrun swiftc)
  P="$(xcrun --show-sdk-platform-path)/Developer"
  MOD_FLAGS+=(-F "$P/Library/Frameworks" -I "$P/usr/lib" -target "$(uname -m)-apple-macos14")
else
  SWIFTC=(swiftc)
fi

EXPECTED_FAILURES="$(grep -v '^#' "$ROOT/Fixtures/Swift6/expected-failures.txt" 2>/dev/null || true)"

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
  "${SWIFTC[@]}" -typecheck -swift-version 6 "${MOD_FLAGS[@]}" -module-name Fix "$@" \
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
