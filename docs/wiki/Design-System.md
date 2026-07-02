# Design System

Contained's UI is built around a small Liquid Glass design system. Prefer these
components before adding one-off surfaces.

App-agnostic SwiftUI/AppKit primitives live in the local `ContainedDesignSystem`
package under `Packages/`. App-specific views, stores, settings, routing, and
domain presentation mappings stay in the executable target until they have a
clean reusable boundary.

Package-local docs:

- [`Packages/ContainedDesignSystem/README.md`](../../Packages/ContainedDesignSystem/README.md)
- [`ContainedDesignSystem` DocC landing page](../../Packages/ContainedDesignSystem/Sources/ContainedDesignSystem/ContainedDesignSystem.docc/ContainedDesignSystem.md)
- [`Packages/ContainedNavigation/README.md`](../../Packages/ContainedNavigation/README.md)

The package owns the shared tokens, visual-effect background bridge, exterior
shadow, glass surface modifier, panel/page/sheet scaffolds, toolbar controls,
option tiles, transient error banner, resource-card chrome, activity status,
JSON and stream-console surfaces, sparklines, clipboard helper, gradient-angle
control, and micro primitives such as status dots, badges, keycaps, metric
tiles, terminal chrome, and card-selection overlays. Components that read
`AppModel`, settings stores, feature routes, or runtime models stay in the app
target, but they should pass values into package components instead of
recreating style locally.

## Core principles

- A morph panel is one stable shell. Content can swap inside it, but the shell
  should own size, clipping, backdrop, and elevation.
- Search fields and toolbar controls should feel like compact macOS controls,
  not large mobile bars.
- Cards own their content clipping. Parent scroll views own viewport clipping.
- Nested cards inside panels are flat by default; the enclosing shell owns the
  elevation.
- Personalization is local app state. Tint, icon, nickname, and background
  styling should not be written back to container labels.

Style ownership:

- `Personalization` is the resolved card style.
- `WidgetConfiguration` owns app-side metric-widget schema. `GraphStyle` and
  `WidgetInterpolation` live in the design package as graph rendering options.
- `PersonalizationStore` owns persistence, inheritance, backup, and legacy
  `contained.*` label migration.

## Panel scaffolding

Use `MorphPanelScaffold` for toolbar panels. It provides the shared chrome,
content, and footer structure used by Images, Templates, Activity, System,
Settings, and the Command Palette.

Guidelines:

- keep panels anchored to their toolbar source when possible
- use `PanelHeader` for titled panels
- omit `PanelHeader` when the primary control is itself the header, such as the
  Command Palette search field
- keep footer hints compact and secondary

## Settings-style editors

Use `PanelSection`, `PanelRow`, `PanelField`, and `PanelToggleRow` for dense
settings and editor surfaces inside glass panels. This keeps Customize, Run/Edit,
registry login, image build, and Settings aligned on one row rhythm and one
info-button placement model.

Guidelines:

- keep sections top-level; avoid nesting glass cards inside glass cards
- put explanatory help in the row `info` slot instead of appending ad-hoc
  trailing info buttons
- split repeated editors into focused subviews when the parent sheet also owns
  persistence or presentation state
- use `SheetHeader` for modal sheets and `PanelHeader` for in-window morph
  panels or embedded panel pages

## Toolbar shell

The floating toolbar and toolbar-panel navigation are separate experimental
settings. `experimentalToolbarUI` turns on the custom top/bottom toolbar chrome;
`experimentalPanelNavigation` decides whether eligible routes open morph panels
or fall back to classic pages and sheets.

`AppToolbar` is mounted inside the `NavigationSplitView` detail column by
`ClassicShell`, not across the whole split view. The detail body receives top
padding from `AppSafeAreaManager`, while the sidebar and bottom page edge keep
native split-view layout. Scrollable page interiors add bottom scroll-content
clearance for the floating toolbar, so the last row can move above it without
lifting the page itself. Toolbar page actions live in the top row to the left of
search; page filters live in the bottom row next to System and hide on pages
without filters.

Bottom page filters use the shared toolbar menu-button shape. Containers,
Images, Templates, and Networks all expose their page-specific grouping/sorting
state from this slot rather than inventing page-local controls.

Contextual page controls act on the current page. They should switch page or
subpage state directly rather than opening morph panels. Global toolbar buttons
and menu commands own panel presentation.

