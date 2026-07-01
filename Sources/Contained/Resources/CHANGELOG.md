# Changelog

## [Unreleased] - Creation Workflow 10

### Added

#### Toolbar & Navigation Redesign
- **Classic sidebar fallback**: The default app shell is a native sidebar with full-page destinations for Containers, Images, Volumes, Networks, System, Registries, Templates, Activity, and Settings.
- **Toolbar-first architecture**: The floating custom toolbar is now an experimental UI, off by default, while still available from Settings → Experimental.
- **Split toolbar/panel navigation**: toolbar visibility and morph-panel routing are separate experimental toggles, so users can try the custom toolbar while keeping classic page/sheet presentation.
- **Morphing panel system**: When the toolbar UI is enabled, toolbar buttons morph into resizing panels for Images, Templates, Activity, and System resources.
- **Visual command palette**: Integrated `⌘K` search and command palette into the toolbar's expandable search field, with the search bar acting as the panel header
- **Palette action index**: Added global commands for app update checks, all-image update checks, pulling available image updates, checking container-image updates, pulling available container-image updates, local image search, Docker Hub search, and app tint changes
- **Inline palette results**: Container, image group, tag, volume, network, and tint matches render as compact design-system cards instead of generic rows
- **Palette fuzzy search**: Field-aware scoring now handles exact keywords, word initials, separated partials, and small typo/transposition mistakes
- **App-wide toolbar band**: Custom Liquid Glass toolbar proportions (52pt band height, 36pt controls) matching macOS 26 design standards
- **Semantic toolbar sizing**: Button glyphs use Dynamic-Type-scalable `.headline + .imageScale(.large)` for accessibility
- **Toolbar keyboard shortcuts**: `⌘N` (New), `⌘S` (Search), `⌘U` (Updates), `⌘I` (Activity)
- **Container view options**: Bottom toolbar filter control to group the Containers page by Network / Volume / Image / Flat, sort by Name / Status / Image, and toggle running-only.
- **Page actions in the top toolbar**: page-specific actions sit left of search; filters stay in the bottom toolbar when a page has useful filtering.
- **Expanded page filters**: Images, Templates, and Networks now expose bottom-toolbar grouping, sorting, and filtering controls alongside Containers.
- **Toolbar page chrome polish**: the page switcher hides with the sidebar, contextual page actions sit after the page switcher, and creation/image cards use full-card hit targets.
- **Activity unread badge**: The toolbar Activity bell fills and gains an accent + red dot when there are unread events; the panel adds Mark-all-read and Clear controls and highlights unread rows; events mark read on dismiss
- **Reusable activity/status asset** (`ActivityStatusView`): long-running operations (image pulls, etc.) now morph the bottom-left system-status capsule in place instead of a separate floating progress bar

#### Palette search scopes & inline registry search
- **Palette scopes**: Docker Hub and Local-images scope chips pin to the search field and search in-place within the palette (backspace/✕ removes the scope)
- **Inline Docker Hub search**: live, debounced registry results rendered directly in the palette; selecting one opens the prefilled configure flow (pulls on create)
- **Sectioned browse view**: with no query, palette entries are grouped under labelled headings (Navigate, Create & Search, Containers, Images, Volumes & Networks, Settings, Actions)
- **Deduplicated entries**: removed overlapping commands (e.g. "Pull an image" / "Activity history") in favour of scopes and the navigation entries
- **Color name aliases**: tint search matches everyday color names (e.g. "purple" → Indigo, "blue" → Azure, "grey" → Graphite)

