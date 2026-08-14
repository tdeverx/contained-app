# ``ContainedUI``

Reusable visual building blocks for Contained and related macOS SwiftUI apps.

## Overview

`ContainedUI` exposes a nested `UI.*` API for app-neutral cards, panels,
native form rows, actions, controls, toolbar controls, state views, chart
widgets, materials, and tokens. The package receives strings from the host app and does not ship
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
- `UI.Form.Grouped` plus rows, fields, toggles, info buttons, and error/changed label states
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
            UI.Control.TintSelector(selection: $tint,
                                    customLabel: "Custom",
                                    labelForTint: label)
        }
        UI.Panel.Row(title: "Custom") {
            UI.Control.HexTintField(selection: $tint)
        }
    }
}
```

Seed `.tint(...)`, `.accentColor(...)`, and `\.designSystemAccentColor` at every scene root. The
first styles native controls, the second scopes explicit accent drawing, and the third gives reusable
controls such as the App Accent swatch the resolved, live accent color to render.

```swift
UI.Form.Grouped {
    Section("Runtime") {
        UI.Form.Field(label: "Image", info: "The image reference to run.") {
            TextField("nginx:latest", text: $image)
        }
        UI.Form.ToggleRow(title: "Run in background",
                          isChanged: true,
                          isOn: $detached)
    }
}
```

```swift
UI.Chart.Sparkline(samples: samples,
                   color: .accentColor,
                   scale: .fraction)
    .frame(height: UI.Card.Metric.sparklineHeight)
```

## Related Documentation

- [Design System](../../../../../Documentation/Architecture/Design-System.md)
- [Wiki sync map](../../../../../Documentation/Wiki/File-Map.md)
