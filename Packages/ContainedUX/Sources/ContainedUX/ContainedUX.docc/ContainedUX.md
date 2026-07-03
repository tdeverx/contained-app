# ``ContainedUX``

Reusable morphing, placement, safe-area, and measurement infrastructure.

## Overview

`ContainedUX` exposes nested `UX.*` routes. `UX` decides how surfaces move and
where they fit; `ContainedUI` decides how surfaces look; the app decides which
surface opens and why.

`ContainedUX` consumes contextual `ContainedUI` element tokens such as
`UI.Panel.Size`, `UI.Panel.Radius`, `UI.Toolbar.Size`, and `UI.Layout.Spacing`.
Raw `UI.Tokens` stay inside `ContainedUI`.

SwiftUI previews are colocated with the morph, placement, measurement, and
safe-area declarations they exercise. The package does not use a separate
preview-only source tree.

```swift
UX.Morph.Expander(isPresented: $isPresented,
                  originFrame: originFrame,
                  target: .anchored(size: UI.Panel.Size.imageDetail)) {
    UI.Panel.Scaffold(width: UI.Panel.Size.imageDetail.width) {
        UI.Panel.Header(symbol: "photo", title: "Images", subtitle: nil) {
            UI.Action.Group(UI.Action.Item(systemName: "xmark", help: "Close") {
                isPresented = false
            })
        }
    } content: {
        content()
    }
}
```

## Topics

### Namespaces

- `UX.Morph`
- `UX.Panel`
- `UX.SafeArea`
- `UX.Measurement`

### Related Visual Package

- `UI.Panel.Scaffold`
- `UI.Card.Scaffold`
- `UI.Toolbar.Size`