#### Experimental features (Settings → Experimental, all off by default)
- **Opt-in gating**: A new Settings → Experimental section gates surfaces that are still being refined. Each defaults **off**; enabling one reveals its menu commands, toolbar affordances, and creation options app-wide
- **Toolbar-first UI**: Gated behind `experimentalToolbarUI` (off by default). When disabled, the app uses the sidebar shell.
- **Toolbar panel navigation**: Gated behind `experimentalPanelNavigation` and effective only when toolbar-first UI is enabled. When disabled, access points use classic pages and sheets.
- **Command palette (⌘K)**: Gated behind `commandPaletteEnabled` (off by default). A render-level backstop in `AppToolbar` keeps it fully hidden regardless of activation path; page search and menu commands are unaffected
- **Docker Hub search**: Gated behind `hubSearchEnabled` — the creation "Search" path, the "Pull Image…" menu commands, and the palette's Hub scope
- **Compose import**: Gated behind `composeImportEnabled` — paste, file pick, drag-and-drop, menu command, and palette entry
- **Image build workspace**: Gated behind `imageBuildEnabled` — the Dockerfile build flow and its menu command

#### Creation & Resource Management
- **Paged creation flow**: Multi-step flow for creating containers, networks, volumes, and building images
- **Unified creation entry point**: File/menu shortcuts, command palette actions, and empty states open the same toolbar add panel at the relevant creation page
- **Compose import UI**: Paste YAML or select compose files; services with images auto-populate the prefill queue
- **Image archive support**: Load OCI image `.tar` files directly into the local store
- **Local image filtering**: Searchable local image list with architecture and size info
- **Template management**: Save and reuse container configurations from anywhere in the creation flow
- **Network & volume creation**: Dedicated creation flows with form validation and inline feedback
- **Image build integration**: Build workspace for Dockerfile-based image creation

#### Design System & Cards
- **ResourceGlassCard component**: Unified card component supporting small/medium/large sizes with configurable elevation
- **GlassOptionTile**: New design-system tile for creation menu options with optional matched geometry
- **MorphingExpander primitive**: Reusable panel grow/collapse animation from origin slot to full screen
- **ExteriorShadow component**: Precise shadow rendering for elevated panels (shadow before blur for correct layering)
- **AppSafeAreaManager**: Intelligent safe area management distinguishing between toolbar-inclusive and toolbar-exclusive layouts, scoped to the detail body so sidebar navigation is unaffected.
- **ToolbarControls**: Centralized toolbar button and cluster components (ToolbarIconButton, ToolbarButtonCluster)

#### Container Customization & Styling
- **Image detail sub-pages**: Inspect, History, Add Tag, and Push grow the image detail morph into in-place sub-pages (back chevron returns to the card) instead of opening modal sheets
- **Image update detection**: Display "Update Container" option when a newer image version is available
- **Enhanced card styling**: Elevated cards with improved glass effects and optional shadows for nested layouts
- **Multi-level personalization**:
  - App-wide default image card design from Settings
  - Image group styling (local image collections)
  - Per-image-tag styling with group inheritance
  - Volume styling with disk read/write metrics
  - Container-level overrides

#### Settings & System Management
- **Runtime settings tab**: View/edit Kernel and DNS settings; read-only Defaults display
- **System resource surfaces**: System info is shared by the sidebar System/Volumes pages and the toolbar morph panel when the experimental toolbar UI is enabled.
- **Registries management**: Credential management consolidated in Settings; global command for registry login
- **Streamlined activity history**: Activity view accessible via toolbar morph and `⌘I`

### Changed

#### UI/UX Improvements
- **Font consistency**: Migrated fixed-point fonts to semantic Dynamic-Type styles (`.headline`, `.body`, `.caption`, etc.)
- **Card density options**: Added `.small`, `.medium`, `.large` (replaced `compact` variant)
- **Window chrome alignment**: Toolbar traffic lights centered with leading inset (80pt) to clear system controls
- **Glass button styling**: Updated icon scales and weights for toolbar cohesion
- **Palette expansion**: Taller header (48pt) and roomier padding when search palette expands
- **ContainerCard refactor**: Extracted form logic into shared `ContainerConfigureView` (used by both sheet and paged flow)
- **Container grid backdrop**: Replaced manual blur/dim with `globalBackdrop` system
- **Palette links respect presentation mode**: commands route through the shared presentation layer, opening morph panels only when toolbar panel navigation is enabled and falling back to pages/sheets otherwise.
- **Contextual toolbar controls**: page-specific toolbar buttons now switch page/subpage state directly instead of opening morph panels.
- **Panel navigation pages**: when toolbar panel navigation is enabled, panel-owned destinations such as System, Activity, and Settings are hidden from page/sidebar navigation.
- **Activity progress relocated**: the floating activity/progress bar was removed in favour of the morphing bottom-left status capsule

