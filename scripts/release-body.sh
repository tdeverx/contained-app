#!/usr/bin/env bash
# Compose Markdown release notes for a channel build.
set -euo pipefail
cd "$(dirname "$0")/.."

CHANGELOG="${CHANGELOG:-CHANGELOG.md}"
RELEASE_NOTES_FILE="${RELEASE_NOTES:-}"
CHANGES_FILE="${CHANGES:-}"
CHANGES_DIR_VALUE="${CHANGES_DIR:-}"
VERSION_VALUE="${VERSION_VALUE:-${VERSION:-$(cat VERSION 2>/dev/null || true)}}"
CHANNEL_VALUE="${CHANNEL:-}"
CHANGES_FILE_IS_DEFAULT_CHANGELOG=false

[ -f "$CHANGELOG" ] || { echo "✗ $CHANGELOG not found" >&2; exit 1; }
[ -n "$VERSION_VALUE" ] || { echo "✗ VERSION is empty" >&2; exit 1; }

if [ -z "$RELEASE_NOTES_FILE" ]; then
  if [ -f RELEASE_NOTES.md ]; then
    RELEASE_NOTES_FILE="RELEASE_NOTES.md"
  else
    RELEASE_NOTES_FILE="$CHANGELOG"
  fi
fi

if [ -z "$CHANGES_FILE" ]; then
  if [ -f CHANGES.md ]; then
    CHANGES_FILE="CHANGES.md"
  else
    CHANGES_FILE="$CHANGELOG"
    CHANGES_FILE_IS_DEFAULT_CHANGELOG=true
  fi
fi

[ -f "$RELEASE_NOTES_FILE" ] || { echo "✗ Release notes file '$RELEASE_NOTES_FILE' not found" >&2; exit 1; }
[ -f "$CHANGES_FILE" ] || { echo "✗ Changes file '$CHANGES_FILE' not found" >&2; exit 1; }

base="${VERSION_VALUE%%+*}"
base="${base%%-*}"
if [ -z "$CHANNEL_VALUE" ]; then
  case "$VERSION_VALUE" in
    *-nightly.*) CHANNEL_VALUE="nightly" ;;
    *-beta.*) CHANNEL_VALUE="beta" ;;
    *) CHANNEL_VALUE="stable" ;;
  esac
fi

extract() {
  local file="$1"
  local version="$2"
  awk -v version="$version" '
    BEGIN { in_section=0 }
    /^## / {
      if (in_section) exit
      if (index($0, version) > 0 || index($0, "[" version "]") > 0) { in_section=1; next }
    }
    in_section { print }
  ' "$file"
}

collect_change_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  find "$dir" -type f -name '*.md' | LC_ALL=C sort | while IFS= read -r file; do
    [ -f "$file" ] || continue
    sed -n '/./,$p' "$file"
    printf '\n'
  done
}

default_changes_dir() {
  [ -z "$CHANGES_DIR_VALUE" ] || return 0
  for candidate in "changes/$CHANNEL_VALUE" "changes/unreleased"; do
    if [ -d "$candidate" ]; then
      CHANGES_DIR_VALUE="$candidate"
      return 0
    fi
  done
}

channel_title() {
  case "$CHANNEL_VALUE" in
    beta) printf 'Beta' ;;
    nightly) printf 'Nightly' ;;
    *) printf 'Release' ;;
  esac
}

full_fragment=""
if [ "$base" != "$VERSION_VALUE" ]; then
  full_fragment="$(extract "$RELEASE_NOTES_FILE" "$base")"
else
  full_fragment="$(extract "$RELEASE_NOTES_FILE" "$VERSION_VALUE")"
fi
if [ -z "$full_fragment" ] && [ "$base" != "$VERSION_VALUE" ]; then
  full_fragment="$(extract "$RELEASE_NOTES_FILE" "$VERSION_VALUE")"
fi
if [ -z "$full_fragment" ]; then
  full_fragment="$(extract "$RELEASE_NOTES_FILE" "Unreleased")"
fi

changes_fragment=""
if [ "$CHANNEL_VALUE" = "beta" ] || [ "$CHANNEL_VALUE" = "nightly" ]; then
  default_changes_dir
  if [ -n "$CHANGES_DIR_VALUE" ] && [ -d "$CHANGES_DIR_VALUE" ]; then
    changes_fragment="$(collect_change_dir "$CHANGES_DIR_VALUE")"
  fi
  if [ -z "$changes_fragment" ] && $CHANGES_FILE_IS_DEFAULT_CHANGELOG; then
    changes_fragment="$(CHANNEL="$CHANNEL_VALUE" VERSION_VALUE="$VERSION_VALUE" ./scripts/changes-since-release.sh)"
  fi
  if [ -z "$changes_fragment" ]; then
    changes_fragment="$(extract "$CHANGES_FILE" "$VERSION_VALUE")"
  fi
  if [ -z "$changes_fragment" ]; then
    changes_fragment="$(extract "$CHANGES_FILE" "$CHANNEL_VALUE")"
  fi
  if [ -z "$changes_fragment" ]; then
    changes_fragment="$(extract "$CHANGES_FILE" "Unreleased")"
  fi
fi

if [ -n "$changes_fragment" ]; then
  printf '## Changes Since Last %s\n\n' "$(channel_title)"
  printf '%s\n\n' "$changes_fragment"
fi

printf '## Full Release Notes\n\n'
if [ -n "$full_fragment" ]; then
  printf '%s\n' "$full_fragment"
else
  printf 'No full release notes were found for %s.\n' "$VERSION_VALUE"
fi
