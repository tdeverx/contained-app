# Command Palette

> **Experimental (off by default).** The palette is gated behind Settings →
> Experimental → "Command palette (⌘K)" and uses the toolbar search slot to
> render as a morph. While disabled, the toolbar search field stays a plain page
> filter (no ⌘K hint, no escalation), menu commands are hidden, and `AppToolbar`
> refuses to render the palette morph even if some path sets `activeMorph =
> .palette`. The Docker Hub search scope has its own experimental flag
> (`hubSearchEnabled`).

The command palette is the app-wide action index. If a user can do something
from a toolbar panel, menu command, container card, image card, settings page, or
resource panel, it should be discoverable from `CommandPalette.swift`.

## Interaction model

- `Command-K` opens the palette from the toolbar search morph when the toolbar
  UI and command palette are enabled.
- If toolbar panel navigation is disabled, actions route through the same classic
  pages and sheets as toolbar buttons and menu commands.
- The search bar is the panel header. Do not add a second title header above it.
- The text field autofocuses when the palette opens.
- Arrow keys move the selected result; Return runs it; Escape closes the panel.
- The header row shows inline context such as total matches, local image matches,
  and a Docker Hub search affordance when a query exists.
- Toggles render as real switches and mutate the same setting as Settings.

## Result design

Results should use the design system rather than custom row chrome:

- use `DesignCard` for every result card
- pass badges, chevrons, return hints, and unread dots through the card's named
  accessory slots instead of building custom headers
- use `PaletteItemVisual` for anything that can be represented visually
- render containers, image groups, tags, volumes, networks, and tints as mini
  cards using their actual app styling
- use `.plain` only for generic commands that have no richer visual state

## Action coverage checklist

When adding a feature, check whether it needs one or more palette entries:

- global app actions, such as refresh, app update checks, activity, logs, and
  Settings pages
- creation actions, such as run container, pull/search image, build image, import
  compose, create network, create volume, and registry login
- container actions, such as start, stop, restart, edit, and image update
- image actions, such as run, check update, pull update, tag, push, save, load,
  prune, and bulk update checks
- resource actions, such as use volume, run on network, create resource, delete,
  and prune
- settings toggles and bounded settings values, such as menu bar visibility,
  CLI preview visibility, info tips, and app tint

Registry credential actions should route to Settings → Registries. Registries do
not appear as their own app page in the sidebar, page switcher, or navigation
results.

## Implementation map

- `Sources/ContainedApp/Features/Palette/CommandPalette.swift` owns the indexed
  actions and search fields.
- `Sources/ContainedApp/Features/Palette/PaletteSearch.swift` owns scoring.
- `Sources/ContainedApp/Navigation/ToolbarPanels/ToolbarSearchSource.swift` owns the
  toolbar search field (and the empty-query escalation into the palette).
- `Sources/ContainedApp/Navigation/ToolbarPanels/ToolbarCommandPalette.swift` owns
  the visual panel and keyboard handling.
- `Sources/ContainedApp/Navigation/ToolbarPanels/PaletteResultCard.swift` owns
  per-result card rendering.
- `Tests/ContainedAppTests/PaletteSearchTests.swift` locks in fuzzy matching and
  ranking expectations.

Keep comments near new palette sections short and intentional. The goal is to
make future missing actions easy to spot, not to narrate every line.
