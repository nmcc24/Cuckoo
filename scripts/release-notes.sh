#!/usr/bin/env bash
# Prints a version's release notes: its section of CHANGELOG.md, from its `## <version>` heading to the next `## `
# heading. Fails if the section is missing or empty, so the Release workflow can check it before it tags anything.
#
#   scripts/release-notes.sh <version>
set -euo pipefail

cd "$(dirname "$0")/.."

[[ $# -eq 1 ]] || { echo "usage: $0 <version>" >&2; exit 2; }
version="$1"

notes="$(awk -v heading="## $version" '$0 == heading { found = 1; next } found && /^## / { exit } found' CHANGELOG.md)"
[[ "$notes" =~ [^[:space:]] ]] || { echo "CHANGELOG.md has no section '## $version', or it's empty." >&2; exit 1; }
printf '%s\n' "$notes"
