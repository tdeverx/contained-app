# Contained

A native, SwiftUI-first macOS app for Apple's [`container`](https://github.com/apple/container) CLI — a Liquid Glass control surface for running, customizing, and inspecting Linux containers on Apple silicon. It covers the everyday Docker-Desktop workflow plus the broader `container` command surface, without leaving the Mac-native look and feel.

## Quick start

```sh
git clone https://github.com/tdeverx/contained-app.git
cd contained-app
swift build && swift test
./scripts/bundle.sh debug
open Contained.app
```

Prefer a prebuilt app? Grab the latest `.dmg` from [Releases](https://github.com/tdeverx/contained-app/releases). Full details on [[Installation]].

## What's inside

- **Containers** — a grid of personalized Liquid Glass cards with live sparklines, full lifecycle, and a 7-tab detail (Overview, Logs, Terminal, Stats, History, Files, Inspect).
- **Images / Build / Volumes / Networks / Registries / System** — pull (with Docker Hub search), build (streamed BuildKit log), tag/push/save/load, filesystem export, volume & network CRUD, registry login, service control, `df`, a Prune Center, and guarded kernel/DNS management.
- **Templates & Compose import** — saved run recipes + built-in starters, and `compose.yaml` import that opens editable, prefilled Run forms for each service.
- **Persistent history** — SwiftData-backed events and metrics powering a per-container History tab and a system-wide Activity view (Swift Charts).
- **App-managed restart & healthchecks** — `container` has no native `--restart` or healthcheck; Contained runs both itself.

See the full tour on [[Features]].

## Pages

### Start here

- **[[Features]]** — overview and links into each feature area
- **[[Installation]]** — requirements, install, build from source, updates
- **[[Keyboard Shortcuts|Keyboard-Shortcuts]]** — shortcut gates and current bindings
- **[[Troubleshooting]]** — common issues and fixes

### Workflows

- **[[Creation Workflow|Creation-Workflow]]** — the shared create/edit/search/build front door
- **[[Run / Edit Form|Run-Edit-Form]]** — UI-first mapping of `container run` flags
- **[[Compose Import|Compose-Import]]** — compose-to-run-form behavior
- **[[Command Palette|Command-Palette]]** — the app-wide command index and palette rules
- **[[Updates]]** — app updates, image updates, channels, and release notes

### Feature areas

- **[[Containers|Features-Containers]]**
- **[[Images|Features-Images]]**
- **[[Resources|Features-Resources]]**
- **[[System & Settings|System-Settings]]**

### Maintainers

- **[[Architecture]]** — how the CLI wrapper, stores, and design system fit together
- **[[Design System|Design-System]]** — shared Liquid Glass components and layout rules
- **[[Contributing]]** — layout, conventions, and the pre-PR checklist
- **[[Release]]** — the maintainer signing / notarization / appcast runbook

## Updates

Updates ship in-app via [Sparkle](https://sparkle-project.org) across three independent branch feeds, selectable in **Settings → Updates**:

| Channel | What you get |
| --- | --- |
| **Stable** | Finished releases. |
| **Beta** | Pre-release builds, ahead of stable. |
| **Nightly** | The latest build from every commit (CI). Bleeding edge. **(default while pre-1.0)** |

The classic sidebar shell is the default. Toolbar-first UI, toolbar panel navigation, command palette, Docker Hub search, Compose import, image build workspace, and keyboard shortcuts are opt-in from **Settings → Experimental**.

## License

**Source-available, free for non-commercial use** under the [PolyForm Noncommercial License 1.0.0](https://github.com/tdeverx/contained-app/blob/main/LICENSE). Forks, issues, and pull requests are welcome — the only thing off the table is commercial use.
