# Design System

Contained's UI is built around a small Liquid Glass design system. Prefer these
components before adding one-off surfaces.

App-agnostic SwiftUI/AppKit primitives live in the local `ContainedUI`
package under `Packages/`. App-specific views, stores, settings, routing,
localization, and domain presentation mappings stay in `ContainedApp` until they
have a clean reusable boundary.

Package-local docs:

- [`Packages/ContainedUI/README.md`](../../Packages/ContainedUI/README.md)
- [`ContainedUI` DocC landing page](../../Packages/ContainedUI/Sources/ContainedUI/ContainedUI.docc/ContainedUI.md)
- [`Packages/ContainedUX/README.md`](../../Packages/ContainedUX/README.md)

The package owns the shared tokens, visual-effect background bridge, exterior
shadow, glass surface modifier, panel/page/sheet scaffolds, toolbar controls,
option tiles, transient status/error banners, design-card chrome, action
buttons, toggles, selection bars, activity status, JSON and stream-console
surfaces, sparklines, clipboard helper, gradient-angle control, and micro
primitives such as status dots, badges, keycaps, metric tiles, terminal chrome,
and card-selection overlays. Components that read `AppModel`, settings stores,
feature routes, or runtime models stay in the app target, but they should pass
values into package components instead of recreating style locally.

Repeated package implementation structure belongs in
`Packages/ContainedUI/Sources/ContainedUI/Shared`. The `Shared` tree is
package-internal: it can factor common capsule, swatch, row, label, or surface
rendering anatomy, but app code should still consume the named public `UI.*`
components rather than reaching for shared helpers.

Package SwiftUI previews live beside the declaration they exercise. Do not add
new preview-only folders for design-system elements; add a focused `#Preview`
to the element file so Xcode Canvas opens directly on that component. The main
app should keep a small fixture-free fake-data preview at the app surface that
needs it instead of linking fixture products into shipping targets.

## Localization boundary

The design system is a building block package. It owns layout, materials,
tokens, animation behavior, and control anatomy, but it does not own app copy or
localized resources.

Guidelines:

- user-facing labels, help text, accessibility labels, picker names, page names,
  and empty-state copy are supplied by `Sources/ContainedApp`
- package APIs that need words take app-supplied strings or semantic item
  titles, such as `UI.Card.Pages.closeLabel`,
  `UI.Toolbar.SearchField.clearSearchLabel`, and `UI.Control.TintSelector`'s
  `labelForTint`
- app-owned enum labels and dynamic templates flow through `AppText`, which uses
  `String(localized:defaultValue:bundle:)` with English fallbacks today
- package-owned strings are limited to non-user identifiers such as SF Symbol
  names, raw values, chart field identifiers, and accessibility-hidden chart
  dimensions

Only `ContainedApp` owns product-facing localization catalogs. `ContainedUI`
and `ContainedUX` should remain reusable without shipping language bundles
unless a future package genuinely owns standalone user-facing copy.
`ContainedCore` is the exception: it may ship display-neutral semantic strings
for schema labels/help, validation messages, capability reasons, projection
warnings, and typed package-error fallback descriptions.

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
- `WidgetConfiguration` owns app-side metric-widget schema. `UI.Chart.GraphStyle` and
  `UI.Chart.Interpolation` live in the design package as graph rendering options.
- `PersonalizationStore` owns persistence, inheritance, backup, and local-only
  style resolution.

## Panel scaffolding

Use `UI.Panel.Scaffold` for toolbar panels. It provides the shared chrome,
content, and footer structure used by Images, Templates, Activity, System,
Settings, and the Command Palette.

Guidelines:

- keep panels anchored to their toolbar source when possible
- use `UI.Panel.Header` for titled panels
- omit `UI.Panel.Header` when the primary control is itself the header, such as the
  Command Palette search field
- keep footer hints compact and secondary

## Settings-style editors

Use `UI.Panel.Section`, `UI.Panel.Row`, `UI.Panel.Field`, and `PanelToggleRow` for dense
settings and editor surfaces inside glass panels. This keeps Customize, Run/Edit,
registry login, image build, and Settings aligned on one row rhythm and one
info-button placement model.

Guidelines:

- keep sections top-level; avoid nesting glass cards inside glass cards
- put explanatory help in the row `info` slot instead of appending ad-hoc
  trailing info buttons
- split repeated editors into focused subviews when the parent sheet also owns
  persistence or presentation state
- use `UI.Panel.SheetTitleBar` for modal sheets and `UI.Panel.Header` for in-window morph
  panels or embedded panel pages

## Toolbar shell

The floating toolbar and toolbar-panel navigation are separate experimental
settings. `experimentalToolbarUI` turns on the custom top/bottom toolbar chrome;
`experimentalPanelNavigation` decides whether eligible routes open morph panels
or fall back to classic pages and sheets.

`AppToolbar` is mounted inside the `NavigationSplitView` detail column by
`ClassicShell`, not across the whole split view. The detail body receives top
padding from `UX.SafeArea.Manager`, while the sidebar and bottom page edge keep
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

