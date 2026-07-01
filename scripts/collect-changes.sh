#!/usr/bin/env bash
# Compile committed markdown change fragments from a directory or git range.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  echo "Usage: $0 [<git-range>] [changes-dir]" >&2
  echo "       $0 changes/unreleased" >&2
}

first="${1:-}"
second="${2:-}"
range=""
changes_dir="changes/unreleased"

if [ -n "$first" ]; then
  if [ -z "$second" ] && [[ "$first" != *..* ]]; then
    changes_dir="$first"
  else
    range="$first"
    changes_dir="${second:-$changes_dir}"
  fi
fi

case "$changes_dir" in
  ""|/*|*..*)
    echo "✗ changes-dir must be a relative path inside the repository" >&2
    usage
    exit 1
    ;;
esac

emit_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  sed -n '/./,$p' "$file"
  printf '\n'
}

if [ -n "$range" ]; then
  git diff --name-only --diff-filter=AM "$range" -- "$changes_dir" \
    | LC_ALL=C sort -u \
    | while IFS= read -r file; do
        case "$file" in
          *.md) emit_file "$file" ;;
        esac
      done
else
  [ -d "$changes_dir" ] || exit 0
  find "$changes_dir" -type f -name '*.md' \
    | LC_ALL=C sort \
    | while IFS= read -r file; do emit_file "$file"; done
fi
