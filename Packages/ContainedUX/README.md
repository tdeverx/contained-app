# ContainedUX

`ContainedUX` owns reusable interaction infrastructure: morph geometry,
safe-area policy, source-frame measurement, panel placement, and single-surface
expansion behavior.

It depends on `ContainedUI` for visual primitives and contextual element tokens.
`ContainedUX` uses routes such as `UI.Panel.Size`, `UI.Panel.Radius`,
`UI.Toolbar.Size`, and `UI.Layout.Spacing`; it does not read raw `UI.Tokens`.
It does not own app sections, stores, toolbar panel contents, `UIState`, feature
routing, or localized copy.

## Importing

```swift
.product(name: "ContainedUX", package: "ContainedUX")
```

```swift
import SwiftUI
import ContainedUI
import ContainedUX
```

## Public API Shape

- `UX.Morph.*` owns morph target geometry, grow/shrink expanders, and single-surface transitions.
- `UX.Panel.*` owns panel placement and backdrop policy.
- `UX.SafeArea.*` owns toolbar-aware safe-area measurement and environment policy.
- `UX.Measurement.*` owns source-frame collection for morph origins.
- `ContainedUI` owns visual anatomy such as `UI.Panel.Scaffold`; `ContainedUX` moves and places that anatomy.

## Panel Morph Example

```swift
struct AddPanelHost: View {
    @State private var isPresented = false
    let originFrame: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            UI.Action.Group(UI.Action.Item(systemName: "plus", help: "Add") {
                isPresented = true
            })
            .padding(UI.Layout.Spacing.l)

            UX.Morph.Expander(isPresented: $isPresented,
                              originFrame: originFrame,
                              target: .centered(size: UI.Panel.Size.add)) {
                UI.Panel.Scaffold(width: UI.Panel.Size.add.width) {
                    UI.Panel.Header(symbol: "plus",
                                    title: "Add",
                                    subtitle: "Choose a starting point") {
                        UI.Action.Group(UI.Action.Item(systemName: "xmark",
                                                       help: "Close",
                                                       isCancel: true) {
                            isPresented = false
                        })
                    }
                } content: {
                    UI.Control.OptionTile(symbol: "play.rectangle",
                                          title: "Run a container",
                                          subtitle: "Start from an image") {
                        isPresented = false
                    }
                    .padding(UI.Panel.Padding.compact)
                }
            }
        }
        .environment(\.morphSafeAreaManager,
                      UX.SafeArea.Manager(topToolbarHeight: UI.Toolbar.Size.band,
                                          bottomToolbarHeight: UI.Toolbar.Size.band))
    }
}
```

## Single Surface Example

Use `UX.Morph.SingleSurface` when an existing card, row, or tile should expand
as one surface without handing off to a separate panel:

```swift
UX.Morph.SingleSurface(source: sourceFrame,
                       target: detailFrame,
                       progress: isExpanded ? 1 : 0) {
    UI.Card.Scaffold(size: .large,
                     isExpanded: isExpanded,
                     title: "web",
                     subtitle: "Running",
                     pages: nil) {
        UI.Card.IconChip(symbol: "shippingbox.fill")
    } titleAccessory: {
        EmptyView()
    } subtitleAccessory: {
        EmptyView()
    } headerAccessory: {
        EmptyView()
    } bodyContent: {
        EmptyView()
    } footerLeading: {
        EmptyView()
    } footerActions: {
        EmptyView()
    } widget: {
        EmptyView()
    }
}
```

## Previews

Package-local SwiftUI previews live beside the interaction primitive they
exercise. Opening a morph, measurement, placement, or safe-area source file in
Xcode should show the matching canvas preview without looking in a separate
preview-only folder.

## Verification

```sh
swift build --package-path Packages/ContainedUX
swift test --package-path Packages/ContainedUX
```
