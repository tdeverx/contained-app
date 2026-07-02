# ``ContainedNavigation``

Reusable navigation and layout infrastructure for Contained's window chrome.

## Overview

`ContainedNavigation` owns generic safe-area and morph-panel mechanics. It uses
`ContainedDesignSystem` for tokens and visual primitives, but it does not own app
routes, stores, toolbar panel contents, or feature decisions.

Host apps own localized strings. This package provides layout behavior and
accepts caller-supplied titles, help text, accessibility labels, and panel copy
through the views it composes.

Use this package when a view needs reusable layout behavior such as a panel that
grows from a toolbar source, clamps to app safe areas, and hosts fixed chrome
above scrollable content.

Card-like detail views can use `MorphingSingleSurface` when the source and
destination are the same conceptual surface rather than a toolbar-to-panel
handoff. Keep the source laid out, hide it while selected, and render one
promoted overlay from the measured source frame to the target frame.

## Example

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
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "plus", help: "Add") {
                    isPresented = true
                }
            }
            .padding(Tokens.Space.l)

            MorphingExpander(isPresented: $isPresented,
                             originFrame: originFrame,
                             target: .centered(size: Tokens.PanelSize.add)) {
                MorphPanelScaffold(width: Tokens.PanelSize.add.width) {
                    PanelHeader(symbol: "plus",
                                title: "Add",
                                subtitle: "Choose a starting point") {
                        GlassButton(singleItem: true) {
                            GlassButtonItem(systemName: "xmark",
                                            help: "Close",
                                            isCancel: true) {
                                isPresented = false
                            }
                        }
                    }
                    Divider()
                } content: {
                    VStack(spacing: Tokens.Space.s) {
                        Text("Panel content")
                            .frame(maxWidth: .infinity, alignment: .leading)
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

## Topics

### Safe Areas

- ``AppSafeAreaManager``
- ``AppSafeAreaPolicy``
- ``AppToolbarSafeAreaExclusion``
- ``AppSafeAreaPadding``

### Morph Targets and Geometry

- ``AppMorphTarget``
- ``MorphPanelPlacement``
- ``MorphGeometry``

### Morph Presentation

- ``MorphingExpander``
- ``MorphingSingleSurface``
- ``MorphingSingleSurfaceExpander``
- ``MorphFrame``
- ``MorphPanelScaffold``
- ``GlobalBackdropStyle``
