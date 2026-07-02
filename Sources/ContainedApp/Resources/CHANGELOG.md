# Changelog

## [Unreleased]

## [1.0.0] - Initial macOS Container Control Surface

### Highlights

- First complete Contained release: a native macOS 26 SwiftUI control surface for Apple's `container` CLI, built around local containers, images, volumes, networks, registries, system status, templates, activity history, and app-managed workflow state.
- The default experience is a classic macOS sidebar shell; the floating Liquid Glass toolbar, morph panels, command palette, Docker Hub search, Compose import, image build workspace, and keyboard shortcuts are available behind explicit experimental gates.
- Contained stays CLI-first: privileged runtime operations are handled by Apple's `container` command, generated `container ...` arguments can be revealed before run/edit operations, and local app metadata is kept out of container resources unless it is required for behavior.

### Added

#### App Shell & Navigation

- Classic sidebar navigation with full-page destinations for Containers, Images, Build, Volumes, Networks, System, Templates, Activity, and Settings.
- Optional menu-bar app with service health, unread Activity count, quick actions, update checks, and navigation into the main app.
- Menu and menu-bar navigation fallback that routes create, image, system, activity, registry, and settings actions through the same presentation model as the sidebar.
- Experimental toolbar-first UI with top/bottom Liquid Glass toolbar bands, measured detail-column safe areas, morph panels, contextual page actions, and bottom page filters.
- Experimental toolbar panel navigation setting so toolbar actions can open morph panels or fall back to classic pages and sheets.
- Experimental keyboard shortcuts for sidebar/search/settings/create/update/activity/palette actions.

#### Containers

- Container grid with personalized Liquid Glass cards, lifecycle actions, status, image, command, resource highlights, full-card hit targets, and context menus.
- Container grouping by Network, Volume, Image, or Flat list, with sort and running-only filtering in shared toolbar controls.
- Expanded container detail tabs for Overview, Logs, Terminal, Stats, History, and Files.
- Live logs, one-shot and follow modes, terminal access through SwiftTerm, file browsing/copy workflows, and per-container metrics history.
- Shared Run/Edit form for new containers and recreate/edit flows, with validation, image pre-pull, inline errors, and an exact CLI preview.
- App-managed restart policies and health checks for behavior Apple's `container` CLI does not provide natively.
- Container image update checks that can pull newer image tags and reopen the edit flow without automatically replacing the running container.

#### Images

- Local image and tag browsing with grouped references, run actions, history pages, tagging, pushing, saving archives, loading OCI `.tar` archives, pruning, and update status.
- Registry image search flow for Docker Hub, gated behind Settings -> Experimental, with selected results handed into the run configuration flow.
- Image update detection based on local and remote digests, surfaced on image cards, container cards, toolbar panels, System, and command palette entries.
- Manual and scheduled image update checks, including "check all", "pull all available image updates", and container-image specific sweeps.
- Experimental image build workspace for Dockerfile/context builds with streamed BuildKit output.

#### Creation, Compose & Templates

- Shared creation flow for running containers, editing containers, choosing local images, searching registry images, importing Compose, loading image archives, creating networks, creating volumes, and building images.
- Run/Edit form organized as native macOS sections for Essentials, Resources, Networking, Storage, Environment, App Managed, Appearance, and Advanced Options.
- Structured controls for bounded CLI flags, repeatable rows for lists, and free-form fields where the CLI accepts arbitrary values.
- Compose import from paste, file picker, drag-and-drop, menu command, or command palette action, translating services into editable run forms instead of launching opaque stacks.
- Compose translations for image, platform, command, entrypoint, ports, volumes, env files, network mode, restart policy, health checks, working directory, user, capabilities, DNS, tmpfs, and ulimits, with warnings for unsupported shapes.
- Template storage for reusable run configurations, using the same Run/Edit form as other creation paths.

#### Resources & Registries

- Volume browsing, creation, deletion, prune actions, local card styling, and mount-aware container grouping.
- Network browsing, creation, deletion, prune actions, and network-aware container grouping.
- Registry credential management in Settings -> Registries, including login/logout with passwords piped through `--password-stdin` rather than process arguments.
- Activity history for lifecycle, image, compose, system, registry, pull, build, watchdog, healthcheck, alert, and UI events, including unread state, filtering, copy/delete actions, and clear controls.

#### System & Settings

