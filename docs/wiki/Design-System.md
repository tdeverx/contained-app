# Design System

Contained's UI is built around a small Liquid Glass design system. Prefer these
components before adding one-off surfaces.

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

Contextual page controls act on the current page. They should switch page or
subpage state directly rather than opening morph panels. Global toolbar buttons
and menu commands own panel presentation.

## Resource cards

Use `ResourceGlassCard` for containers, images, tags, volumes, networks, and
palette result cards.

Recommended internal pieces:

- `ResourceCardHeader` for the top row
- `ResourceCardIconChip` for icons and symbols
- `ResourceCardTitleText` for names
- `ResourceCardSubtitleText` or `ResourceCardMonospacedSubtitleText` for metadata
- `ResourceBadgeText` for compact state or kind labels
- `ResourceCardFooterMini` for small footer actions and metrics

Use `isSelected` instead of inventing a second selection ring. Use `elevated:
false` for cards inside already-elevated morph panels.

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
and shadows. If a new value appears repeatedly, add a token before duplicating
magic numbers.

Important groups:

- `Tokens.Toolbar` for toolbar band and control sizing
- `Tokens.PanelSize` for morph target sizes
- `Tokens.Space` for layout rhythm
- `Tokens.Radius` for card and control rounding
- `Tokens.IconSize` for chips and toolbar controls

## Verification

UI changes should run:

```sh
swift test
git diff --check
./scripts/bundle.sh debug
open Contained.app
```

For Contained UI work, relaunch the built app after passing tests so the current
panel/card behavior is visible in the running app.
