# Features

## Containers
- Grid of personalized Liquid Glass cards with a live sparkline (CPU/memory/network/disk).
- Lifecycle: start / stop / restart / delete; multi-tab detail (Overview, Logs, Terminal, Stats, History, Files, Inspect).
- **Edit** form (create or edit-in-place): full `container run` mapping incl. an Advanced section (workdir, user/uid/gid, cap-add/drop, DNS, tmpfs, shm-size, ulimit), host-bounded CPU picker + memory slider, and a live "Reveal CLI" preview.
- **Customize** a card's style (per-container or per-image), stored locally.
- **Healthcheck** (app-managed): an `exec` probe on an interval; a heart badge flips red when unhealthy.

## Images
- List / inspect / run / tag / push / delete / prune / history.
- Pull with live progress + **Docker Hub search**.
- **Save** to a tar archive and **load** from one (also via drag-and-drop).

## Build
- Build workspace: context + Dockerfile + tags + build-args, streamed BuildKit log.

## Volumes / Networks / Registries
- Create + delete volumes and networks; registry login (`--password-stdin`) / logout.

## System
- Service status + start/stop/restart, `system df`, a Prune Center, daemon properties, and a system-logs viewer.
- **Kernel & DNS** (privileged): install the recommended kernel; create/list/delete local DNS domains (may prompt for an admin password, handled by the CLI).
- **Activity** — the persistent event log across all containers.

## Stacks & Templates
- Import a `compose.yaml` (drag-and-drop too); launch in dependency order with `service_healthy` gating.
- Templates library: built-in starters + your saved run recipes.

## Command Palette
- ⌘K fuzzy palette to jump to any section, run a container, or fire common actions from the keyboard.

## Menu bar
- **Menu-bar extra** — a status item showing the running count with quick lifecycle actions; toggle in Settings.
- **App menus** — File (New Container ⌘N, Pull Image, Import Compose), Edit (Find ⌘F focuses search), View (toggle sidebar, Reload ⌘⇧R, Card Size, Show Running Only), Go (⌘1–8 sections), and Help (web docs, issues, source, Reveal CLI binary). About and Check for Updates live in the app menu.

## Settings
- **Appearance** — theme (system/light/dark), accent tint, card size, window backdrop, reduce translucency.
- **General** — launch at login, keep in menu bar, crash notifications, Reveal-CLI gate, refresh interval, history retention + Clear History, CLI path override.
- **Updates** — channel picker (Stable / Beta / Nightly), automatic checks, Check for Updates.
- **About** — app icon, version, runtime versions, copyright.

## Onboarding
- **Bootstrap** screen shown until the `container` service is reachable: detects the CLI, surfaces install/start guidance, and starts the service.

## Throughout
- Persistent SwiftData history (events + metrics) with a per-container History tab and a system-wide Activity view.
- Crash/restart and unhealthy notifications, light/dark + accent theming, and accessibility (Reduce Transparency / Reduce Motion / VoiceOver labels on every icon-only control).
