#!/usr/bin/env bash
# Ensure build/generation steps did not leave tracked files dirty.
set -euo pipefail

cd "$(dirname "$0")/.."

git update-index -q --refresh

if ! git diff --quiet --exit-code || ! git diff --cached --quiet --exit-code; then
  echo "✗ Tracked files changed unexpectedly:" >&2
  git status --short >&2
  exit 1
fi

echo "✓ No tracked generated-file drift."
