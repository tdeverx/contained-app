#!/usr/bin/env bash
# Validate wiki markers, links, and PR approval requirements.
set -euo pipefail

cd "$(dirname "$0")/.."
ruby scripts/wiki-tool.rb check "$@"
