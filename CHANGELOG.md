# Changelog

## [Unreleased] - Creation Workflow 10

### Added

#### Toolbar & Navigation Redesign
- **Toolbar-first architecture**: Removed the sidebar entirely; the app now features a single Containers page with a floating custom toolbar
- **Morphing panel system**: Toolbar buttons morph into resizing panels for Images, Templates, Activity, and System resources
- **Visual command palette**: Integrated `⌘K` search and command palette into the toolbar's expandable search field, with the search bar acting as the panel header
- **Palette action index**: Added global commands for app update checks, all-image update checks, pulling available image updates, checking container-image updates, pulling available container-image updates, local image search, Docker Hub search, and app tint changes
- **Inline palette results**: Container, image group, tag, volume, network, and tint matches render as compact design-system cards instead of generic rows
- **Palette fuzzy search**: Field-aware scoring now handles exact keywords, word initials, separated partials, and small typo/transposition mistakes
- **App-wide toolbar band**: Custom Liquid Glass toolbar proportions (52pt band height, 36pt controls) matching macOS 26 design standards
- **Semantic toolbar sizing**: Button glyphs use Dynamic-Type-scalable `.headline + .imageScale(.large)` for accessibility
- **Toolbar keyboard shortcuts**: `⌘N` (New), `⌘S` (Search), `⌘U` (Updates), `⌘I` (Activity)
- **Container view options**: Top-left toolbar control (icon + title/subtitle + down chevron) to group the Containers page by Network / Volume / Image / Flat, sort by Name / Status / Image, and toggle running-only
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
- **AppSafeAreaManager**: Intelligent safe area management distinguishing between toolbar-inclusive and toolbar-exclusive layouts
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
- **System resource panel**: Moved System info into a toolbar morph panel (header-less, no sidebar)
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
- **Palette links avoid sheets**: Registry login and System logs commands now open the Settings/System morph panels instead of modal sheets
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
- **Safe area calculation**: Proper top inset accounting for both native and custom toolbar heights
- **Search palette sizing**: Correct max-width constraints and dynamic field scaling
- **Start/stop UI hang**: Container refreshes are now serialized so a user action and the background
  polling tick no longer run `list`+`stats` concurrently (decoding JSON on the main actor and
  stomping the shared stats dictionaries). The grid also only re-renders when the container list
  actually changes, eliminating the per-tick re-render storm during a `.stopping` transition

### Removed

- **Sidebar**: Complete removal of the old navigation sidebar
- **System/Registries/Runtime pages**: Moved into toolbar morphs and Settings tab
- **Old Network creation**: Previously on a dedicated Networks page; now a creation flow option
- **Legacy card sizes**: Removed `CardDensity.compact` (migrated to `.medium`)
- **Image action sheets**: Removed `TagImageSheet`, `PushImageSheet`, and `ImageHistorySheet` (replaced by image-detail morph sub-pages)

### Technical

- **New components**: `MorphingExpander`, `ResourceGlassCard`, `GlassOptionTile`, `CreationFlow`, `ContainerConfigureView`, `ToolbarControls`, `ExteriorShadow`, `ActivityStatusView`, `ToolbarViewOptions`, `InlineJSONView`
- **New models/state**: `ContainerGrouping`, `ContainerSort`, `PaletteScope`, `EventRecord.isRead`
- **Design tokens**: Added `Tokens.Toolbar` enum for all toolbar sizing and spacing
- **Geometry helpers**: `MorphGeometry` utilities for panel sizing, clamping, and target rect calculation
- **Optional matched geometry**: Helper for conditional `.matchedGeometryEffect()` in tiles
- **Polish pass**: Extracted the image-update subsystem into `AppModel+ImageUpdates.swift` (core
  `AppModel` 774 → 586 lines) and collapsed the four sweep/pull methods into two shared helpers; split
  the 771-line `ToolbarSearchPalette.swift` into `ToolbarSearchSource`, `ToolbarCommandPalette`, and
  `PaletteResultCard`; combined the three service-lifecycle methods; removed the unused `isLoading` flag

### Migration Notes

- Saved card density preferences using `compact` will auto-migrate to `medium`
- Sidebar toggle setting is obsolete (sidebar no longer exists)
- Existing container and image styles are preserved
- Activity events recorded before this version are treated as unread on first launch (the `isRead` column defaults to false); opening and dismissing the Activity panel clears the badge

## 1.0.0

### Added

- Versioned `.containedbackup` export and import for settings, local personalization, health checks, templates, and activity history.
- Rollback guard for data created by newer app schemas, with an export-before-reset path.
- Sparkle release notes in appcasts and an in-app “What’s New” view.
