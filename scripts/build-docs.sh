#!/usr/bin/env bash
# Builds the Cuckoo runtime's DocC documentation into a .doccarchive and fails on any docc warning.
# Needs no package dependency: it takes the module's symbol graph from SwiftPM and runs the toolchain's docc.
#
# Usage: scripts/build-docs.sh [output-path]   (default: .build/docs/Cuckoo.doccarchive)
# Extra docc options can be passed in DOCC_FLAGS, e.g. DOCC_FLAGS="--transform-for-static-hosting".
set -euo pipefail

cd "$(dirname "$0")/.."
output="${1:-.build/docs/Cuckoo.doccarchive}"

# On Linux, Swift 6.2 and 6.3 exit 1 after writing the runtime's graph, because they can't emit one for the
# test-discovery modules. Carry on, and fail below if the runtime's graph is missing.
swift package dump-symbol-graph --minimum-access-level public >/dev/null || true
graphs="$(find .build -type d -name symbolgraph -newer Package.swift | head -1)"
if [ -z "$graphs" ]; then
    graphs="$(find .build -type d -name symbolgraph | head -1)"
fi
if [ -z "$graphs" ] || [ ! -f "$graphs/Cuckoo.symbols.json" ]; then
    echo "error: swift package dump-symbol-graph wrote no Cuckoo.symbols.json" >&2
    exit 1
fi

# Only the runtime module, plus its extensions of other modules' types (`Cuckoo@Swift.symbols.json`).
selected="$(mktemp -d)"
trap 'rm -rf "$selected"' EXIT
cp "$graphs"/Cuckoo.symbols.json "$selected"/
cp "$graphs"/Cuckoo@*.symbols.json "$selected"/ 2>/dev/null || true

# `docc` comes with the toolchain; on macOS it's reached through xcrun.
docc=docc
if ! command -v docc >/dev/null 2>&1; then
    docc="xcrun docc"
fi

mkdir -p "$(dirname "$output")"
$docc convert Source/Cuckoo.docc \
    --additional-symbol-graph-dir "$selected" \
    --fallback-display-name Cuckoo \
    --fallback-bundle-identifier org.brightify.Cuckoo \
    --output-path "$output" \
    --warnings-as-errors \
    ${DOCC_FLAGS:-}
echo "Documentation written to $output"
