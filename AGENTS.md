# Agent Guide

This file is the working contract for coding agents in this repository. Follow it before touching files.

## Project Shape

- This is a package-first macOS 26 SwiftUI app with both SwiftPM and native Xcode entry points.
- Local reusable packages live under `Packages/` and are consumed by the root SwiftPM package and the native Xcode app target.
- `Contained.xcworkspace` is the Xcode entry point. `Contained.xcodeproj` contains a native macOS app target that links the `ContainedApp` package product and builds/runs `Contained.app` directly from Xcode.
- SwiftPM remains the CI, release, packaging, signing, notarization, and appcast source of truth. Keep `Package.swift`, `swift build`, `swift test`, and `scripts/bundle.sh` working.
- `Packages/ContainedCore/Sources/ContainedCore` is pure/testable logic. Keep SwiftUI, app state, Sparkle, and persistence out of it.
- `Packages/ContainedRuntime/Sources/ContainedRuntime` is the shared runtime contract module. Keep it adapter-neutral so future runtimes can conform without changing app stores or views.
- `Packages/AppleContainerRuntime/Sources/AppleContainerRuntime` is the Apple `container` adapter. Future Docker-compatible, Podman, Lima-backed, remote, or other engines should be sibling adapter packages rather than switches in the app.
- `Sources/ContainedApp` is the app implementation: SwiftUI screens, app-specific presentation mappings, navigation, stores, history, settings, localization, and update support.
- `Sources/Contained` is only the tiny SwiftPM executable launcher.
- `Packages/ContainedDesignSystem` is the reusable SwiftUI/AppKit design-system package. Keep app state, stores, Sparkle, SwiftData, persistence, and feature routing out of it.
- `Packages/ContainedNavigation` is the reusable navigation/layout package. Keep app sections, toolbar panels, stores, and concrete routing state in `Sources/ContainedApp`.
- `Packages/ContainedPreviewSupport` is deterministic fixture data for package examples and SwiftUI previews. Keep live runtime calls and localized copy out of it.
- `docs/` is structured by audience and ownership. User-facing behavior or workflow changes should update the matching page under `docs/app`, `docs/features`, `docs/development`, `docs/architecture`, or `docs/release`.
- Package docs live beside each package as README + DocC. Keep package examples working and app-supplied strings explicit.
- Keep directory names intentional: SwiftPM-owned folders stay `Sources` and `Tests`, Swift source domain folders use PascalCase, and repo infrastructure uses lowercase names such as `docs` and `scripts`.

## Branches And Updates

- Default target branch for ongoing work is `nightly` unless the maintainer says otherwise.
- Do not compute release build numbers directly in workflows or scripts. Use `scripts/version-info.sh`.
- `CFBundleVersion` must be retained when a nightly build is promoted to beta or stable.
- Stable and beta own their branch appcasts; nightly is a superset feed that also receives promoted beta/stable appcast items.
- Appcast-only bot commits must not trigger release loops. Keep `appcast.xml` path-ignored in workflows and use `[skip ci]` for appcast bot commits.
- CodeQL uses the checked-in advanced setup at `.github/workflows/codeql.yml`. Actions workflow analysis runs on PRs, pushes, and the weekly baseline; Swift analysis is scheduled/manual because Swift CodeQL currently takes too long to be a healthy per-PR gate. Keep appcast, docs, and release-note-only paths ignored there too.
- PR/release workflows run `scripts/ci-validate.sh`; keep that script fast and focused on repository invariants before expensive Swift builds.
- PR CI enforces release-note coverage for material changes. Add a changelog/change fragment, or use the `no-release-note` label only for docs/meta/dependency-only maintenance.
- Release workflows validate built bundles and generated appcasts before publishing or committing feed changes.

## GitHub Issues

- Follow `docs/development/Issues-and-Discussions.md` for issue routing, naming, labels, milestones, native parent/sub-issue links, and blocked-by/blocking links.
- Use area labels for ownership only; do not treat area labels as workflow state.

