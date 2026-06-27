<p align="center">
  <img src=".github/assets/icon.png" width="128" alt="Contained icon">
</p>

<h1 align="center">Contained</h1>

A native, SwiftUI-first macOS app for Apple's [`container`](https://github.com/apple/container) CLI — a Liquid Glass control surface for running, customizing, and inspecting Linux containers on Apple silicon. It covers the everyday Docker-Desktop workflow plus the broader `container` command surface, without leaving the Mac-native look and feel.

<p align="center">
  <img src=".github/assets/screenshot.png" width="900" alt="Contained — running containers and the Run a Container sheet">
  <br><sub><i>Work in progress — the UI and features are still evolving.</i></sub>
</p>

> **Status:** feature-complete, polishing toward 1.0. Every section below is implemented; see the [1.0 Polish Checklist](#10-polish-checklist) for the per-screen pass that remains before tagging a stable release.

## Highlights

- **Grid of glass cards** — each container is a clear Liquid Glass card with a customizable tint, gradient, icon, nickname, an app-managed health badge, and a selectable live sparkline (CPU / memory / network / disk).
- **Full lifecycle + 7 detail tabs** — start/stop/restart, plus Overview, Logs, Terminal (SwiftTerm), Stats, History, Files, and Inspect for each container.
- **Images, Build, Volumes, Networks, Registries, System** — pull (with Docker Hub search), build (streamed BuildKit log), tag/push/save/load, filesystem export, volume/network CRUD, registry login, service control, `df`, a Prune Center, and guarded kernel/DNS management.
- **Templates & Compose import** — a library of saved run recipes plus built-in starters, and `compose.yaml` import that opens editable, prefilled Run forms for each service.
- **One Edit form** — progressive-disclosure mapping of the `container run` flags with host-bounded CPU/RAM controls and a live "reveal the CLI" preview.
- **Persistent history** — SwiftData-backed events and metrics power a per-container History tab and a system-wide Activity view (Swift Charts), with configurable retention.
- **App-managed restart & healthchecks** — `container` has no native `--restart` or healthcheck, so Contained runs both itself.
- **Mac-native throughout** — `NavigationSplitView`, the system search field, a section-aware Liquid Glass toolbar, a command palette (⌘K), a menu-bar extra, full keyboard shortcuts, and accessibility (Reduce Transparency / Reduce Motion / VoiceOver). AppKit bridges are used only where SwiftUI has no equivalent, and are flagged in the source.

## Install & updates

Download the latest `.dmg` from [Releases](https://github.com/tdeverx/contained-app/releases). Updates are delivered in-app via [Sparkle](https://sparkle-project.org) across three channels, selectable in Settings → Updates:

- **Stable** — finished releases.
- **Beta** — pre-release builds, ahead of stable.
- **Nightly** — the latest build from every commit (CI), bleeding edge.

Channels are cumulative (Nightly still receives Beta and Stable). See the [Release runbook](https://github.com/tdeverx/contained-app/wiki/Release) for the maintainer signing/notarization flow.

## Documentation

Full docs live in the **[wiki](https://github.com/tdeverx/contained-app/wiki)** — [Features](https://github.com/tdeverx/contained-app/wiki/Features) · [Run / Edit Form](https://github.com/tdeverx/contained-app/wiki/Run-Edit-Form) · [Keyboard Shortcuts](https://github.com/tdeverx/contained-app/wiki/Keyboard-Shortcuts) · [Installation](https://github.com/tdeverx/contained-app/wiki/Installation) · [Troubleshooting](https://github.com/tdeverx/contained-app/wiki/Troubleshooting) · [Architecture](https://github.com/tdeverx/contained-app/wiki/Architecture) · [Contributing](https://github.com/tdeverx/contained-app/wiki/Contributing).

## Requirements

- macOS 26 or later (Apple silicon)
- Xcode 26 / Swift 6.2+
- Apple's `container` CLI **1.0.0** installed and on `PATH` ([install](https://github.com/apple/container))

## Build & run

This is a Swift Package — open it directly in Xcode (there is no `.xcodeproj`):

```sh
open Package.swift        # opens the package as a project in Xcode
```

Or from the command line:

```sh
swift build               # compile
swift test                # run the unit tests
./scripts/bundle.sh       # assemble a runnable Contained.app
open Contained.app        # launch it
```

## Architecture

The package splits into two targets so all logic is testable without a UI:

- **`ContainedCore`** (library) — models, the `container` CLI wrapper (`--format json`), lenient decoders grounded against captured real CLI output, and command builders. No UI.
- **`Contained`** (executable) — the SwiftUI app: design system, stores (`@Observable` + `@MainActor`), feature views, and the SwiftData history store.

Integration is by **shelling out** to the `container` CLI and decoding its JSON, rather than linking a private framework — robust across CLI updates and easy to verify. Personalization (tint, icon, nickname, background) is stored **locally** (image-keyed defaults + per-container overrides) and never written back as container labels, keeping the CLI clean. Full design notes in the [Architecture](https://github.com/tdeverx/contained-app/wiki/Architecture) wiki page.

```
Sources/
  ContainedCore/   Models, Services (CLI wrapper), decoding
  Contained/       App, DesignSystem, Features, Navigation, Stores, History, Support
Tests/
  ContainedCoreTests/   Decoding + command-builder tests against real CLI fixtures
  ContainedAppTests/    RunSpec argv + compose-mapping golden tests
scripts/
  bundle.sh        Build + assemble Contained.app
  release.sh       Sign + notarize + DMG (maintainers)
  appcast.sh       Generate this branch's Sparkle appcast
appcast.xml        Per-branch Sparkle feed (nightly/beta/main each own one; human docs live in the wiki)
```

## 1.0 Polish Checklist

Every screen gets the same pass before tagging 1.0. Criteria per page: **G** Liquid Glass consistency · **S** empty / loading / error states · **A** keyboard + VoiceOver accessibility · **C** Reveal-CLI on privileged actions · **L** copy / labels / info-popovers · **R** responsive layout.

| Screen | G | S | A | C | L | R |
|---|---|---|---|---|---|---|
| Containers (grid) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Container Detail · Overview | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Container Detail · Logs | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Container Detail · Terminal | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Container Detail · Stats | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Container Detail · History | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Container Detail · Files | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Container Detail · Inspect | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Images | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Build | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Volumes | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Networks | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Registries | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| System | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| System · Activity | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Templates | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Compose import | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Edit / Run form | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Customize sheet | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Settings | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Onboarding / Bootstrap | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Command Palette | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Menu-bar extra | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

## Contributing

Forks, issues, and pull requests are welcome — see [Contributing](https://github.com/tdeverx/contained-app/wiki/Contributing). The project is built for collaboration; the only thing off the table is commercial use (see License).

## License

**Source-available, free for non-commercial use.** Contained is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE) — use, modify, fork, and share it freely for any noncommercial purpose; commercial use of any kind is not permitted. This is intentionally *not* the OSI "Open Source" label (that definition forbids restricting commercial use), but in plain terms the code is open, free, and collaborative. The "Contained" name and branding are reserved — see [NOTICE](NOTICE).
