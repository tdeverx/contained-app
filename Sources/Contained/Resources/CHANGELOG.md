# Changelog

## [1.0.0] - Update Infrastructure and Sidebar Fallback

### Added

- Versioned `.containedbackup` export/import for settings, personalization, health checks, templates, and activity history, with per-category selection.
- Rollback guard for data created by newer app schemas, including an export-before-reset path and a best-effort keep-readable-data option.
- Sparkle release notes from `CHANGELOG.md`, with appcast-embedded HTML and in-app “What’s New” views.
- Classic sidebar navigation as the default shell, covering Containers, Images, Volumes, Networks, System, Registries, Templates, Activity, and Settings.
- `Toolbar-first UI` experimental flag, off by default, to restore the floating morph toolbar shell when enabled.
- Menu and menu-bar navigation fallback that routes plus/menu actions directly to the relevant full page instead of opening creation-flow sheets.

### Changed

- Fresh installs default to the Nightly update channel and automatically check for app updates.
- Pre-release build versions such as `1.0.0-nightly.N+sha` resolve release notes from this base `1.0.0` section.
