#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="${1:-build}"
product="${2:-Contained}"
configuration="$(printf '%s' "${CONFIGURATION:-Debug}" | tr '[:upper:]' '[:lower:]')"

case "$configuration" in
  debug|release) ;;
  *) configuration="debug" ;;
esac

case "$mode" in
  build)
    swift build -c "$configuration" --product "$product"
    ;;
  test)
    swift test
    ;;
  *)
    echo "Unknown Xcode SwiftPM bridge mode: $mode" >&2
    exit 64
    ;;
esac
