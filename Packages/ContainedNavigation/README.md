# ContainedNavigation

`ContainedNavigation` is the local Swift package that owns reusable navigation
and layout infrastructure for Contained's window chrome.

It depends on `ContainedDesignSystem` for tokens and visual primitives. It does
not own app sections, stores, toolbar panel content, `UIState`, routes, or
feature decisions.

It also does not own localized resources or English UI defaults. Host apps pass
their own titles, help text, accessibility labels, and panel copy into the
navigation/design-system views they compose.

## Importing

From the root app package:

```swift
.product(name: "ContainedNavigation", package: "ContainedNavigation")
```

From Swift code:

```swift
import SwiftUI
import ContainedDesignSystem
import ContainedNavigation
```

## What Belongs Here

- `AppSafeAreaManager`, `AppSafeAreaPolicy`, and the `appSafeAreas` environment
  value for generic top/bottom toolbar safe-area contracts.
- `MorphGeometry`, `AppMorphTarget`, and `MorphPanelPlacement` for target rects
  that clamp to a safe area.
- `MorphingExpander` for the reusable grow/shrink panel shell.
- `MorphingSingleSurface` and `MorphingSingleSurfaceExpander` for card-like
  overlays that grow from one existing source slot into one target rect without
  a handoff panel.
- `MorphSourceFrameReader` and `MorphSourceFramesKey` for measuring source
  frames in a named coordinate space without app-local preference keys.
- `MorphPanelScaffold` for generic fixed chrome, scrollable content, and pinned
  footer layout inside a morph panel.

Keep concrete panel contents in the app target. For example, Images, Templates,
System, Settings, Activity, and Command Palette panels are app features that use
this package; they do not live in this package.

## Example

This example uses a fixed `originFrame` to stay compact. Production apps usually
measure the toolbar button frame with a `GeometryReader` or preference key and
pass that measured rect into `MorphingExpander`.

```swift
import SwiftUI
import ContainedDesignSystem
import ContainedNavigation

struct NavigationPackageExample: View {
    @State private var isPresented = false

    private let originFrame = CGRect(x: 24,
                                     y: 24,
                                     width: Tokens.Toolbar.buttonGroupHeight,
                                     height: Tokens.Toolbar.buttonGroupHeight)

    var body: some View {
        ZStack(alignment: .topLeading) {
            DesignActionGroup(DesignAction(systemName: "plus", help: "Add") {
                isPresented = true
            })
            .padding(Tokens.Space.l)

            MorphingExpander(isPresented: $isPresented,
                             originFrame: originFrame,
                             target: .centered(size: Tokens.PanelSize.add)) {
                MorphPanelScaffold(width: Tokens.PanelSize.add.width) {
                    PanelHeader(symbol: "plus",
                                title: "Add",
                                subtitle: "Choose a starting point") {
                        DesignActionGroup(DesignAction(systemName: "xmark",
                                                       help: "Close",
                                                       isCancel: true) {
                            isPresented = false
                        })
                    }
                    Divider()
                } content: {
                    VStack(spacing: Tokens.Space.s) {
                        GlassOptionTile(symbol: "play.rectangle",
                                        title: "Run a container",
                                        subtitle: "Start from an image") {
                            isPresented = false
                        }
                        GlassOptionTile(symbol: "square.stack.3d.up",
                                        title: "Use an existing image",
                                        subtitle: "Pick from local images") {
                            isPresented = false
                        }
                    }
                    .padding(Tokens.Space.s)
                }
            }
        }
        .environment(\.appSafeAreas,
                      AppSafeAreaManager(topToolbarHeight: Tokens.Toolbar.band,
                                         bottomToolbarHeight: Tokens.Toolbar.band))
    }
}
```

For a card-like detail surface, keep the compact source laid out in its grid
slot, hide that source while selected, and render one promoted overlay through
`MorphingSingleSurface`:

```swift
MorphingSingleSurface(source: sourceFrame,
                      target: detailFrame,
                      progress: isExpanded ? 1 : 0) {
    DetailCard()
}
```

When the card needs the same open/close lifecycle as a morph panel but already
draws its own surface, use `MorphingSingleSurfaceExpander` instead of
`MorphingExpander`:

```swift
MorphingSingleSurfaceExpander(isPresented: $isPresented,
                              originFrame: sourceFrame,
                              target: .anchored(size: Tokens.PanelSize.imageDetail)) {
    ExpandedResourceCard()
}
```

## Safe-Area Policies

Use `AppMorphTarget.centered(size:)` for modal-like work, such as creation
details. Use `AppMorphTarget.anchored(size:)` when a panel should grow from and
stay near its source control. Both paths use `AppSafeAreaManager` to avoid
toolbar bands and system insets.

For real toolbar sources, measure source controls in the same named coordinate
space that hosts the morph overlay:

```swift
Button("Open") { isPresented = true }
    .background(MorphSourceFrameReader("settings",
                                       coordinateSpaceName: "toolbar"))
    .onPreferenceChange(MorphSourceFramesKey<String>.self) { frames = $0 }
```

## Documentation

- DocC landing page:
  `Sources/ContainedNavigation/ContainedNavigation.docc/ContainedNavigation.md`
- Design package:
  `../ContainedDesignSystem/README.md`
- App architecture:
  `../../docs/wiki/Architecture.md`

## Verification

Build the package by itself:

```sh
swift build --package-path Packages/ContainedNavigation
```

Build it through the app graph:

```sh
swift build
swift test
```
