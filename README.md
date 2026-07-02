>[!warning]
>Major Refactor in Progress
>
>A large foundation refactor is currently under review in [PR #48](https://github.com/tdeverx/contained-app/pull/48). This introduces significant changes across the codebase and will likely require existing branches to be rebased with manual conflict resolution.
>
>If you’re planning to contribute, it’s recommended that you base new work on this branch until it has been merged.


<p align="center">
  <img src=".github/assets/icon.png" width="128" alt="Contained icon">
</p>

<h1 align="center">Contained</h1>

Contained is a native macOS control surface for Apple's [`container`](https://github.com/apple/container) CLI. It gives containers, images, volumes, networks, registries, logs, templates, and app-managed health/restart behavior a Mac-first SwiftUI interface without hiding the underlying command line.

<p align="center">
  <img src=".github/assets/screenshot.png" width="900" alt="Contained running containers">
  <br><sub><i>Pre-1.0 and actively polishing.</i></sub>
</p>

## What It Does

- Run, edit, stop, restart, inspect, and delete containers.
- Browse rich Liquid Glass cards with local-only tint, icon, nickname, and graph personalization.
- Manage images, tags, updates, archives, volumes, networks, registry credentials, templates, activity history, and system resources.
- Import Compose files into editable run forms instead of launching opaque stacks.
- Reveal the exact `container` CLI command before privileged run/edit operations.
- Optionally enable the floating toolbar, morph panels, command palette, Docker Hub search, image build workspace, keyboard shortcuts, and Compose import from Settings -> Experimental.

## Install

Download the latest `.dmg` from [Releases](https://github.com/tdeverx/contained-app/releases).

Sparkle updates are built in. During pre-1.0 development, fresh installs default to the Nightly channel so they can receive current builds. Stable, Beta, and Nightly can be changed in Settings -> Updates.

Requirements:

- macOS 26 or later on Apple silicon
- Apple's `container` CLI 1.0.0 on `PATH`
- Xcode 26 / Swift 6.2+ for local development

## Build

Contained has two supported development entry points that share the same package
graph:

- Xcode: `Contained.xcworkspace` contains a native macOS app target that builds
  and runs `Contained.app` directly for SwiftUI iteration.
- SwiftPM: `Package.swift`, `swift build`, `swift test`, and `scripts/bundle.sh`
  remain the CI, release, packaging, signing, notarization, and appcast path.

```sh
open Contained.xcworkspace
swift build
swift test
xcodebuild -workspace Contained.xcworkspace -scheme Contained -configuration Debug build
xcodebuild -workspace Contained.xcworkspace -scheme Contained -configuration Debug test
./scripts/bundle.sh debug
open Contained.app
```

Maintainers use `scripts/release.sh` and `scripts/appcast.sh` for signing, notarization, DMG creation, GitHub release notes, and Sparkle appcasts.

## Documentation

Maintained docs live in [`docs`](docs) beside the code so architecture and
workflow changes can be reviewed with implementation changes:

- App: [Home](docs/app/Home.md), [Installation](docs/app/Installation.md), [Keyboard Shortcuts](docs/app/Keyboard-Shortcuts.md), [Troubleshooting](docs/app/Troubleshooting.md), [Updates](docs/app/Updates.md), [System Settings](docs/app/System-Settings.md)
- Features: [Feature Overview](docs/features/Features.md), [Containers](docs/features/Containers.md), [Images](docs/features/Images.md), [Resources](docs/features/Resources.md), [Creation Workflow](docs/features/Creation-Workflow.md), [Run / Edit Form](docs/features/Run-Edit-Form.md), [Compose Import](docs/features/Compose-Import.md), [Command Palette](docs/features/Command-Palette.md)
- Architecture: [Architecture](docs/architecture/Architecture.md), [Runtime Adapters](docs/architecture/Runtime-Adapters.md), [Design System](docs/architecture/Design-System.md)
- Development: [Contributing](docs/development/Contributing.md), [Issues and Discussions](docs/development/Issues-and-Discussions.md), [Localization](docs/app/Localization.md)
- Release: [Release Runbook](docs/release/Release.md)

Each local package also has its own README and DocC landing page under
`Packages/<PackageName>/`.

## Contributing And Support

Start with the [docs](docs) and
[Troubleshooting](docs/app/Troubleshooting.md).
Use [Discussions Q&A](https://github.com/tdeverx/contained-app/discussions/categories/q-a)
for setup help and questions, and
[open an issue](https://github.com/tdeverx/contained-app/issues/new/choose) for
actionable bugs, crashes, regressions, or tracked feature work.

Please read the [contributing guide](docs/development/Contributing.md)
before opening a larger PR. Do not post vulnerabilities publicly; use
[private vulnerability reporting](https://github.com/tdeverx/contained-app/security/advisories/new)
instead.

## Architecture

The root package contains the app launcher and app implementation, then consumes
standalone local packages:

- [`ContainedCore`](Packages/ContainedCore/README.md): pure models, runtime-neutral create/recreate request fields, Apple `container` argv builders, decoders, compose parsing, metric normalization, and package error metadata.
- [`ContainedRuntime`](Packages/ContainedRuntime/README.md): shared runtime contracts, descriptors, capabilities, translation plans, command errors, and command execution primitives.
- [`AppleContainerRuntime`](Packages/AppleContainerRuntime/README.md): the current Apple `container` adapter, including translation from shared create/import models to Apple CLI commands. Future Docker-compatible, Podman, Lima-backed, remote, or other runtime engines should be sibling adapter packages.
- [`ContainedDesignSystem`](Packages/ContainedDesignSystem/README.md): reusable SwiftUI/AppKit visual primitives, tokens, spacing, material, cards, panels, controls, feedback, and data visualization.
- [`ContainedNavigation`](Packages/ContainedNavigation/README.md): reusable safe-area, morphing, measurement, and panel-host infrastructure.
- [`ContainedPreviewSupport`](Packages/ContainedPreviewSupport/README.md): deterministic fixtures for package examples and SwiftUI previews.
- `ContainedApp`: SwiftUI app shell, navigation, feature views, stores, history, settings, Sparkle support, app state migration, app-specific presentation mappings, and localization.
- `Contained`: tiny SwiftPM executable launcher used by command-line builds and bundle scripts.

Integration is intentionally CLI-based rather than private-framework based. Personalization and app-managed metadata stay local to Contained so the user's container resources remain clean when used directly from the terminal.
Reusable packages expose display-neutral errors with stable package codes/context; the app owns localized messages, alerts, and Activity history presentation.

## License

Contained is source-available and free for non-commercial use under the [PolyForm Noncommercial License 1.0.0](LICENSE). The Contained name and branding are reserved; see [NOTICE](NOTICE).
