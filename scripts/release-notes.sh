#!/usr/bin/env bash
# Prints a version's release notes: its section of CHANGELOG.md, from its `## <version>` heading to the next `## `
# heading. Fails if the section is missing or empty, so the Release workflow can check it before it tags anything.
#
# A relative link, such as the migration guide's, works in the repository but not on the release page, so it's
# rewritten to the file at the version's tag in $GITHUB_REPOSITORY (nmcc24/Cuckoo by default): inline links and
# images, with angle brackets or a title, and reference definitions. Absolute URLs, anchors and root-relative
# paths are left alone.
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
  perl -pe '
    # An inline link or image, with or without angle brackets and a title: [text](path "title").
    # The bracket is possessive, so a rejected absolute link can't match again without it.
    s{\]\(\s*(<?+)(?![a-z][a-z0-9+.-]*:|#|/)([^)\s>]+)}{]($1$ENV{BASE}$2}gi;
    # A reference definition, [label]: path "title", but not a footnote, [^1]: text.
    s{^(\s{0,3}\[(?!\^)[^\]]+\]:\s*<?+)(?![a-z][a-z0-9+.-]*:|#|/)(\S+)}{$1$ENV{BASE}$2}i;
  '
