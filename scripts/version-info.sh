#!/usr/bin/env bash
# Print release version/build values shared by CI workflows and bundle.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

command="${1:-version}"
channel="${CHANNEL:-${2:-nightly}}"
base="${BASE_VERSION:-$(cat VERSION 2>/dev/null || echo 1.0.0)}"
build="${BUILD:-}"
sha="${SHA:-}"
build_source_ref="${BUILD_SOURCE_REF:-}"

if [ -z "$sha" ]; then
  sha="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
fi

build_from_source_ref() {
  [ -n "$build_source_ref" ] || return 1
  appcast="$(git show "$build_source_ref:appcast.xml" 2>/dev/null || true)"
  [ -n "$appcast" ] || return 1

  SHORT_SHA="$sha" perl -0ne '
    my $sha = $ENV{"SHORT_SHA"};
    while (m{<item>.*?</item>}gs) {
      my $item = $&;
      next unless index($item, $sha) >= 0;
      if ($item =~ m{<sparkle:version>([^<]+)</sparkle:version>}) {
        print "$1\n";
        exit 0;
      }
    }
    exit 1;
  ' <<<"$appcast"
}

if [ -z "$build" ]; then
  build="$(build_from_source_ref || git rev-list --count HEAD 2>/dev/null || echo 1)"
fi

case "$command" in
  base)
    printf '%s\n' "$base"
    ;;
  build)
    printf '%s\n' "$build"
    ;;
  sha)
    printf '%s\n' "$sha"
    ;;
  version)
    case "$channel" in
      stable)
        printf '%s\n' "$base"
        ;;
      beta)
        printf '%s-beta.%s+%s\n' "$base" "$build" "$sha"
        ;;
      nightly)
        printf '%s-nightly.%s+%s\n' "$base" "$build" "$sha"
        ;;
      *)
        echo "✗ Unknown channel '$channel' (expected stable, beta, or nightly)" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Usage: $0 [base|build|sha|version] [stable|beta|nightly]" >&2
    exit 1
    ;;
esac