## Release Notes

- Stable ships `Full Release Notes`.
- Beta ships `Changes Since Last Beta` plus `Full Release Notes`.
- Nightly ships `Changes Since Last Nightly` plus `Full Release Notes`.
- Keep `CHANGELOG.md` ordered with `Unreleased` above released version sections; in-app What's New
  and generated Sparkle notes should both show channel/build changes before full version notes.
- Keep `CHANGELOG.md` curated and version-level. Put PR/build deltas in change fragments, not as
  a running implementation inventory.
- Prefer one committed change fragment per PR or user-facing change, not one file per commit.
- Use `changes/unreleased/YYYYMMDD-short-slug.md` for normal fragments. Use `changes/beta/` or `changes/nightly/` only for channel-specific notes.
- `scripts/collect-changes.sh` can compile fragments from a directory or git range.
- When no explicit `CHANGES`/`CHANGES_DIR` source is provided, Beta/Nightly release notes use `scripts/changes-since-release.sh` to derive the build-change section from the previous matching appcast item and the changelog/change-fragment git delta.
- Generated release-note scratch files belong under `updates/`, `.release/`, or `.release-notes/`; do not commit them.

## Design And UI Rules

- Reuse app-facing design-system routes before adding local styling: `PanelHeader`, `PanelSection`, `PanelField`, `DesignCard`, `DesignActionGroup`, `DesignTextActionButton`, `DesignToggleButton`, `DesignSelectionActionBar`, `CommandPreviewBar`, `TintSelector`, and `DesignTokens`.
- Do not add app-local spacing, padding, radius, shadow, material, opacity, glass button styles, or micro-chrome constants. Add or extend a `ContainedDesignSystem` token/primitive first, then consume it from the app. Low-level package composition pieces such as card shell/header/page-rail assembly, glass button groups, and glass surface modifiers are package-internal and should not be reintroduced in `Sources/ContainedApp`.
- Keep the classic sidebar fallback working. Toolbar-first UI and toolbar panel navigation are experimental gates, not replacements.
- Prefer native macOS/Liquid Glass behavior over custom chrome when the system primitive fits.
- Do not make broad visual changes without a product reason.

## Coding Rules

- Keep Apple `container` CLI actions behind `ContainerCommands` and `AppleContainerRuntime`; do not assemble argv inline in SwiftUI. App stores should depend on `any ContainerRuntimeClient` where backend choice matters.
- Put pure decision logic in `ContainedCore` with focused tests.
- Keep localization owned by `Sources/ContainedApp`. Packages should receive
  app-supplied labels/help/accessibility strings and should not add English UI
  defaults or localized resource bundles. Use `AppText` for reusable app copy
  and dynamic templates; plain SwiftUI literals are acceptable when SwiftUI keeps
  them localization-ready.
- Keep package errors display-neutral. Reusable targets should throw typed errors
  with stable codes/context, preferably `ContainedPackageError`, while
  `Sources/ContainedApp` maps them through `AppErrorPresentation`/`AppText` before
  showing toasts, alerts, inline errors, or Activity entries. Preserve arbitrary
  backend stderr as runtime detail rather than pretending to localize it.
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

For CodeQL/workflow changes:

```sh
./scripts/ci-validate.sh
swift build --arch arm64 --product Contained
```

For generated release artifacts:

```sh
VERSION="$VERSION" BUILD="$BUILD" ./scripts/validate-bundle.sh Contained.app
CHANNEL=nightly ./scripts/validate-appcast.sh appcast.xml
./scripts/check-generated-clean.sh
```

For app/UI changes:

```sh
xcodebuild -workspace Contained.xcworkspace -scheme Contained -configuration Debug build
xcodebuild -workspace Contained.xcworkspace -scheme Contained -configuration Debug test
./scripts/bundle.sh debug
open Contained.app
```

Sync the bundled changelog before verification when release notes changed:

```sh
./scripts/sync-changelog-resource.sh
./scripts/sync-changelog-resource.sh --check
```
