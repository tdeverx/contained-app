#!/usr/bin/env bash
# Render the repository wiki mirror into publishable GitHub wiki Markdown.
set -euo pipefail

cd "$(dirname "$0")/.."
ruby scripts/wiki-tool.rb render "$@"
