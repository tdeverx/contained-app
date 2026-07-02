# Design System

Contained's UI is built around a small Liquid Glass design system. Prefer these
components before adding one-off surfaces.

App-agnostic SwiftUI/AppKit primitives live in the local `ContainedDesignSystem`
package under `Packages/`. App-specific views, stores, settings, routing,
localization, and domain presentation mappings stay in `ContainedApp` until they
have a clean reusable boundary.

Package-local docs:

- [`Packages/ContainedDesignSystem/README.md`](../../Packages/ContainedDesignSystem/README.md)
- [`ContainedDesignSystem` DocC landing page](../../Packages/ContainedDesignSystem/Sources/ContainedDesignSystem/ContainedDesignSystem.docc/ContainedDesignSystem.md)
- [`Packages/ContainedNavigation/README.md`](../../Packages/ContainedNavigation/README.md)

The package owns the shared tokens, visual-effect background bridge, exterior
shadow, glass surface modifier, panel/page/sheet scaffolds, toolbar controls,
option tiles, transient status/error banners, design-card chrome, action
buttons, toggles, selection bars, activity status, JSON and stream-console
surfaces, sparklines, clipboard helper, gradient-angle control, and micro
primitives such as status dots, badges, keycaps, metric tiles, terminal chrome,
and card-selection overlays. Components that read `AppModel`, settings stores,
feature routes, or runtime models stay in the app target, but they should pass
values into package components instead of recreating style locally.

## Localization boundary

The design system is a building block package. It owns layout, materials,
tokens, animation behavior, and control anatomy, but it does not own app copy or
localized resources.

Guidelines:

- user-facing labels, help text, accessibility labels, picker names, page names,
  and empty-state copy are supplied by `Sources/ContainedApp`
- package APIs that need words take app-supplied strings or semantic item
  titles, such as `DesignCardPages.closeLabel`,
  `DesignToolbarSearchField.clearSearchLabel`, and `TintSelector`'s
  `labelForTint`
- app-owned enum labels and dynamic templates flow through `AppText`, which uses
  `String(localized:defaultValue:bundle:)` with English fallbacks today
- package-owned strings are limited to non-user identifiers such as SF Symbol
  names, raw values, chart field identifiers, and accessibility-hidden chart
  dimensions

Only `ContainedApp` owns localization catalogs. The local packages should
remain reusable without shipping their own language bundles unless a future
package genuinely owns standalone user-facing copy.

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

Use `DesignPanelScaffold` for toolbar panels. It provides the shared chrome,
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
padding from `MorphSafeAreaManager`, while the sidebar and bottom page edge keep
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

Expanded design cards opened from full pages should receive the same toolbar
safe-area contract as morph panels, clearing both top and bottom toolbar bands.

## Action and toolbar chrome

Use package-owned semantic controls for command chrome:

- `DesignActionGroup` and `DesignActionItems` for icon action groups
- `DesignActionCluster` for mixed menu/action capsules
- `DesignInputCluster` for inline search/input glass lanes
- `DesignTextActionButton` for labeled standard or prominent actions
- `DesignGlassToggle` for glass toggle buttons
- `DesignSelectionActionBar` for floating selection bars
- `DesignStatusBanner` for transient bottom banners
- `DesignToolbarSearchField`, `DesignGlassMenuButton`,
  `DesignToolbarStatusButton`, `DesignToolbarActionCluster`, and
  `DesignToolbarVanitySlot` for toolbar-specific slots

Feature views cannot call the package-internal `GlassButton`, `GlassButtonItem`,
`GlassButtonInputItem`, `glassSurface`, or `glassCapsuleSurface` routes. They
also should not use `.buttonStyle(.glass/.glassProminent)` directly. If a view
needs a new command shape, add a named design-system route and then consume it
from the app.

## Design cards

Use `DesignCard` for containers, images, tags, volumes, networks, and
palette result cards.

Recommended inputs and package pieces:

- `DesignCardPages` for expanded-card page rails
- `DesignCardIconChip` for icons and symbols
- `DesignCardTextStyle` for standard versus monospaced title/subtitle text
- `DesignBadgeText` for compact state or kind labels
- `DesignCardFooterMini` for small footer actions and metrics
- `DesignCardWidgetGroup` for horizontal widget metadata
- `DesignCardFooterChip` and `DesignCardFooterButton` for card-local controls
- `DesignCardInsetSection` for charts, lists, and read-only groups inside an
  expanded card body
- `designCardFloatingControls` and `designCardProgressOverlay` for
  card-owned overlays
- `DesignStatusDot`, `DesignStatusBadge`, `DesignKeyCap`, and
  `DesignKeyboardHint` for micro chrome

Use `isSelected` instead of inventing a second selection ring. Use `elevated:
false` for cards inside already-elevated morph panels.

`DesignCard` owns the card anatomy:

- the header is always visible and stays outside the expanding body
- page controls are declared with `DesignCardPages`, stay mounted in the header
  trailing slot, and use `controlsReveal` instead of app-local overlays or
  conditional trailing views
- the body appears only while expanded
- widgets stay sticky on `.large` cards and move into the expanded body on
  `.medium`
- footers stay sticky on `.medium` and `.large` cards and move into the
  expanded body on `.small`

`DesignCardSurface`, `DesignCardHeader`, and `DesignCardPageControls` are
package-internal composition pieces used by `DesignCard`.

Do not create a second `DesignCard` or direct surface modifier inside an
expanded card body unless the nested object is itself an independent resource
card, such as an image tag row. In-card content should go through
`DesignCardInsetSection`.

## Palette visual results

The palette should not degrade rich app objects into plain text. Use
`PaletteItemVisual` whenever a result has meaningful state:

- `.container` for actual containers
- `.imageGroup` for local image groups
- `.imageTag` for local tags
- `.volume` and `.network` for resources
- `.tint` for appearance color choices

Plain rows are reserved for generic actions such as refresh or opening a page.

## DesignTokens

Use `DesignTokens` for spacing, radius, toolbar dimensions, panel sizes, icon sizes,
form widths, chart sizes, badge/keycap insets, design-card opacities, terminal
chrome, and shadows. Feature views should not call low-level surface modifiers
or glass button styles; use named package routes such as `DesignCard`,
`PanelSection`, `DesignContentSurface`, `DesignInputSurface`,
`DesignActionGroup`, `DesignActionCluster`, `DesignInputCluster`,
`DesignTextActionButton`, and `DesignCardInsetSection`.
If a new visual value appears, add a token or package primitive before using it
in the app.

Important groups:

- `DesignTokens.Toolbar` for toolbar band and control sizing
- `DesignTokens.PanelSize` for morph target sizes
- `DesignTokens.Space` for layout rhythm
- `DesignTokens.Radius` for card and control rounding
- `DesignTokens.IconSize` for chips and toolbar controls
- `DesignTokens.DesignCard`, `DesignTokens.Badge`, `DesignTokens.Keyboard`, `DesignTokens.Chart`,
  `DesignTokens.FormWidth`, and `DesignTokens.Terminal` for smaller repeated chrome values

Feature views can choose semantic content, domain colors, and app data, but
should not create app-local spacing, padding, radius, shadow, material, opacity,
badge, keycap, status-dot, or terminal-surface recipes.

## Verification

UI changes should run:

```sh
swift test
git diff --check
xcodebuild -workspace Contained.xcworkspace -scheme Contained -configuration Debug build
./scripts/bundle.sh debug
open Contained.app
```

For Contained UI work, relaunch the built app after passing tests so the current
panel/card behavior is visible in the running app. If an existing `Contained.app`
is open, quit it before rebuilding and reopening the fresh bundle.
