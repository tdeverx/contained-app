#!/usr/bin/env bash
# Build, open, and run the local Contained.app development bundle.
# Usage: ./Scripts/build.sh <app|open|run> [...]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Contained"
APP_BUNDLE="$ROOT/Contained.app"
BUNDLE_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUNDLE_ID="com.contained.app"

usage() {
  cat >&2 <<'USAGE'
Usage:
  ./Scripts/build.sh app [debug|release]
  ./Scripts/build.sh open
  ./Scripts/build.sh run [--debug|--logs|--telemetry|--verify]
USAGE
}

kill_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_bundle() {
  ./Scripts/package.sh app "${1:-debug}"
}

open_bundle() {
  /usr/bin/open "$APP_BUNDLE"
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift

case "$command" in
  app)
    build_bundle "${1:-debug}"
    ;;
  open)
    open_bundle
    ;;
  run)
    mode="${1:-run}"
    case "$mode" in
      run)
        kill_app
        build_bundle debug
        open_bundle
        ;;
      --debug|debug)
        kill_app
        build_bundle debug
        lldb -- "$BUNDLE_BINARY"
        ;;
      --logs|logs)
        kill_app
        build_bundle debug
        open_bundle
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
      --telemetry|telemetry)
        kill_app
        build_bundle debug
        open_bundle
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
      --verify|verify)
        kill_app
        build_bundle debug
        open_bundle
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null
        ;;
      *)
        usage
        exit 2
        ;;
    esac
    ;;
  *)
    usage
    exit 2
    ;;
esac
