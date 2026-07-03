# System & Settings

System and Settings own runtime status, app preferences, update controls,
experimental gates, registries, and local data management.

## System

The System page surfaces runtime status, runtime details, resource usage,
image update status, and app/runtime actions. System content is shared between
the classic sidebar page and toolbar morph panel when the experimental toolbar
UI is enabled.

Apple container exposes service lifecycle, kernel, and DNS controls. Docker is
reached through the Docker CLI and its configured endpoint, so Contained shows
retry/runtime guidance instead of trying to start Docker Desktop or another
external daemon. Privileged kernel or DNS operations may trigger prompts handled
by the CLI or macOS. Contained does not ask for or store administrator
credentials.

## Settings tabs

- General: app behavior, menu bar, CLI previews, metric normalization, info tips, and related defaults.
- Appearance: tint, material, card, panel, and theme choices.
- Data: backup/export/import and local state controls.
- Runtime: runtime reachability, Apple `container` and Docker CLI path overrides, Apple-only service/kernel/DNS controls, and Docker endpoint guidance.
- Registries: registry login/logout and credential management.
- Updates: app channel, Sparkle checks, release notes, and image update cadence.
- Experimental: opt-in feature gates.
- About: app and runtime information.

## Experimental gates

Experimental features default off:

- Toolbar-first UI
- Toolbar panel navigation
- Sidebar navigation
- Command palette
- Docker Hub search
- Compose import
- Image build workspace
- Keyboard shortcuts

Each gate hides or disables the matching menu commands, toolbar affordances, and
creation entry points where applicable.

## Local data

Contained stores settings, personalization, templates, health checks, activity
history, image update status, and backups locally. Versioned backup and migration
envelopes protect data created by newer app schema versions.

## Metric normalization

Settings -> General -> Data -> Normalize stats controls how CPU and memory
percentages are scaled across cards, live stats, mini chips, widgets, and
history charts:

- Container: each container card is scaled against that container's configured
  CPU and memory limits.
- Machine: every card is scaled against the available runtime machine CPU and
  memory resources when available, so container usage appears in runtime-wide
  context.

Network and disk widgets remain raw bytes-per-second rates in both modes.
History keeps raw samples on disk and applies the selected normalization mode
when rendering charts, so older samples remain usable if the mode changes.

The neighboring **List refresh interval** setting controls background service,
container list, and resource-cache polling. Live metric widgets use their own
low-priority runtime stream instead of this interval.