When the sidebar is visible, the top-row vanity traffic-light house and page
switcher are hidden because native sidebar navigation owns that role. Contextual
page controls remain in the leading toolbar cluster, immediately before search.

When toolbar panel navigation is enabled, panel-owned destinations such as
System, Activity, and Settings are removed from page navigation and remain
available through their toolbar/menu entry points.

Expanded resource cards opened from full pages should receive the same toolbar
safe-area contract as morph panels, clearing both top and bottom toolbar bands.

## Resource cards

Use `ResourceGlassCard` for containers, images, tags, volumes, networks, and
palette result cards.

Recommended internal pieces:

- `ResourceCardHeader` for the top row
- `ResourceCardHeaderTextBlock` for sticky title/subtitle lanes inside headers
- `ResourceCardIconChip` for icons and symbols
- `ResourceCardTitleText` for names
- `ResourceCardSubtitleText` or `ResourceCardMonospacedSubtitleText` for metadata
- `ResourceBadgeText` for compact state or kind labels
- `ResourceCardFooterMini` for small footer actions and metrics
- `ResourceCardWidgetGroup` for horizontal widget metadata
- `ResourceCardFooterChip`, `ResourceCardFooterButton`, and
  `ResourceCardPageControls` for card-local controls
- `ResourceCardInsetSection` for charts, lists, and read-only groups inside an
  expanded card body
- `resourceCardFloatingControls` and `resourceCardProgressOverlay` for
  card-owned overlays
- `DesignStatusDot`, `DesignStatusBadge`, `DesignKeyCap`, and
  `DesignKeyboardHint` for micro chrome

Use `isSelected` instead of inventing a second selection ring. Use `elevated:
false` for cards inside already-elevated morph panels.

`ResourceGlassCard` owns the card anatomy:

- the header is always visible and stays outside the expanding body
- page controls belong in the header trailing slot, stay mounted, and use
  `controlsReveal` instead of app-local overlays or conditional trailing views
- the body appears only while expanded
- widgets stay sticky on `.large` cards and move into the expanded body on
  `.medium`
- footers stay sticky on `.medium` and `.large` cards and move into the
  expanded body on `.small`

Do not create a second `ResourceGlassCard` or direct surface modifier inside an
expanded card body unless the nested object is itself an independent resource
card, such as an image tag row. In-card content should go through
`ResourceCardInsetSection`.

## Palette visual results

The palette should not degrade rich app objects into plain text. Use
`PaletteItemVisual` whenever a result has meaningful state:

- `.container` for actual containers
- `.imageGroup` for local image groups
- `.imageTag` for local tags
- `.volume` and `.network` for resources
- `.tint` for appearance color choices

Plain rows are reserved for generic actions such as refresh or opening a page.

## Tokens

Use `Tokens` for spacing, radius, toolbar dimensions, panel sizes, icon sizes,
form widths, chart sizes, badge/keycap insets, resource-card opacities, terminal
chrome, and shadows. Feature views should not call low-level surface modifiers
such as `glassSurface`; use named package routes such as `ResourceGlassCard`,
`PanelSection`, `DesignContentSurface`, `DesignInputSurface`, and
`ResourceCardInsetSection`. If a new visual value appears, add a token or package
primitive before using it in the app.

Important groups:

- `Tokens.Toolbar` for toolbar band and control sizing
- `Tokens.PanelSize` for morph target sizes
- `Tokens.Space` for layout rhythm
- `Tokens.Radius` for card and control rounding
- `Tokens.IconSize` for chips and toolbar controls
- `Tokens.ResourceCard`, `Tokens.Badge`, `Tokens.Keyboard`, `Tokens.Chart`,
  `Tokens.FormWidth`, and `Tokens.Terminal` for smaller repeated chrome values

Feature views can choose semantic content, domain colors, and app data, but
should not create app-local spacing, padding, radius, shadow, material, opacity,
badge, keycap, status-dot, or terminal-surface recipes.

## Verification

UI changes should run:

```sh
swift test
git diff --check
./scripts/bundle.sh debug
open Contained.app
```

For Contained UI work, relaunch the built app after passing tests so the current
panel/card behavior is visible in the running app. If an existing `Contained.app`
is open, quit it before rebuilding and reopening the fresh bundle.
