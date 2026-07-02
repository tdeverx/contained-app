#!/usr/bin/env bash
# Fail material PRs that forget a committed release note or change fragment.
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "✗ $*" >&2
  exit 1
}

base_ref="${BASE_REF:-${1:-}}"
head_ref="${HEAD_REF:-${2:-HEAD}}"

if [ "${NO_RELEASE_NOTE:-}" = "1" ]; then
  echo "✓ Release-note requirement skipped by NO_RELEASE_NOTE=1."
  exit 0
fi

[ -n "$base_ref" ] || fail "BASE_REF is required for release-note enforcement"
git rev-parse --verify "$base_ref" >/dev/null 2>&1 || fail "Base ref '$base_ref' was not found"
git rev-parse --verify "$head_ref" >/dev/null 2>&1 || fail "Head ref '$head_ref' was not found"

changed_files="$(git diff --name-only --diff-filter=ACMR "$base_ref...$head_ref")"
if [ -z "$changed_files" ]; then
  echo "✓ No changed files to inspect for release notes."
  exit 0
fi

has_note=false
has_material_change=false

while IFS= read -r file; do
  [ -n "$file" ] || continue

  case "$file" in
    CHANGELOG.md|Sources/ContainedApp/Resources/CHANGELOG.md|RELEASE_NOTES.md|CHANGES.md|changes/*.md|changes/*/*.md)
      has_note=true
      ;;
  esac

  case "$file" in
    Package.swift|Package.resolved|VERSION|Sources/**|Tests/**|Resources/**|scripts/**|.github/workflows/**)
      has_material_change=true
      ;;
  esac
done <<< "$changed_files"

if $has_material_change && ! $has_note; then
  echo "✗ Material changes need a release note or change fragment." >&2
  echo >&2
  echo "Changed files:" >&2
  while IFS= read -r file; do
    [ -n "$file" ] && printf '  %s\n' "$file" >&2
  done <<< "$changed_files"
  echo >&2
  echo "Add one of:" >&2
  echo "  - CHANGELOG.md plus synced Sources/ContainedApp/Resources/CHANGELOG.md" >&2
  echo "  - changes/unreleased/YYYYMMDD-short-slug.md" >&2
  echo "  - RELEASE_NOTES.md / CHANGES.md when the release train uses split files" >&2
  echo >&2
  echo "For docs/meta/dependency-only maintenance, apply the 'no-release-note' PR label so CI sets NO_RELEASE_NOTE=1." >&2
  exit 1
fi

echo "✓ Release-note requirement passed."
