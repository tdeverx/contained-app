# System & Settings

System and Settings own runtime status, app preferences, update controls,
experimental gates, registries, and local data management.

## System

The System page surfaces service status, runtime details, resource usage, image
update status, and app/runtime actions. System content is shared between the
classic sidebar page and toolbar morph panel when the experimental toolbar UI is
enabled.

Privileged kernel or DNS operations may trigger prompts handled by the CLI or
macOS. Contained does not ask for or store administrator credentials.

## Settings tabs

- General: app behavior, menu bar, CLI previews, info tips, and related defaults.
- Appearance: tint, material, card, panel, and theme choices.
- Data: backup/export/import and local state controls.
- Runtime: CLI path and runtime defaults.
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
