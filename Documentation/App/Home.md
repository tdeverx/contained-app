# Contained

A native, SwiftUI-first macOS app for Apple's [`container`](https://github.com/apple/container) CLI — a Liquid Glass control surface for running and customizing Linux containers on Apple silicon. It covers the everyday Docker-Desktop workflow plus the broader `container` command surface, without leaving the Mac-native look and feel.

## Quick start

```sh
git clone https://github.com/tdeverx/contained-app.git
cd contained-app
swift build && swift test
./Scripts/package.sh app debug
open Contained.app
```

Prefer a prebuilt app? Grab the latest `.dmg` from [Releases](https://github.com/tdeverx/contained-app/releases). Full details on [Installation](/Documentation/App/Installation.md).

## What's inside

- **Containers** — a grid of personalized Liquid Glass cards with live sparklines, full lifecycle, and a 6-page detail (Overview, Logs, Terminal, Stats, History, Files).
- **Images / Build / Volumes / Networks / Registries / System** — pull (with Docker Hub search), build (streamed BuildKit log), tag/push/save/load, filesystem export, volume & network CRUD, registry login, service control, `df`, a Prune Center, and guarded kernel/DNS management.
- **Templates & Compose import** — saved run recipes + built-in starters, and `compose.yaml` import that opens editable, prefilled Run forms for each service.
- **Persistent history** — SwiftData-backed events and metrics powering a per-container History tab and a system-wide Activity view (Swift Charts). Contained samples while it is running; it does not install a background collector after you quit.
- **App-managed restart & healthchecks** — `container` has no native `--restart` or healthcheck; Contained runs both itself.

See the full tour on [Features](/Documentation/Features/Features.md).

## Pages

### Start here

- **[Features](/Documentation/Features/Features.md)** — overview and links into each feature area
- **[Installation](/Documentation/App/Installation.md)** — requirements, install, build from source, updates
- **[Keyboard Shortcuts](/Documentation/App/Keyboard-Shortcuts.md)** — shortcut gates and current bindings
- **[Troubleshooting](/Documentation/App/Troubleshooting.md)** — common issues and fixes

### Workflows

- **[Creation Workflow](/Documentation/Features/Creation-Workflow.md)** — the shared create/edit/search/build front door
- **[Run / Edit Form](/Documentation/Features/Run-Edit-Form.md)** — UI-first mapping of `container run` flags
- **[Compose Import](/Documentation/Features/Compose-Import.md)** — compose-to-run-form behavior
- **[Command Palette](/Documentation/Features/Command-Palette.md)** — the app-wide command index and palette rules
- **[Updates](/Documentation/App/Updates.md)** — app updates, image updates, channels, and release notes

### Feature areas

- **[Containers](/Documentation/Features/Containers.md)**
- **[Images](/Documentation/Features/Images.md)**
- **[Resources](/Documentation/Features/Resources.md)**
- **[System & Settings](/Documentation/App/System-Settings.md)**

### Maintainers

- **[Architecture](/Documentation/Architecture/Architecture.md)** — how the CLI wrapper, stores, and design system fit together
- **[Design System](/Documentation/Architecture/Design-System.md)** — shared Liquid Glass components and layout rules
- **[Contributing](/Documentation/Development/Contributing.md)** — layout, conventions, and the pre-PR checklist
- **[Release](/Documentation/Release/Release.md)** — the maintainer signing / notarization / appcast runbook

## Updates

Updates ship in-app via [Sparkle](https://sparkle-project.org) across three independent branch feeds, selectable in **Settings → Updates**:

| Channel | What you get |
| --- | --- |
| **Stable** | Finished releases. |
| **Beta** | Pre-release builds, ahead of stable. |
| **Nightly** | The latest build from every commit (CI). Bleeding edge. **(default while pre-1.0)** |

The permanent toolbar switches resource pages and opens focused panels for System,
Templates, Activity, Settings, and creation workflows. Command palette, Docker Hub
search, Compose import, image build workspace, and keyboard shortcuts are opt-in
from **Settings → Experimental**.

## License

**Source-available, free for non-commercial use** under the [PolyForm Noncommercial License 1.0.0](https://github.com/tdeverx/contained-app/blob/main/LICENSE). Forks, issues, and pull requests are welcome — the only thing off the table is commercial use.
