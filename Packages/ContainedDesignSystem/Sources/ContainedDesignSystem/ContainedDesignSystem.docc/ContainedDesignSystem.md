# ``ContainedDesignSystem``

Reusable SwiftUI/AppKit visual primitives for Contained.

## Overview

`ContainedDesignSystem` owns app-agnostic visual policy: spacing, padding,
radius, material, tint, glass surfaces, panel/page/sheet scaffolds, toolbar
controls, resource-card chrome, sparklines, JSON/stream surfaces, color controls,
clipboard helpers, and small chrome such as badges, keycaps, status dots, metric
tiles, terminal surfaces, and selection overlays.

Do not add app state, stores, SwiftData models, Sparkle wiring, routing, runtime
models, or feature-specific business rules here. Convert app/domain state into
plain values before passing it to package views.

## Configure Shared Policy Once

Set material and shell policy near the app root:

```swift
struct AppRoot: View {
    var body: some View {
        DesignSystemExample()
            .tint(AppTint.azure.color)
            .environment(\.modalMaterial, WindowMaterial.sheet)
            .environment(\.buttonMaterial, WindowMaterial.glassClear)
            .environment(\.cardMaterial, WindowMaterial.glassRegular)
            .environment(\.buttonTintStyle, GlassButtonTintStyle(enabled: true,
                                                                 tint: .azure))
            .environment(\.designSystemShowsInfoTips, true)
            .environment(\.pageScaffoldUsesToolbarChrome, false)
            .environment(\.pageScaffoldBottomClearance, 0)
    }
}
```

## Example

```swift
import SwiftUI
import ContainedDesignSystem

struct DesignSystemExample: View {
    @State private var tint = AppTint.azure

    var body: some View {
        PageScaffold(symbol: "shippingbox",
                     title: "Containers",
                     subtitle: "Local runtime") {
            VStack(spacing: Tokens.Space.l) {
                PanelSection(header: "Appearance") {
                    PanelRow(title: "Accent") {
                        TintSelector(selection: $tint)
                    }
                    PanelRow(title: "Shortcut") {
                        DesignKeyboardHint("return", "Open")
                    }
                }

                ResourceGlassCard(size: .small, elevated: false) {
                    ResourceCardHeader {
                        ResourceCardIconChip(symbol: "shippingbox.fill",
                                             tint: tint.color)
                    } content: {
                        VStack(alignment: .leading,
                               spacing: Tokens.ResourceCard.compactTextSpacing) {
                            ResourceCardTitleText(text: "web")
                            ResourceCardSubtitleText(text: "nginx:latest")
                        }
                    } trailing: {
                        GlassListRowChevron()
                    }
                }
                .selectionFill()
            }
        }
        .environment(\.cardMaterial, .glassRegular)
        .environment(\.buttonMaterial, .glassClear)
    }
}
```

## Topics

### Tokens and Theme

- ``Tokens``
- ``WindowMaterial``
- ``AppTint``
- ``ColorLayerBlendMode``
- ``GlassButtonTintStyle``

### Surfaces and Scaffolds

- ``GlassSurface``
- ``GlassCapsuleSurface``
- ``PageScaffold``
- ``PanelHeader``
- ``PanelSection``
- ``PanelRow``
- ``PanelField``
- ``PanelToggleRow``
- ``SheetHeader``

### Toolbar Controls

- ``GlassButton``
- ``GlassButtonItem``
- ``GlassButtonInputItem``
- ``GlassRowMenu``

### Resource Cards

- ``ResourceGlassCard``
- ``ResourceCardHeader``
- ``ResourceCardIconChip``
- ``ResourceBadgeText``
- ``ResourceCardFooterMini``
- ``ResourceCardTitleText``
- ``ResourceCardSubtitleText``
- ``ResourceCardMonospacedSubtitleText``
- ``ResourceCardMetricText``

### Data Display and Micro Chrome

- ``ActivityStatusView``
- ``ActivityStatusPresentation``
- ``LiveSparkline`` for lightweight Canvas-backed live graph widgets
- ``GraphStyle``
- ``WidgetInterpolation``
- ``MetricTile``
- ``DesignStatusDot``
- ``DesignStatusBadge``
- ``DesignKeyCap``
- ``DesignKeyboardHint``
- ``DesignTintSwatch``
- ``DesignMetricTile``

### Utilities

- ``TintSelector``
- ``GradientAngleControl``
- ``JSONInspectorSheet``
- ``InlineJSONView``
- ``StreamConsole``
- ``copyToPasteboard(_:)``
