# ``ContainedUI``

Reusable visual building blocks for Contained and related macOS SwiftUI apps.

## Overview

`ContainedUI` exposes a nested `UI.*` API for app-neutral cards, panels,
actions, controls, toolbar controls, state views, chart widgets, materials, and
tokens. The package receives strings from the host app and does not ship
localized resources.

Use contextual tokens first:

```swift
UI.Panel.Padding.top
UI.Panel.Spacing.section
UI.Card.Radius.container
UI.Toolbar.Size.controlHeight
```

UI.Tokens is the raw primitive namespace for `ContainedUI` internals. UI
components may use raw tokens directly so one primitive change can flow through
every element that mirrors it. `ContainedUX` and app code use contextual element tokens
such as `UI.Panel.Padding.top` or `UI.Toolbar.Size.controlHeight`.
Contextual tokens mirror raw defaults unless their declaration explains an
intentional divergence.

Implementation-only helpers that remove repeated structure across elements live
under `Sources/ContainedUI/Shared`. They are package-internal and are not app
API; app code should keep using the public `UI.*` routes.

SwiftUI previews are colocated with the element declarations they exercise. The
package does not use a separate preview-only source tree, so opening an element
file in Xcode should show that element's canvas sample directly.

## Topics

### Namespaces

- `UI.Card`
- `UI.Panel`
- `UI.Action`
- `UI.Control`
- `UI.Toolbar`
- `UI.State`
- `UI.Chart`
- `UI.Theme`
- `UI.Tokens`

### Examples

```swift
UI.Action.Group([
    UI.Action.Item(systemName: "doc.on.doc", help: "Copy") { copy() },
    UI.Action.Item(systemName: "trash", title: "Delete", role: .destructive) { delete() }
])
```

```swift
UI.Panel.Scaffold(width: UI.Panel.Size.settings.width) {
    UI.Panel.Header(symbol: "gearshape", title: "Settings", subtitle: "Preferences") {
        UI.Action.Group(UI.Action.Item(systemName: "xmark", help: "Close") {})
    }
} content: {
    UI.Panel.Section(header: "Appearance") {
        UI.Panel.Row(title: "Accent") {
            UI.Control.TintSelector(selection: $tint, labelForTint: label)
        }
    }
}
```

```swift
UI.Chart.Sparkline(samples: samples,
                   color: .accentColor,
                   scale: .fraction)
    .frame(height: UI.Card.Metric.sparklineHeight)
```
