#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Contained"
APP_BUNDLE="$ROOT_DIR/Contained.app"
BUNDLE_SCRIPT="$ROOT_DIR/scripts/bundle.sh"
BUNDLE_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUNDLE_ID="com.contained.app"

kill_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_bundle() {
  "$BUNDLE_SCRIPT" debug
}

open_bundle() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    kill_app
    build_bundle
    open_bundle
    ;;
  --debug|debug)
    kill_app
    build_bundle
    lldb -- "$BUNDLE_BINARY"
    ;;
  --logs|logs)
    kill_app
    build_bundle
    open_bundle
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    kill_app
    build_bundle
    open_bundle
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    kill_app
    build_bundle
    open_bundle
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
