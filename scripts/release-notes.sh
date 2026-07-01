#!/usr/bin/env bash
# Write composed Sparkle release-note HTML fragments next to each archive in an updates directory.
set -euo pipefail
cd "$(dirname "$0")/.."

UPDATES_DIR="${1:-updates}"
CHANGELOG="${CHANGELOG:-CHANGELOG.md}"
VERSION_VALUE="${VERSION_VALUE:-${VERSION:-$(cat VERSION 2>/dev/null || true)}}"

[ -d "$UPDATES_DIR" ] || { echo "✗ Updates dir '$UPDATES_DIR' not found"; exit 1; }
[ -f "$CHANGELOG" ] || { echo "✗ $CHANGELOG not found"; exit 1; }
[ -n "$VERSION_VALUE" ] || { echo "✗ VERSION is empty"; exit 1; }

fragment="$(VERSION_VALUE="$VERSION_VALUE" CHANGELOG="$CHANGELOG" ./scripts/release-body.sh)"

html="$(printf '%s\n' "$fragment" | awk '
  BEGIN { in_list=0 }
  /^## / {
    if (in_list) { print "</ul>"; in_list=0 }
    sub(/^## /, "")
    print "<h2>" $0 "</h2>"
    next
  }
  /^### / {
    if (in_list) { print "</ul>"; in_list=0 }
    sub(/^### /, "")
    print "<h3>" $0 "</h3>"
    next
  }
  /^#### / {
    if (in_list) { print "</ul>"; in_list=0 }
    sub(/^#### /, "")
    print "<h4>" $0 "</h4>"
    next
  }
  /^[[:space:]]*- / {
    if (!in_list) { print "<ul>"; in_list=1 }
    sub(/^[[:space:]]*- /, "")
    print "<li>" $0 "</li>"
    next
  }
  /^[[:space:]]*$/ {
    if (in_list) { print "</ul>"; in_list=0 }
    next
  }
  {
    if (in_list) { print "</ul>"; in_list=0 }
    print "<p>" $0 "</p>"
  }
  END { if (in_list) print "</ul>" }
')"

found=0
for archive in "$UPDATES_DIR"/*.{dmg,zip,tar.gz,tgz}; do
  [ -e "$archive" ] || continue
  found=1
  base="$archive"
  case "$base" in
    *.tar.gz) base="${base%.tar.gz}" ;;
    *) base="${base%.*}" ;;
  esac
  printf '%s\n' "$html" > "$base.html"
  echo "✓ Wrote ${base}.html"
done

[ "$found" -eq 1 ] || { echo "✗ No archives found in $UPDATES_DIR"; exit 1; }