- `UI.Action.Group` and `UI.Action.Items` for icon action groups
- `UI.Action.Cluster` for mixed menu/action capsules
- `UI.Action.InputCluster` for inline search/input lanes
- `UI.Action.TextButton` for labeled standard or prominent actions
- `UI.Action.ToggleButton` for toggle buttons in toolbar or panel chrome
- `UI.Action.SelectionBar` for floating selection bars
- `UI.State.Banner` for transient bottom banners
- `UI.Action.MenuButton` for material-backed menu triggers outside toolbar slots
- `UI.Toolbar.SearchField`,
  `UI.Toolbar.StatusButton`, `UI.Toolbar.ActionCluster`, and
  `UI.Toolbar.VanitySlot` for toolbar-specific slots

Feature views cannot call the package-internal `MaterialButton`, `MaterialButtonItem`,
`MaterialButtonInputItem`, `materialSurface`, or `materialCapsuleSurface` routes. They
also should not use `.buttonStyle(.glass/.glassProminent)` directly. If a view
needs a new command shape, add a named design-system route and then consume it
from the app.

## Design cards

Use `UI.Card.Scaffold` for containers, images, tags, volumes, networks, and
palette result cards.

Recommended inputs and package pieces:

- `UI.Card.Pages` for expanded-card page rails
- `UI.Card.IconChip` for icons and symbols
- `UI.Card.TextStyle` for standard versus monospaced title/subtitle text
- `UI.Badge.Text` for compact state or kind labels
- `UI.Card.FooterMini` for small footer actions and metrics
- `UI.Card.WidgetGroup` for horizontal widget metadata
- `UI.Card.FooterChip` and `UI.Card.FooterButton` for card-local controls
- `UI.Card.InsetSection` for charts, lists, and read-only groups inside an
  expanded card body
- `designCardFloatingControls` and `designCardProgressOverlay` for
  card-owned overlays
- `UI.Badge.Dot`, `UI.Badge.Status`, `UI.Control.KeyCap`, and
  `UI.Control.KeyboardHint` for micro chrome

Use `isSelected` instead of inventing a second selection ring. Use `elevated:
false` for cards inside already-elevated morph panels.

`UI.Card.Scaffold` owns the card anatomy:

- the header is always visible and stays outside the expanding body
- page controls are declared with `UI.Card.Pages`, stay mounted in the header
  trailing slot, and use `controlsReveal` instead of app-local overlays or
  conditional trailing views
- the body appears only while expanded
- widgets stay sticky on `.large` cards and move into the expanded body on
  `.medium`
- footers stay sticky on `.medium` and `.large` cards and move into the
  expanded body on `.small`

`card surface internals`, `card header internals`, and `card page-control internals` are
package-internal composition pieces used by `UI.Card.Scaffold`.

Do not create a second `UI.Card.Scaffold` or direct surface modifier inside an
expanded card body unless the nested object is itself an independent resource
card, such as an image tag row. In-card content should go through
`UI.Card.InsetSection`.

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

`UI.Tokens` is the minimal raw token source for `ContainedUI` internals. UI
components may read those raw tokens directly so one primitive change can flow
through every visual element that mirrors it.

App-facing and UX-facing code should use contextual element tokens instead:

- `UI.Toolbar.Size` for toolbar band and control sizing
- `UI.Panel.Size`, `UI.Panel.Padding`, `UI.Panel.Spacing`, and `UI.Panel.Radius`
  for panels and morph targets
- `UI.Card.Padding`, `UI.Card.Spacing`, `UI.Card.Radius`, and `UI.Card.Metric`
  for card anatomy
- `UI.Layout.Spacing` only when layout rhythm has no more specific element owner
- `UI.Control.Size`, `UI.Badge.Padding`, `UI.Form.Width`, `UI.Chart.Size`, and
  similar element namespaces for repeated smaller chrome values

Contextual tokens mirror `UI.Tokens` by default. If an element needs its own
value, the declaration must include a short inline comment explaining why that
token intentionally diverges from the raw default.

Feature views should not call low-level surface modifiers, material button
styles, or raw `UI.Tokens`; use named package routes such as
`UI.Card.Scaffold`, `UI.Panel.Section`, `UI.Surface.Content`,
`UI.Surface.Input`, `UI.Action.Group`, `UI.Action.Cluster`,
`UI.Action.InputCluster`, `UI.Action.TextButton`, and `UI.Card.InsetSection`.
If a new visual value appears, add or extend a contextual element token or
package primitive before using it in the app.

When two design-system elements have the same internal anatomy, factor only the
shared implementation into the package-internal `Shared` tree. Keep distinct
public routes when callers need different semantics, names, or capability
boundaries.

## Verification

UI changes should run:

```sh
swift test
git diff --check
xcodebuild -workspace Contained.xcworkspace -scheme Contained -configuration Debug build
./Scripts/package.sh app debug
open Contained.app
```

For Contained UI work, relaunch the built app after passing tests so the current
panel/card behavior is visible in the running app. If an existing `Contained.app`
is open, quit it before rebuilding and reopening the fresh bundle.
