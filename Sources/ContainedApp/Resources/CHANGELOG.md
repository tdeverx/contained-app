# Changelog

## [Unreleased]

## [1.0.0] - Initial macOS Container Control Surface

### Highlights

- First complete Contained release: a native macOS 26 SwiftUI control surface for Apple's `container` CLI.
- Classic sidebar navigation is the default experience. The Liquid Glass toolbar, morph panels, command palette, Docker Hub search, Compose import, image build workspace, and keyboard shortcuts are available as explicit experimental features.
- Contained stays CLI-first: privileged runtime work goes through Apple's `container` command, run/edit operations can reveal the generated `container ...` command, and decorative app metadata stays local to Contained.
- Built-in Sparkle updates support Stable, Beta, and Nightly channels, with fresh pre-1.0 installs defaulting to Nightly so testers receive current builds.

### App & Navigation

- Full-page macOS app shell for Containers, Images, Build, Volumes, Networks, System, Templates, Activity, and Settings.
- Optional menu-bar app with service health, unread Activity count, update checks, quick actions, and navigation back into the main window.
- Shared presentation model for sidebar, menus, menu-bar actions, toolbar panels, sheets, and command-palette routes.
- Toolbar-aware safe areas and page filters so experimental toolbar chrome does not cover classic sidebar content or expanded cards.
- Keyboard shortcuts for common navigation, search, settings, creation, update, activity, and palette actions when the experimental gate is enabled.

### Containers & Creation

- Container grid with Liquid Glass cards, lifecycle actions, status, image, command, resource highlights, context menus, and full-card hit targets.
- Grouping, sorting, and running-only filters for containers by network, volume, image, or flat list.
- Expanded container tabs for Overview, Logs, Terminal, Stats, History, and Files, including live/follow logs, SwiftTerm terminal access, file browsing/copy workflows, and per-container metric history.
- Shared Run/Edit form for new containers and recreate/edit flows, with validation, image pre-pull, inline errors, app-managed options, and exact CLI preview.
- Compose import from paste, file picker, drag-and-drop, menu command, or command palette action, translating services into editable run forms instead of launching opaque stacks.
- Compose translation for image, platform, command, entrypoint, ports, volumes, env files, network mode, restart policy, health checks, working directory, user, capabilities, DNS, tmpfs, and ulimits, with warnings for unsupported shapes.
- Template storage for reusable run configurations using the same Run/Edit form as other creation paths.
- App-managed restart policies and health checks for behavior Apple's `container` CLI does not provide natively.

### Images, Resources & Registries

- Local image and tag browsing with grouped references, run actions, history pages, tagging, pushing, saving archives, loading OCI `.tar` archives, pruning, and update status.
- Image update checks based on local and remote digests, surfaced on image cards, container cards, toolbar panels, System, and command palette entries.
- Manual and scheduled image update checks, including "check all", "pull all available image updates", and container-image specific sweeps.
- Experimental Docker Hub search that can hand selected results into the run configuration flow.
- Experimental image build workspace for Dockerfile/context builds with streamed BuildKit output.
- Volume and network browsing, creation, deletion, prune actions, local styling, and mount/network-aware container grouping.
- Registry credential management in Settings, including login/logout with passwords piped through `--password-stdin` rather than process arguments.

### System, Settings & Activity

- Bootstrap states for missing CLI, unsupported CLI version, stopped service, and ready service.
- System page for engine/service state, resource usage, background work, volume inventory, runtime defaults, system logs, and prune/service lifecycle actions.
- Settings tabs for General, Appearance, Runtime, Registries, Experimental, Updates, and About.
- Configurable appearance, tint, materials, card density, menu-bar behavior, CLI previews, info tips, logging, update cadence, image update cadence, and experimental feature gates.
- Activity history for lifecycle, image, compose, system, registry, pull, build, watchdog, healthcheck, alert, and UI events, including unread state, filtering, copy/delete actions, and clear controls.
- Versioned `.containedbackup` export/import for settings, personalization, health checks, templates, and activity history, with per-category selection and merge/replace behavior.
- Rollback guard for local data created by newer app schemas, including export-before-reset and best-effort keep-readable-data paths.

### Personalization & Accessibility

- Local-only personalization for containers, image groups, image tags, and volumes, including nickname, icon, tint, background, graph/widget choices, and inheritance from image or app defaults.
- CPU, memory, network, and disk widgets with configurable graph style, interpolation, tint, and normalization choices.
- Accessibility-aware visual effects and motion handling, including Reduce Transparency and Reduce Motion support where Contained supplies custom glass or animation.

### Reliability & Performance

- Shared refresh coordination for service/list refreshes, lifecycle actions, image list refreshes, disk usage refreshes, and image-update checks to avoid unnecessary CLI process churn.
- One app-wide low-priority stats stream for running containers, with narrower per-container metric invalidation and lazy long panels.
- Chronological sparkline windows, fixed CPU/memory percentage scales, raw network/disk throughput shapes, configurable CPU/memory normalization, and clearer sub-1% readouts.
- Deferred heavyweight expanded-card pages, cached style/tag lookups, and coalesced image refreshes so navigation and customization stay responsive.
- Hardened terminal teardown so rapid card or tab switching cleans up `container exec --tty` children.
- Compose import preserves user control by opening editable run forms and reporting unsupported values rather than silently guessing.
- App-managed restart and health flows suppress user-initiated stops where appropriate and avoid uncontrolled restart loops.

### Architecture & Release

- Package-first SwiftPM layout with `ContainedCore` for backend orchestration, `ContainedUI` for visual primitives, `ContainedUX` for interaction infrastructure, `ContainedApp` for app-owned SwiftUI/persistence/localization policy, and a tiny `Contained` executable launcher.
- `Core.Orchestrator` is the app-facing backend boundary; Core owns runtime descriptors, command previews, Apple `container` adapter internals, typed async runtime methods, Compose/image-default translation, and typed stats streams.
- Core-published run/edit schema documents own editable runtime fields, schema conformance, validation, source aliases, disabled runtime explanations, command previews, and execution mapping.
- `AppModel`, focused stores, `UIState`, and toolbar option enums centralize bootstrap, navigation, refresh coordination, image updates, settings, resource styles, filters, and fallback routing.
- SwiftData-backed history records events, metric samples, and templates with bounded retention and backup/import support.
- Checked-in Xcode workspace and native macOS app target build and run `Contained.app` directly while SwiftPM remains the CI, release, packaging, signing, notarization, and appcast source of truth.
- Release scripts centralize version/build derivation, retain promoted nightly build numbers for beta/stable, compose channel-specific and full-version release notes, generate Sparkle appcast HTML, and keep the bundled changelog resource in sync.
- Repository validation covers script strict mode and headers, workflow path filters, docs indexes, wiki mapping, package-boundary imports, app adapter internals, stale names, raw token use, empty source/docs folders, release-note composition, and bundled changelog sync.

### Migration Notes

- Saved local container, image, and volume styles are kept in local app storage.
- Local settings, personalization, health checks, templates, and activity history can be exported before resetting data created by a newer app schema.
- Activity events created before unread tracking are treated as unread on first launch.
