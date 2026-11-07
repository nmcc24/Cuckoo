#!/usr/bin/env bash
# Builds the generator's prebuilt `artifactbundle` (roadmap Phase 5 item 2).
#
#   scripts/build-artifactbundle.sh build <parts-dir>
#       Builds CuckooGenerator in release mode for this machine's platform and puts it in <parts-dir>, with the
#       target triples it runs on: macOS as a universal binary (arm64 and x86_64), Linux for this machine's
#       architecture with the Swift runtime linked statically, so it needs no toolchain to run.
#
#   scripts/build-artifactbundle.sh merge <version> <bundle-dir> <parts-dir>...
#       Lays the parts out as <bundle-dir> (named `CuckooGenerator.artifactbundle`), with its info.json, zips it
#       next to it and prints the zip's checksum, which the release commit's `binaryTarget` names.
#
# SWIFT_BUILD_FLAGS adds flags to `swift build`, such as `--build-system native`.
set -euo pipefail

cd "$(dirname "$0")/.."

build() {
    local parts="$1"
    local name triples arch_flags strip_flags
    case "$(uname -s)" in
        Darwin)
            name=macos
            triples='"arm64-apple-macosx", "x86_64-apple-macosx"'
            arch_flags=(--arch arm64 --arch x86_64)
            strip_flags=(-x)
            ;;
        Linux)
            local arch
            arch="$(uname -m)"
            name="linux-$arch"
            triples="\"$arch-unknown-linux-gnu\""
            arch_flags=(--static-swift-stdlib)
            strip_flags=()
            ;;
        *)
            echo "Unsupported platform: $(uname -s)" >&2
            exit 1
            ;;
    esac

    # shellcheck disable=SC2086 # SWIFT_BUILD_FLAGS holds several flags.
    swift build -c release --product CuckooGenerator "${arch_flags[@]}" ${SWIFT_BUILD_FLAGS:-}
    local bin
    # shellcheck disable=SC2086
    bin="$(swift build -c release "${arch_flags[@]}" ${SWIFT_BUILD_FLAGS:-} --show-bin-path)"

    local part="$parts/CuckooGenerator-$name"
    rm -rf "$part"
    mkdir -p "$part/bin"
    cp "$bin/CuckooGenerator" "$part/bin/CuckooGenerator"
    strip "${strip_flags[@]}" "$part/bin/CuckooGenerator"
    if grep -q icudt "$part/bin/CuckooGenerator"; then
        echo "The generator links ICU's data (44 MB): something in it uses swift-corelibs Foundation rather than FoundationEssentials." >&2
        exit 1
    fi
    echo "$triples" > "$part/triples"
    echo "Built $part ($(du -h "$part/bin/CuckooGenerator" | cut -f1))"
}

merge() {
    local version="$1" bundle="$2"
    shift 2
    if [[ "$(basename "$bundle")" != CuckooGenerator.artifactbundle ]]; then
        echo "The bundle must be named CuckooGenerator.artifactbundle: $bundle" >&2
        exit 1
    fi
    rm -rf "$bundle" "$bundle.zip"
    mkdir -p "$bundle"

    local variants=()
    local parts part
    for parts in "$@"; do
        for part in "$parts"/CuckooGenerator-*; do
            [[ -d "$part" ]] || continue
            cp -R "$part" "$bundle/"
            variants+=("{ \"path\": \"$(basename "$part")/bin/CuckooGenerator\", \"supportedTriples\": [$(cat "$part/triples")] }")
            rm "$bundle/$(basename "$part")/triples"
        done
    done
    if [[ ${#variants[@]} -eq 0 ]]; then
        echo "No parts found in: $*" >&2
        exit 1
    fi

    local joined
    joined="$(printf '        %s,\n' "${variants[@]}")"
    cat > "$bundle/info.json" <<EOF
{
  "schemaVersion": "1.0",
  "artifacts": {
    "CuckooGenerator": {
      "version": "$version",
      "type": "executable",
      "variants": [
${joined%,}
      ]
    }
  }
}
EOF
    cp LICENSE "$bundle/LICENSE"

    (cd "$(dirname "$bundle")" && rm -f CuckooGenerator.artifactbundle.zip && zip -qry CuckooGenerator.artifactbundle.zip CuckooGenerator.artifactbundle)
    echo "Bundle: $bundle.zip ($(du -h "$bundle.zip" | cut -f1))"
    echo "Checksum: $(swift package compute-checksum "$bundle.zip")"
}

case "${1:-}" in
    build) [[ $# -eq 2 ]] || { echo "usage: $0 build <parts-dir>" >&2; exit 2; }; build "$2" ;;
    merge) [[ $# -ge 4 ]] || { echo "usage: $0 merge <version> <bundle-dir> <parts-dir>..." >&2; exit 2; }; shift; merge "$@" ;;
    *) echo "usage: $0 build <parts-dir> | merge <version> <bundle-dir> <parts-dir>..." >&2; exit 2 ;;
esac
