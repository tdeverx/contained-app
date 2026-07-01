#!/usr/bin/env bash
# Promote wiki lifecycle markers from nightly to beta, or beta to stable.
set -euo pipefail

cd "$(dirname "$0")/.."
ruby scripts/wiki-tool.rb promote "$@"
