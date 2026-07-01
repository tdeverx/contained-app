# Agent Guide

This file is the working contract for coding agents in this repository. Follow it before touching files.

## Project Shape

- This is a SwiftPM-first macOS 26 SwiftUI app.
- `Sources/ContainedCore` is pure/testable logic. Keep SwiftUI, app state, Sparkle, and persistence out of it.
- `Sources/Contained` is the app: SwiftUI screens, design system, navigation, stores, history, settings, and update support.
- `docs/wiki` mirrors the GitHub wiki. User-facing behavior or workflow changes should update the matching page.

## Branches And Updates

- Default target branch for ongoing work is `nightly` unless the maintainer says otherwise.
- Do not compute release build numbers directly in workflows or scripts. Use `scripts/version-info.sh`.
- `CFBundleVersion` must be retained when a nightly build is promoted to beta or stable.
- Stable and beta own their branch appcasts; nightly is a superset feed that also receives promoted beta/stable appcast items.
- Appcast-only bot commits must not trigger release loops. Keep `appcast.xml` path-ignored in workflows and use `[skip ci]` for appcast bot commits.

## Release Notes

- Stable ships `Full Release Notes`.
- Beta ships `Changes Since Last Beta` plus `Full Release Notes`.
- Nightly ships `Changes Since Last Nightly` plus `Full Release Notes`.
- Prefer one committed change fragment per PR or user-facing change, not one file per commit.
- Use `changes/unreleased/YYYYMMDD-short-slug.md` for normal fragments. Use `changes/beta/` or `changes/nightly/` only for channel-specific notes.
- `scripts/collect-changes.sh` can compile fragments from a directory or git range.
- Generated release-note scratch files belong under `updates/`, `.release/`, or `.release-notes/`; do not commit them.

## Design And UI Rules

- Reuse design-system primitives before adding local styling: `PanelHeader`, `PanelSection`, `PanelField`, `ResourceGlassCard`, `CommandPreviewBar`, `TintSelector`, `ToolbarIconButton`, and `Tokens`.
- Keep the classic sidebar fallback working. Toolbar-first UI and toolbar panel navigation are experimental gates, not replacements.
- Prefer native macOS/Liquid Glass behavior over custom chrome when the system primitive fits.
- Do not make broad visual changes without a product reason.

## Coding Rules

- Keep CLI actions behind `ContainerCommands` and `ContainerClient`; do not assemble argv inline in SwiftUI.
- Put pure decision logic in `ContainedCore` with focused tests.
- Do not write app personalization back as `contained.*` labels. Only `contained.restart` and `contained.stack` may round-trip through container labels.
- Keep comments human and useful. Explain surprising intent, not obvious syntax.
- Avoid large file reshuffles unless they reduce real complexity or match existing ownership boundaries.

## Verification

Run the checks that match your change:

```sh
swift build
swift test
git diff --check
```

For release scripts/workflows:

```sh
bash -n scripts/*.sh
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path) }' .github/workflows/*.yml
swift test --filter UpdaterControllerTests
```

For app/UI changes:

```sh
./scripts/bundle.sh debug
open Contained.app
```

Sync the bundled changelog before verification when release notes changed:

```sh
./scripts/sync-changelog-resource.sh
```