- Onboarding/bootstrap states for missing CLI, unsupported CLI version, stopped service, and ready service.
- System page covering engine/service state, resource usage, background work, volumes, runtime defaults, system logs, and prune/service lifecycle actions.
- Settings tabs for General, Appearance, Runtime, Registries, Experimental, Updates, and About.
- Configurable appearance, tint, materials, card density, card material, panel material, button tint, menu-bar behavior, CLI previews, info tips, logging, update cadence, image update cadence, and experimental feature gates.
- Versioned `.containedbackup` export/import for settings, personalization, health checks, templates, and activity history, with per-category selection and merge/replace import behavior.
- Rollback guard for local data created by newer app schemas, including export-before-reset and best-effort keep-readable-data paths.
- Sparkle app updates with Stable, Beta, and Nightly channels plus in-app "What's New" views for current and available builds.

#### Personalization & Design System

- Local-only personalization for containers, image groups, image tags, and volumes, including nickname, icon, tint, background, graph/widget choices, and inheritance from image or app defaults.
- Shared Liquid Glass design system primitives: `DesignCardSurface`, `GlassSurface`, `GlassButton`, `GlassOptionTile`, `DesignPanelScaffold`, `PanelHeader`, `PanelSection`, `PanelRow`, `PanelField`, `CommandPreviewBar`, `InfoButton`, `TintSelector`, `StreamConsole`, `ActivityStatusView`, and toolbar controls.
- Accessibility-aware custom visual effects and motion handling, including Reduce Transparency and Reduce Motion support where the app supplies custom glass or animation.
- Shared page and panel scaffolds so sidebar pages, sheets, and toolbar morphs can reuse content without duplicate layouts.

### Changed

- Fresh installs default to the Nightly update channel and automatically check for app updates during pre-1.0 development.
- Registries live under Settings instead of a standalone app page, while registry actions remain discoverable through menus and the command palette.
- Local card personalization is stored in Contained's own state instead of being written back as decorative container labels.
- Container refresh, lifecycle actions, image list refreshes, disk usage refreshes, and image-update checks are throttled or serialized to avoid unnecessary CLI process churn and UI re-render storms.
- Background work uses a shared refresh coordinator, restart watchdog, health monitor, history store, and logger instead of page-local polling.
- Each release workflow publishes GitHub release notes and Sparkle appcast notes from the same release-note source.
- Pre-release build versions such as `1.0.0-nightly.N+sha` resolve full release notes from the matching base `1.0.0` section.

### Fixed

- Sidebar layouts are no longer padded or covered by custom toolbar chrome because toolbar safe-area measurement is scoped to the detail column.
- Page and expanded-card layouts account for toolbar bands only where the experimental toolbar is visible.
- Container lifecycle actions and background polling no longer race the shared container list/stats dictionaries during start/stop/restart transitions.
- Compose import preserves user control by opening editable run forms and reporting unsupported values rather than silently guessing.
- App-managed restart and health flows suppress user-initiated stops where appropriate and avoid uncontrolled restart loops.
- Registry login avoids leaking passwords in argv.

### Technical

- Swift Package layout with a pure `ContainedCore` library for CLI command builders, JSON models, compose parsing, decision helpers, and service logic, plus a `Contained` SwiftUI executable for UI, stores, Sparkle, SwiftData, and migration.
- `ContainerCommands` is the single source of truth for `container` argv construction and is covered by golden tests.
- `ContainedRuntime` defines the shared runtime contract, while `AppleContainerRuntime` exposes typed async methods over real `container --format json` output and typed stats streams.
- `RunSpec` is the single source of truth for Run/Edit form state, validation, CLI preview, and actual execution.
- `AppModel` owns bootstrap, client wiring, stores, refresh coordination, image updates, service lifecycle, config transfer, and resource-style lookup through focused extensions.
- `UIState`, `AppSection`, toolbar option enums, and pending actions centralize navigation, filters, morph routing, and classic fallback routing.
- SwiftData-backed `HistoryStore` records events, metric samples, and templates with bounded retention and backup/import support.
- `AppStateEnvelope`, `JSONValue`, `MigrationStep`, and `StateMigrator` provide the baseline for forward migration and downgrade handling from schema version 1 onward.
- Release scripts centralize version/build derivation, retain promoted nightly build numbers for beta/stable, compose channel-specific and full-version release notes, generate Sparkle appcast HTML, and keep the bundled changelog resource in sync.

### Migration Notes

- Saved local container, image, and volume styles are preserved and migrated away from legacy decorative `contained.*` labels where possible.
- Local settings, personalization, health checks, templates, and activity history can be exported before resetting data created by a newer app schema.
- Activity events created before unread tracking are treated as unread on first launch.
