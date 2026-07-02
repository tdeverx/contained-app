# ContainedUI

`ContainedUI` owns Contained's reusable visual system. It contains app-neutral
SwiftUI/AppKit primitives, contextual tokens, materials, cards, panels,
controls, feedback states, chart widgets, and small visual affordances.

It does not own app routes, stores, persistence, Sparkle, runtime policy, or
localized resources. Host apps supply all visible strings, help text,
accessibility labels, and display copy.

## Importing

```swift
.product(name: "ContainedUI", package: "ContainedUI")
```

```swift
import SwiftUI
import ContainedUI
```

## Public API Shape

Use the nested `UI.*` surface from app and package examples:

- `UI.Card.*` for card anatomy, page controls, metric chips, and card-local sections.
- `UI.Panel.*` for panel scaffolds, title bars, fields, rows, and sheet title bars.
- `UI.Action.*` for command groups, action items, selection bars, toggles, and progress capsules.
- `UI.Control.*` for option tiles, input/content surfaces, search fields, menus, tint controls, and keyboard hints.
- `UI.Toolbar.*` for toolbar slots and controls.
- `UI.State.*` for empty/loading/error/status presentation.
- `UI.Chart.*` for Swift Charts-backed sparklines and metric tiles.
- `UI.Theme.*` for materials, tint, appearance, color blending, and button tint policy.

## Tokens

UI.Tokens is the small raw primitive set used inside the package. `ContainedUI`
components may read raw tokens directly so one primitive change can affect every
element that mirrors it. App and `ContainedUX` code should use contextual
element tokens:

```swift
UI.Panel.Padding.top
UI.Panel.Spacing.section
UI.Card.Padding.body
UI.Card.Radius.container
UI.Toolbar.Size.controlHeight
UI.Chart.Size.height
```

Contextual tokens mirror `UI.Tokens` unless a component intentionally diverges.
When a contextual token diverges, the declaration must include a short inline
reason so future contributors understand why the element owns a different value.

## Root Setup

Seed shared material and tint policy once near the app shell:

```swift
struct AppRoot: View {
    let tint = UI.Theme.Tint.azure

    var body: some View {
        RootContent()
            .tint(tint.color)
            .environment(\.modalMaterial, UI.Theme.WindowMaterial.sheet)
            .environment(\.buttonMaterial, UI.Theme.WindowMaterial.glassClear)
            .environment(\.cardMaterial, UI.Theme.WindowMaterial.glassRegular)
            .environment(\.buttonTintStyle,
                          UI.Theme.ButtonTintStyle(enabled: true,
                                                   tint: tint,
                                                   opacity: 0.18))
            .environment(\.designSystemShowsInfoTips, true)
            .environment(\.pageScaffoldUsesToolbarChrome, false)
            .environment(\.pageScaffoldBottomClearance, 0)
    }
}
```

## Card Example

```swift
struct ContainerSummaryCard: View {
    @State private var page = "overview"

    private let pages = [
        UI.Card.Page(id: "overview", title: "Overview", systemImage: "rectangle.grid.1x2"),
        UI.Card.Page(id: "stats", title: "Stats", systemImage: "chart.xyaxis.line")
    ]

    var body: some View {
        UI.Card.Scaffold(size: .large,
                         isExpanded: true,
                         title: "web",
                         subtitle: "Running",
                         pages: UI.Card.Pages(items: pages,
                                              selection: page,
                                              tint: .accentColor,
                                              closeLabel: "Close",
                                              onSelect: { page = $0 },
                                              onClose: {})) {
            UI.Card.IconChip(symbol: "shippingbox.fill", tint: .accentColor)
        } titleAccessory: {
            UI.Badge.Text(text: "Apple")
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            UI.Card.InsetSection(title: "Details") {
                UI.Card.SubtitleText(text: "Port 8080 -> 80")
            }
        } footerLeading: {
            UI.Card.FooterChip(isSelected: true, tint: .accentColor, help: "CPU", action: {}) {
                Image(systemName: "cpu")
            } text: {
                UI.Card.MetricText(text: "12%")
            }
        } footerActions: {
            UI.Card.FooterButton(systemName: "play.fill", help: "Start") {}
        } widget: {
            UI.Chart.Sparkline(samples: [0, 0.12, 0.18],
                               color: .accentColor,
                               scale: .fraction)
                .frame(height: UI.Card.Metric.sparklineHeight)
        }
    }
}
```

## Panel Example

```swift
UI.Panel.Scaffold(width: UI.Panel.Size.settings.width) {
    UI.Panel.Header(symbol: "gearshape",
                    title: "Settings",
                    subtitle: "App preferences") {
        UI.Action.Group(UI.Action.Item(systemName: "xmark", help: "Close") {})
    }
} content: {
    UI.Panel.Section(header: "General") {
        UI.Panel.Row(title: "Launch at login") {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
    }
    .padding(UI.Panel.Padding.compact)
}
```

## Previews

Package-local SwiftUI previews are guarded by `CONTAINED_UI_PREVIEWS`. Normal
app builds do not define that flag, so sample preview values are not linked into
debug, release, notarized, or non-notarized app bundles.

## Verification

```sh
swift build --package-path Packages/ContainedUI
swift test --package-path Packages/ContainedUI
```
