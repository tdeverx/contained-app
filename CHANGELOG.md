# Changelog

## [Unreleased] - Creation Workflow 10

### Added

#### Toolbar & Navigation Redesign
- **Toolbar-first architecture**: Removed the sidebar entirely; the app now features a single Containers page with a floating custom toolbar
- **Morphing panel system**: Toolbar buttons morph into resizing panels for Images, Templates, Activity, and System resources
- **Unified command palette**: Integrated `⌘K` search and command palette into the toolbar's expandable search field
- **App-wide toolbar band**: Custom Liquid Glass toolbar proportions (52pt band height, 36pt controls) matching macOS 26 design standards
- **Semantic toolbar sizing**: Button glyphs use Dynamic-Type-scalable `.headline + .imageScale(.large)` for accessibility
- **Toolbar keyboard shortcuts**: `⌘N` (New), `⌘S` (Search), `⌘U` (Updates), `⌘I` (Activity)

#### Creation & Resource Management
- **Paged creation flow**: Multi-step flow for creating containers, networks, volumes, and building images
- **Unified creation entry point**: Single `CreationSheet` host used for all non-toolbar resource creation (File ▸ New, ⌘K, empty state)
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
- **Image update detection**: Display "Update Container" option when a newer image version is available
- **Enhanced card styling**: Elevated cards with improved glass effects and optional shadows for nested layouts
- **Multi-level personalization**:
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

#### API & Architecture
- **AppModel methods**: Added `containerStyle(for:)`, `imageStyle(for:)`, `imageGroupStyle(forID:)` for personalization lookup
- **Compose import**: Split into file and text variants (`ComposeImport.importFile()`, `importText()`)
- **Resource refresh**: Added `refreshImagesIfStale(force:)` for lazy image list updates
- **Image update tracking**: New `imageUpdateStatus(for:)` to check available updates

#### Settings & Personalization
- **Personalization storage**: New methods for image group and volume styling
- **Card size persistence**: Migration helper for legacy `compact` → `medium` mapping

### Fixed

- **Container card animations**: Fixed grow/shrink spring timing for smoother detail panel transitions
- **Safe area calculation**: Proper top inset accounting for both native and custom toolbar heights
- **Search palette sizing**: Correct max-width constraints and dynamic field scaling

### Removed

- **Sidebar**: Complete removal of the old navigation sidebar
- **System/Registries/Runtime pages**: Moved into toolbar morphs and Settings tab
- **Old Network creation**: Previously on a dedicated Networks page; now a creation flow option
- **Legacy card sizes**: Removed `CardDensity.compact` (migrated to `.medium`)

### Technical

- **New components**: `MorphingExpander`, `ResourceGlassCard`, `GlassOptionTile`, `CreationFlow`, `ContainerConfigureView`, `ToolbarControls`, `ExteriorShadow`
- **Design tokens**: Added `Tokens.Toolbar` enum for all toolbar sizing and spacing
- **Geometry helpers**: `MorphGeometry` utilities for panel sizing, clamping, and target rect calculation
- **Optional matched geometry**: Helper for conditional `.matchedGeometryEffect()` in tiles

### Migration Notes

- Saved card density preferences using `compact` will auto-migrate to `medium`
- Sidebar toggle setting is obsolete (sidebar no longer exists)
- Existing container and image styles are preserved

## 1.0.0

### Added

- Versioned `.containedbackup` export and import for settings, local personalization, health checks, templates, and activity history.
- Rollback guard for data created by newer app schemas, with an export-before-reset path.
- Sparkle release notes in appcasts and an in-app “What’s New” view.