#### API & Architecture
- **AppModel methods**: Added `containerStyle(for:)`, `imageStyle(for:)`, `imageGroupStyle(forID:)` for personalization lookup
- **Compose import**: Split into file and text variants (`ComposeImport.importFile()`, `importText()`)
- **Resource refresh**: Added `refreshImagesIfStale(force:)` for lazy image list updates
- **Image update tracking**: New `imageUpdateStatus(for:)` to check available updates

#### Settings & Personalization
- **Personalization storage**: New methods for image group and volume styling
- **Card size persistence**: Migration helper for legacy `compact` → `medium` mapping
- **Activity read state**: `EventRecord` gains an `isRead` flag (lightweight SwiftData migration); events start unread and are marked read when the Activity panel is dismissed

### Fixed

- **Container card animations**: Fixed grow/shrink spring timing for smoother detail panel transitions
- **Safe area calculation**: Custom toolbar bands are measured in the detail column only, with body content padded independently from the sidebar.
- **Page scroll clearance**: Sidebar pages keep native bottom layout while scrollable content gets real interior bottom breathing room for the floating toolbar.
- **Volumes page routing**: the Volumes sidebar page now opens the Volumes view instead of inheriting the System panel's Engine selection.
- **Network page spacing**: Networks now uses the same page interior padding as the other toolbar-era pages.
- **Expanded resource safe areas**: container and image detail expansion now respects both toolbar bands when opened from full pages.
- **Registry navigation**: Registries now live only under Settings → Registries instead of appearing as a standalone app page.
- **Search palette sizing**: Correct max-width constraints and dynamic field scaling
- **Start/stop UI hang**: Container refreshes are now serialized so a user action and the background
  polling tick no longer run `list`+`stats` concurrently (decoding JSON on the main actor and
  stomping the shared stats dictionaries). The grid also only re-renders when the container list
  actually changes, eliminating the per-tick re-render storm during a `.stopping` transition

### Removed

- **Old sidebar implementation**: Replaced with the new `ClassicShell`/`AppSection` sidebar fallback.
- **Old System/Registries/Runtime pages**: Rebuilt as shared page/panel content for the sidebar shell, Settings tabs, and toolbar morphs.
- **Old Network creation**: Previously on a dedicated Networks page; now a creation flow option
- **Legacy card sizes**: Removed `CardDensity.compact` (migrated to `.medium`)
- **Image action sheets**: Removed `TagImageSheet`, `PushImageSheet`, and `ImageHistorySheet` (replaced by image-detail morph sub-pages)

### Technical

- **New components**: `MorphingExpander`, `ResourceGlassCard`, `GlassOptionTile`, `CreationFlow`, `ContainerConfigureView`, `ToolbarControls`, `ExteriorShadow`, `ActivityStatusView`, `ToolbarViewOptions`, `InlineJSONView`
- **New models/state**: `ContainerGrouping`, `ContainerSort`, `PaletteScope`, `EventRecord.isRead`, `SettingsStore.experimentalPanelNavigation`
- **Design tokens**: Added `Tokens.Toolbar` enum for all toolbar sizing and spacing
- **Geometry helpers**: `MorphGeometry` utilities for panel sizing, clamping, and target rect calculation
- **Optional matched geometry**: Helper for conditional `.matchedGeometryEffect()` in tiles
- **Housekeeping pass**: Normalized Customize, registry login, and image build editor surfaces onto
  `PanelSection`/`PanelRow`/`PanelField`; split `CustomizeWidgetsPanel`, `SystemVolumeInventory`,
  `PanelHeader`, `GlassSurface`, `WidgetConfiguration`, `PersonalizationStore`, `SettingsBackup`,
  and toolbar filter/action option files into focused ownership; moved resource-style lookup and
  configuration import/export into `AppModel` extensions; centralized Docker Hub search fetching in
  `HubSearch`.
