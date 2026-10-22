#!/usr/bin/env bash
# Generates mocks for every fixture in Fixtures/Swift6 and typechecks each
# fixture + its mock in Swift 6 language mode. Prints one line per fixture.
#
# Usage: scripts/swift6-matrix.sh [extra swiftc flags, e.g. -default-isolation MainActor]
# Exit code: 0 if every fixture typechecks, 1 otherwise.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${SWIFT6_MATRIX_WORK:-$ROOT/.build/swift6-matrix}"
mkdir -p "$WORK/gen" "$WORK/logs"

swift build --package-path "$ROOT" --product CuckooGenerator >/dev/null
swift build --package-path "$ROOT" --target Cuckoo >/dev/null
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
  [[ "$errors" == "0" ]] || status=1
  first="$(grep -m1 "error:" "$WORK/logs/$n.tc.log" | sed -E 's/.*error: //' | cut -c1-100)"
  printf "%-36s errors=%-3s %s\n" "$n" "$errors" "$first"
done
echo "Logs: $WORK/logs"
exit $status
