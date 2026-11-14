#!/usr/bin/env bash
# Prints a version's release notes: its section of CHANGELOG.md, from its `## <version>` heading to the next `## `
# heading. Fails if the section is missing or empty, so the Release workflow can check it before it tags anything.
#
# A relative link, such as the migration guide's, works in the repository but not on the release page, so it's
# rewritten to the file at the version's tag in $GITHUB_REPOSITORY (nmcc24/Cuckoo by default).
#
#   scripts/release-notes.sh <version>
set -euo pipefail

cd "$(dirname "$0")/.."

[[ $# -eq 1 ]] || { echo "usage: $0 <version>" >&2; exit 2; }
version="$1"

notes="$(awk -v heading="## $version" '$0 == heading { found = 1; next } found && /^## / { exit } found' CHANGELOG.md)"
[[ "$notes" =~ [^[:space:]] ]] || { echo "CHANGELOG.md has no section '## $version', or it's empty." >&2; exit 1; }
repository="${GITHUB_REPOSITORY:-nmcc24/Cuckoo}"
printf '%s\n' "$notes" | BASE="https://github.com/$repository/blob/$version/" \
  perl -pe 's{\]\((?![a-z][a-z0-9+.-]*:|#|/)([^)\s]+)\)}{]($ENV{BASE}$1)}gi'