- **Release workflow hardening**: Centralized version/build derivation in `scripts/version-info.sh`,
  retained promoted nightly build numbers for beta/stable bundles, kept the nightly appcast as a
  superset of nightly plus promoted release items, and composed generated release notes from full
  version notes plus channel-specific change notes for beta/nightly builds.
- **Release-note display alignment**: The bundled in-app What's New view now uses the same composed
  build-changes-first, full-version-notes-second structure as generated Sparkle release notes.
- **1.0 release-note inventory**: Expanded the working `1.0.0` release notes from the full
  app/docs/source scan so Stable, Beta, Nightly, Sparkle, and in-app notes describe the complete
  product surface instead of only the latest infrastructure work.
- **CI validation guardrail**: Added `scripts/ci-validate.sh` for bundled changelog drift, shell
  syntax, workflow YAML syntax, and Stable/Beta/Nightly release-note ordering; PR and release
  workflows now fail on drift instead of rewriting tracked resources in CI.
- **Release workflow rerun safety**: Beta and Stable workflows now update existing GitHub releases
  on reruns, and local `scripts/release.sh` defaults to the Stable channel to avoid accidentally
  cutting a stable version with nightly assets.
- **Polish pass**: Extracted the image-update subsystem into `AppModel+ImageUpdates.swift` (core
  `AppModel` 774 → 586 lines) and collapsed the four sweep/pull methods into two shared helpers; split
  the 771-line `ToolbarSearchPalette.swift` into `ToolbarSearchSource`, `ToolbarCommandPalette`, and
  `PaletteResultCard`; combined the three service-lifecycle methods; removed the unused `isLoading` flag

### Migration Notes

- Saved card density preferences using `compact` will auto-migrate to `medium`
- The legacy sidebar toggle setting is obsolete; sidebar is now the default shell and the toolbar UI has its own experimental flag.
- Existing container and image styles are preserved
- Activity events recorded before this version are treated as unread on first launch (the `isRead` column defaults to false); opening and dismissing the Activity panel clears the badge

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
- Expanded container detail tabs for Overview, Logs, Terminal, Stats, History, Files, and Inspect.
- Live logs, one-shot and follow modes, terminal access through SwiftTerm, file browsing/copy workflows, JSON inspect views, and per-container metrics history.
- Shared Run/Edit form for new containers and recreate/edit flows, with validation, image pre-pull, inline errors, and an exact CLI preview.
- App-managed restart policies and health checks for behavior Apple's `container` CLI does not provide natively.
- Container image update checks that can pull newer image tags and reopen the edit flow without automatically replacing the running container.

#### Images

- Local image and tag browsing with grouped references, run actions, inspect/history views, tagging, pushing, saving archives, loading OCI `.tar` archives, pruning, and update status.
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

- Volume browsing, creation, inspection, deletion, prune actions, local card styling, and mount-aware container grouping.
- Network browsing, creation, inspection, deletion, prune actions, and network-aware container grouping.
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
- Shared Liquid Glass design system primitives: `ResourceGlassCard`, `GlassSurface`, `GlassButton`, `GlassOptionTile`, `MorphPanelScaffold`, `PanelHeader`, `PanelSection`, `PanelRow`, `PanelField`, `CommandPreviewBar`, `InfoButton`, `TintSelector`, `StreamConsole`, `ActivityStatusView`, and toolbar controls.
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
- `CommandRunner` supports one-shot commands and streamed output; `ContainerClient` exposes typed async methods over real `container --format json` output.
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
