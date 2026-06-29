# Command Palette

The command palette is the app-wide action index. If a user can do something
from a toolbar panel, menu command, container card, image card, settings page, or
resource panel, it should be discoverable from `CommandPalette.swift`.

## Interaction model

- `Command-K` opens the palette from the toolbar search morph.
- The search bar is the panel header. Do not add a second title header above it.
- The text field autofocuses when the palette opens.
- Arrow keys move the selected result; Return runs it; Escape closes the panel.
- The header row shows inline context such as total matches, local image matches,
  and a Docker Hub search affordance when a query exists.
- Toggles render as real switches and mutate the same setting as Settings.

## Result design

Results should use the design system rather than custom row chrome:

- use `ResourceGlassCard` for every result card
- use `ResourceCardHeader`, `ResourceCardIconChip`, `ResourceCardTitleText`,
  `ResourceCardSubtitleText`, and `ResourceBadgeText` inside cards
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

## Implementation map

- `Sources/Contained/Features/Palette/CommandPalette.swift` owns the indexed
  actions and search fields.
- `Sources/Contained/Features/Palette/PaletteSearch.swift` owns scoring.
- `Sources/Contained/Navigation/ToolbarPanels/ToolbarSearchPalette.swift` owns
  the visual panel, keyboard handling, and result rendering.
- `Tests/ContainedAppTests/PaletteSearchTests.swift` locks in fuzzy matching and
  ranking expectations.

Keep comments near new palette sections short and intentional. The goal is to
make future missing actions easy to spot, not to narrate every line.
