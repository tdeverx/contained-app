#!/usr/bin/env bash
# Print the Markdown changelog section for a release version.
set -euo pipefail
cd "$(dirname "$0")/.."

CHANGELOG="${CHANGELOG:-CHANGELOG.md}"
VERSION_VALUE="${VERSION_VALUE:-${VERSION:-$(cat VERSION 2>/dev/null || true)}}"

[ -f "$CHANGELOG" ] || { echo "✗ $CHANGELOG not found" >&2; exit 1; }
[ -n "$VERSION_VALUE" ] || { echo "✗ VERSION is empty" >&2; exit 1; }

base="${VERSION_VALUE%%+*}"
base="${base%%-*}"

extract() {
  local version="$1"
  awk -v version="$version" '
    BEGIN { in_section=0 }
    /^## / {
      if (in_section) exit
      if (index($0, version) > 0 || index($0, "[" version "]") > 0) { in_section=1; next }
    }
    in_section { print }
  ' "$CHANGELOG"
}

fragment="$(extract "$VERSION_VALUE")"
if [ -z "$fragment" ] && [ "$base" != "$VERSION_VALUE" ]; then
  fragment="$(extract "$base")"
fi
if [ -z "$fragment" ]; then
  fragment="$(extract "Unreleased")"
fi

[ -n "$fragment" ] || fragment="No release notes were found for $VERSION_VALUE."
printf '%s\n' "$fragment"
