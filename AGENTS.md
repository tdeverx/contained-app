# Agent Guide

This file is the working contract for coding agents in this repository. Follow it before touching files.

## Project Shape

- This is a SwiftPM-first macOS 26 SwiftUI app.
- `Sources/ContainedCore` is pure/testable logic. Keep SwiftUI, app state, Sparkle, and persistence out of it.
- `Sources/Contained` is the app: SwiftUI screens, design system, navigation, stores, history, settings, and update support.
- `docs/wiki` mirrors the GitHub wiki. User-facing behavior or workflow changes should update the matching page.
- Keep directory names intentional: SwiftPM-owned folders stay `Sources` and `Tests`, Swift source domain folders use PascalCase, and repo infrastructure uses lowercase names such as `docs` and `scripts`.

## Branches And Updates

- Default target branch for ongoing work is `nightly` unless the maintainer says otherwise.
- Do not compute release build numbers directly in workflows or scripts. Use `scripts/version-info.sh`.
- `CFBundleVersion` must be retained when a nightly build is promoted to beta or stable.
- Stable and beta own their branch appcasts; nightly is a superset feed that also receives promoted beta/stable appcast items.
- Appcast-only bot commits must not trigger release loops. Keep `appcast.xml` path-ignored in workflows and use `[skip ci]` for appcast bot commits.
- PR/release workflows run `scripts/ci-validate.sh`; keep that script fast and focused on repository invariants before expensive Swift builds.
- PR CI enforces release-note coverage for material changes. Add a changelog/change fragment, or use the `no-release-note` label only for docs/meta-only work.
- Release workflows validate built bundles and generated appcasts before publishing or committing feed changes.

## Release Notes

- Stable ships `Full Release Notes`.
- Beta ships `Changes Since Last Beta` plus `Full Release Notes`.
- Nightly ships `Changes Since Last Nightly` plus `Full Release Notes`.
- Keep `CHANGELOG.md` ordered with `Unreleased` above released version sections; in-app What's New
  and generated Sparkle notes should both show channel/build changes before full version notes.
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
- Keep helper scripts in `scripts/` and prefer hyphenated file names for multi-word shell scripts.
- Keep comments human and useful. Explain surprising intent, not obvious syntax.
- Debug-only tools, menus, and diagnostics must be guarded with `#if CONTAINED_DEBUG_TOOLS`; SwiftPM defines it only for debug builds so release bundles exclude that code.
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
./scripts/ci-validate.sh
./scripts/test-release-scripts.sh
swift test --filter UpdaterControllerTests
```

For generated release artifacts:

```sh
VERSION="$VERSION" BUILD="$BUILD" ./scripts/validate-bundle.sh Contained.app
CHANNEL=nightly ./scripts/validate-appcast.sh appcast.xml
./scripts/check-generated-clean.sh
```

For app/UI changes:

```sh
./scripts/bundle.sh debug
open Contained.app
```

Sync the bundled changelog before verification when release notes changed:

```sh
./scripts/sync-changelog-resource.sh
./scripts/sync-changelog-resource.sh --check
```
