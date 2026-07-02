# ContainedDesignSystem

`ContainedDesignSystem` is the local Swift package that owns Contained's reusable
SwiftUI/AppKit visual language.

Use it for app-agnostic UI primitives: tokens, glass surfaces, panel/page/sheet
scaffolds, toolbar controls, resource-card chrome, sparklines, JSON/stream
surfaces, color controls, clipboard helpers, and small chrome such as badges,
keycaps, status dots, metric tiles, terminal surfaces, and selection overlays.

Do not put app state, stores, SwiftData models, Sparkle wiring, routing, runtime
models, or feature-specific business rules in this package. App code should pass
plain values into package views instead.

## Importing

From the root app package:

```swift
.product(name: "ContainedDesignSystem", package: "ContainedDesignSystem")
```

From Swift code:

```swift
import SwiftUI
import ContainedDesignSystem
```

This package currently depends only on platform frameworks available to a macOS
26 SwiftUI app.

## What Belongs Here

- `Tokens` for spacing, radius, toolbar, panel, icon, form, chart, badge,
  keycap, card, terminal, and menu-bar constants.
- `WindowMaterial`, `AppTint`, `ColorLayerBlendMode`, and root environment
  values for shared material/tint policy.
- `GlassSurface`, `glassSurface`, `glassCapsuleSurface`, and visual-effect
  helpers for all reusable glass treatment.
- `PanelHeader`, `PanelSection`, `PanelRow`, `PanelField`, `SheetHeader`, and
  `PageScaffold` for app-neutral scaffolding.
- `GlassButton`, `GlassButtonItem`, `GlassButtonInputItem`, `GlassRowMenu`, and
  toolbar control helpers.
- `ResourceGlassCard`, `ResourceCardPageControls`, `ResourceCardFooterChip`,
  `ResourceCardFooterButton`, `ResourceCardInsetSection`, and other
  `ResourceCard*` pieces for repeated card layouts and card-local controls.
  Use `resourceCardFloatingControls` and `resourceCardProgressOverlay` for
  card overlays instead of app-local `.overlay` recipes.
- `ActivityStatusView` with `ActivityStatusPresentation`, where callers provide
  plain status text/progress instead of app model objects.
- `DesignContentSurface` and `DesignInputSurface` for non-card content and
  input surfaces. Feature code should use these named routes instead of calling
  the lower-level surface modifiers directly.
- `LiveSparkline`, `GraphStyle`, `WidgetInterpolation`, and `SparklineScale`
  for Swift Charts-backed live graph widgets. Use `.fraction` for values that
  already live on a 0...1 scale, and `.normalized` for byte/rate series that
  should fill the compact chart.
- Micro-primitives such as `DesignStatusDot`, `DesignStatusBadge`,
  `DesignKeyCap`, `DesignKeyboardHint`, `DesignTintSwatch`, and
  `DesignMetricTile`.

## App Root Setup

Seed package environment values once at the shell/root instead of restyling
individual views:

```swift
struct AppRoot: View {
    var body: some View {
        DesignSystemExample()
            .tint(AppTint.azure.color)
            .environment(\.modalMaterial, WindowMaterial.sheet)
            .environment(\.buttonMaterial, WindowMaterial.glassClear)
            .environment(\.cardMaterial, WindowMaterial.glassRegular)
            .environment(\.buttonTintStyle, GlassButtonTintStyle(enabled: true,
                                                                 tint: .azure,
                                                                 opacity: 0.18))
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

                ActivityStatusView(
                    activity: ActivityStatusPresentation(title: "Pulling image",
                                                         detail: "nginx:latest",
                                                         fraction: 0.42),
                    style: .expanded
                )
            }
        }
        .environment(\.cardMaterial, .glassRegular)
        .environment(\.buttonMaterial, .glassClear)
        .environment(\.designSystemShowsInfoTips, true)
    }
}
```

## Resource Card Controls

Keep card-local controls in the package. Feature views should provide plain
values and actions instead of restyling footer chips or expanded-card page rails:

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
        ResourceGlassCard(size: .large) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: "shippingbox.fill")
            } content: {
                ResourceCardTitleText(text: "web")
            } trailing: {
                EmptyView()
            }
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
        .overlay(alignment: .topTrailing) {
            ResourceCardPageControls(items: pages,
                                     selection: page,
                                     tint: .accentColor,
                                     onSelect: { page = $0 },
                                     onClose: {})
                .padding(Tokens.Space.s)
        }
    }
}
```

For standalone empty states or input chrome, keep the surface choice in this
package too:

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

## Documentation

- DocC landing page:
  `Sources/ContainedDesignSystem/ContainedDesignSystem.docc/ContainedDesignSystem.md`
- App-level guidance:
  `../../docs/wiki/Design-System.md`
- Navigation package:
  `../ContainedNavigation/README.md`

## Verification

Build the package by itself:

```sh
swift build --package-path Packages/ContainedDesignSystem
```

Build it through the app graph:

```sh
swift build
swift test
```
