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

                ResourceCard(size: .small,
                             elevated: false,
                             title: "web",
                             subtitle: "nginx:latest") {
                    ResourceCardIconChip(symbol: "shippingbox.fill",
                                         tint: tint.color)
                } titleAccessory: {
                    EmptyView()
                } subtitleAccessory: {
                    EmptyView()
                } headerAccessory: {
                    GlassListRowChevron()
                } bodyContent: {
                    EmptyView()
                } footerLeading: {
                    EmptyView()
                } footerActions: {
                    EmptyView()
                } widget: {
                    EmptyView()
                }
                .selectionFill()
            }
        }
        .environment(\.cardMaterial, .glassRegular)
        .environment(\.buttonMaterial, .glassClear)
    }
}
```

## Resource Card Controls

Use `ResourceCard` for cards. Feature views pass plain titles, subtitles, page
IDs, labels, metric strings, and actions; the package owns header/body/widget/footer
placement:

`ResourceCard` owns card anatomy:

- the header is always sticky and visible
- page controls are declared through `ResourceCardPages`, stay mounted in the
  header trailing slot, and use `controlsReveal` for visibility
- the body appears only when the card is expanded
- the widget is sticky for `.large` cards and becomes body content for `.medium`
- the footer is sticky for `.medium` and `.large` cards and becomes body content for `.small`

```swift
struct CardControlsExample: View {
    @State private var page = "overview"
    @State private var metric = "cpu"

    private let pages = [
        ResourceCardPageControlItem(id: "overview",
                                    title: "Overview",
                                    systemImage: "rectangle.grid.1x2"),
        ResourceCardPageControlItem(id: "logs",
                                    title: "Logs",
                                    systemImage: "text.alignleft")
    ]

    var body: some View {
        ResourceCard(size: .large,
                     title: "web",
                     subtitle: "nginx:latest",
                     pages: ResourceCardPages(items: pages,
                                              selection: page,
                                              tint: .accentColor,
                                              onSelect: { page = $0 },
                                              onClose: {})) {
            ResourceCardIconChip(symbol: "shippingbox.fill")
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            ResourceCardInsetSection(title: "Details") {
                ResourceCardSubtitleText(text: "Ready")
            }
        } footerLeading: {
            ResourceCardFooterChip(isSelected: metric == "cpu",
                                   tint: .accentColor,
                                   help: "CPU",
                                   action: { metric = "cpu" }) {
                Image(systemName: "cpu")
            } text: {
                ResourceCardMetricText(text: "12%")
            }
        } footerActions: {
            ResourceCardFooterButton(systemName: "play.fill",
                                     help: "Start",
                                     tint: .accentColor) {}
        } widget: {
            LiveSparkline(samples: [0, 0.12, 0.18],
                          color: .accentColor,
                          scale: .fraction)
                .frame(height: Tokens.ResourceCard.sparklineHeight)
        }
    }
}
```

Use package-owned surfaces for standalone empty states and input chrome:

```swift
DesignContentSurface(minHeight: 220) {
    ContentUnavailableView("No matches", systemImage: "magnifyingglass")
}

DesignInputSurface {
    HStack {
        Image(systemName: "magnifyingglass")
        TextField("Search", text: $query)
            .textFieldStyle(.plain)
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

- ``ResourceCard``
- ``ResourceCardPages``
- ``ResourceCardNoPage``
- ``ResourceCardTextStyle``
- ``ResourceGlassCard``
- ``ResourceCardHeader``
- ``ResourceCardHeaderTextBlock``
- ``ResourceCardIconChip``
- ``ResourceBadgeText``
- ``ResourceCardFooterMini``
- ``ResourceCardWidgetGroup``
- ``ResourceCardFooterChip``
- ``ResourceCardFooterButton``
- ``ResourceCardInsetSection``
- ``ResourceCardPageControls``
- ``ResourceCardPageControlItem``
- ``View/resourceCardFloatingControls(when:controls:)``
- ``View/resourceCardProgressOverlay(when:)``
- ``ResourceCardTitleText``
- ``ResourceCardSubtitleText``
- ``ResourceCardMonospacedSubtitleText``
- ``ResourceCardMetricText``

### Data Display and Micro Chrome

- ``ActivityStatusView``
- ``ActivityStatusPresentation``
- ``LiveSparkline`` for Swift Charts-backed live graph widgets
- ``GraphStyle``
- ``WidgetInterpolation``
- ``SparklineScale``
- ``MetricTile``
- ``DesignStatusDot``
- ``DesignStatusBadge``
- ``DesignContentSurface``
- ``DesignInputSurface``
- ``DesignKeyCap``
- ``DesignKeyboardHint``
- ``DesignTintSwatch``
- ``DesignMetricTile``

### Utilities

- ``TintSelector``
- ``GradientAngleControl``
- ``StreamConsole``
- ``copyToPasteboard(_:)``
