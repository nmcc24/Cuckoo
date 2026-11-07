#!/usr/bin/env bash
# Points the plugins at a prebuilt generator `artifactbundle` instead of the source build (roadmap Phase 5 item 2),
# by setting `prebuiltGenerator` in Package.swift.
#
#   scripts/set-prebuilt-generator.sh remote <url> <checksum>   the release commit: the bundle attached to a release
#   scripts/set-prebuilt-generator.sh local <path>              a bundle inside the package, to test it
set -euo pipefail

cd "$(dirname "$0")/.."

case "${1:-}" in
    remote) [[ $# -eq 3 ]] || { echo "usage: $0 remote <url> <checksum>" >&2; exit 2; }
        value=".remote(url: \"$2\", checksum: \"$3\")" ;;
    local) [[ $# -eq 2 ]] || { echo "usage: $0 local <path>" >&2; exit 2; }
        value=".local(path: \"$2\")" ;;
    *) echo "usage: $0 remote <url> <checksum> | local <path>" >&2; exit 2 ;;
esac

line='let prebuiltGenerator: GeneratorBinary? = nil'
if [[ "$(grep -cxF "$line" Package.swift)" -ne 1 ]]; then
    echo "Package.swift doesn't have exactly one line: $line" >&2
    exit 1
fi
replacement="let prebuiltGenerator: GeneratorBinary? = $value"
awk -v line="$line" -v replacement="$replacement" '$0 == line { print replacement; next } { print }' Package.swift > Package.swift.new
mv Package.swift.new Package.swift
echo "Package.swift: $replacement"
