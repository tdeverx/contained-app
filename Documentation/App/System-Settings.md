# System & Settings

System and Settings own runtime status, app preferences, update controls,
experimental gates, registries, and local data management.

## System

The System panel surfaces runtime status, runtime details, resource usage,
image update status, and app/runtime actions.

Runtime controls are rendered from descriptor capabilities. Apple container
currently exposes service lifecycle, kernel, and DNS controls; future runtimes
can expose their own endpoint or management sections without becoming a global
default runtime. Docker adapter groundwork exists in Core but is dormant, so
Docker runtime controls are not shown until Contained has a provider model that
does not depend on Docker Desktop. Privileged kernel or DNS operations may
trigger prompts handled by the CLI or macOS. Contained does not ask for or store
administrator credentials.

## Menu-bar runtime center

The optional menu-bar extra is the compact companion to System. It shows one
card per detected runtime with reachability, CLI version, running and stopped
container counts, image count, and capability-scoped start, stop, restart, or
retry controls. The card's System action opens the full management surface.
Run, Activity, and update checks remain available as focused quick actions;
creation, navigation, settings, and support workflows stay in the main app.

## Settings tabs

Settings tabs use native grouped SwiftUI forms inside the shared Settings panel.
Editable rows use the same label-state rules as Run/Edit: red means that row has
a specific issue, and blue means the setting differs from the shipped default.

- General: app behavior, menu bar, CLI previews, metric normalization, info tips, and related defaults.
- Appearance: tint, material, card, panel, and theme choices.
- Data: backup/export/import and local state controls.
- Runtime: runtime reachability, runtime path overrides, and capability-scoped service/kernel/DNS or endpoint controls.
- Registries: registry login/logout and credential management.
- Updates: app channel, Sparkle checks, release notes, and image update cadence.
- Experimental: opt-in feature gates.
- About: app and runtime information.

## Experimental gates

Experimental features default off:

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
