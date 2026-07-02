# ContainedDesignSystem

`ContainedDesignSystem` is the local Swift package that owns Contained's reusable
SwiftUI/AppKit visual language.

Use it for app-agnostic UI primitives: tokens, glass surfaces, panel/page/sheet
scaffolds, toolbar controls, design-card chrome, sparklines, JSON/stream
surfaces, color controls, clipboard helpers, and small chrome such as badges,
keycaps, status dots, metric tiles, terminal surfaces, and selection overlays.

Do not put app state, stores, SwiftData models, Sparkle wiring, routing, runtime
models, or feature-specific business rules in this package. App code should pass
plain values into package views instead.

This package also does not own localized resources or English UI defaults. When
a primitive needs visible text, accessibility copy, help, display names, or
error/failure messages, the app supplies those strings through parameters. The
app target owns localization keys and English fallbacks.

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

- `DesignTokens` for spacing, radius, toolbar, panel, icon, form, chart, badge,
  keycap, card, terminal, and menu-bar constants.
- `WindowMaterial`, `DesignTint`, `ColorLayerBlendMode`, and root environment
  values for shared material/tint policy.
- Named surface routes such as `DesignContentSurface`, `DesignInputSurface`,
  panel scaffolds, and toolbar controls. Low-level glass modifiers and
  visual-effect bridges are package implementation details.
- `PanelHeader`, `PanelSection`, `PanelRow`, `PanelField`, `SheetHeader`, and
  `PageScaffold` for app-neutral scaffolding.
- `DesignActionGroup`, `DesignActionCluster`, `DesignInputCluster`,
  `DesignTextActionButton`, `DesignToggleButton`, `DesignSelectionActionBar`,
  `DesignStatusBanner`, and toolbar controls for package-owned command chrome.
  Low-level glass button groups are package implementation details behind these
  named controls.
- `DesignOptionStack` and `DesignOptionTile` for option grids and creation-style
  choice lists.
- `DesignCard`, `DesignCardPages`, `DesignCardFooterChip`,
  `DesignCardFooterButton`, `DesignCardWidgetGroup`, `DesignCardInsetSection`,
  and other `DesignCard*` pieces for repeated card layouts and card-local controls.
  App code should use `DesignCard`; card shell, header, and page-rail assembly is
  package-owned.
  Use `designCardFloatingControls` and `designCardProgressOverlay` for
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
            .tint(DesignTint.azure.color)
            .environment(\.modalMaterial, WindowMaterial.sheet)
            .environment(\.buttonMaterial, WindowMaterial.glassClear)
            .environment(\.cardMaterial, WindowMaterial.glassRegular)
            .environment(\.buttonTintStyle, DesignButtonTintStyle(enabled: true,
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
    @State private var tint = DesignTint.azure

    var body: some View {
        PageScaffold(symbol: "shippingbox",
                     title: "Containers",
                     subtitle: "Local runtime") {
            VStack(spacing: DesignTokens.Space.l) {
                PanelSection(header: "Appearance") {
                    PanelRow(title: "Accent") {
                        TintSelector(selection: $tint, labelForTint: tintName)
                    }
                    PanelRow(title: "Shortcut") {
                        DesignKeyboardHint("return", "Open")
                    }
                }

                DesignCard(size: .small,
                             elevated: false,
                             title: "web",
                             subtitle: "nginx:latest") {
                    DesignCardIconChip(symbol: "shippingbox.fill",
                                         tint: tint.color)
                } titleAccessory: {
                    EmptyView()
                } subtitleAccessory: {
                    EmptyView()
                } headerAccessory: {
                    DesignListRowChevron()
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

    private func tintName(_ tint: DesignTint) -> String {
        switch tint {
        case .multicolor: return "App Accent"
        case .graphite: return "Graphite"
        case .azure: return "Azure"
        case .teal: return "Teal"
        case .coral: return "Coral"
        case .indigo: return "Indigo"
        case .green: return "Green"
        case .amber: return "Amber"
        case .pink: return "Pink"
        }
    }
}
```

## Design Card Controls

Keep card-local controls in the package. Feature views provide plain values and
actions instead of assembling headers, footer groups, or expanded-card page rails:

`DesignCard` owns card anatomy:

- the header is always sticky and visible
- page controls are declared through `DesignCardPages`, stay mounted in the
  header trailing slot, and use `controlsReveal` for visibility
- the body appears only when the card is expanded
- the widget is sticky for `.large` cards and becomes body content for `.medium`
- the footer is sticky for `.medium` and `.large` cards and becomes body content for `.small`

```swift
struct CardControlsExample: View {
    @State private var page = "overview"
    @State private var metric = "cpu"

    private let pages = [
        DesignCardPageControlItem(id: "overview",
                                    title: "Overview",
                                    systemImage: "rectangle.grid.1x2"),
        DesignCardPageControlItem(id: "logs",
                                    title: "Logs",
                                    systemImage: "text.alignleft")
    ]

    var body: some View {
        DesignCard(size: .large,
                     title: "web",
                     subtitle: "nginx:latest",
                     pages: DesignCardPages(items: pages,
                                              selection: page,
                                              tint: .accentColor,
                                              closeLabel: "Close",
                                              onSelect: { page = $0 },
                                              onClose: {})) {
            DesignCardIconChip(symbol: "shippingbox.fill")
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            DesignCardInsetSection(title: "Details") {
                DesignCardSubtitleText(text: "Ready")
            }
        } footerLeading: {
            DesignCardFooterChip(isSelected: metric == "cpu",
                                   tint: .accentColor,
                                   help: "CPU",
                                   action: { metric = "cpu" }) {
                Image(systemName: "cpu")
            } text: {
                DesignCardMetricText(text: "12%")
            }
        } footerActions: {
            DesignCardFooterButton(systemName: "play.fill",
                                     help: "Start",
                                     tint: .accentColor) {}
        } widget: {
            LiveSparkline(samples: [0, 0.12, 0.18],
                          color: .accentColor,
                          scale: .fraction)
                .frame(height: DesignTokens.DesignCard.sparklineHeight)
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

## Action and Toolbar Controls

Feature views should pass action intent into package controls. Do not restate
glass button styles, capsule surfaces, hover treatment, or toolbar search chrome
in the app target.

```swift
DesignActionGroup([
    DesignAction(systemName: "doc.on.doc", help: "Copy") {
        copyToPasteboard(output)
    },
    DesignAction(systemName: "trash",
                 help: "Clear",
                 role: .destructive) {
        clear()
    }
])

DesignActionCluster {
    Menu {
        Button("All") {}
    } label: {
        DesignMenuActionLabel(systemName: "line.3.horizontal.decrease",
                              help: "Filter")
    }
    DesignActionItems([
        DesignAction(systemName: "checkmark.circle", help: "Mark read") {}
    ])
}

DesignInputCluster {
    Image(systemName: "magnifyingglass")
    TextField("Search", text: $query)
        .textFieldStyle(.plain)
}

DesignTextActionButton(title: "Import",
                       systemName: "arrow.down.doc",
                       prominence: .prominent,
                       isEnabled: canImport) {
    importArchive()
}

DesignToggleButton(isOn: $following,
                  title: "Follow",
                  systemName: "arrow.down.to.line")

DesignSelectionActionBar(count: selection.count, actions: [
    DesignAction(systemName: "play.fill", title: "Start") { startSelection() },
    DesignAction(systemName: "trash",
                 title: "Delete",
                 role: .destructive) { deleteSelection() }
])
```

Toolbar-specific controls follow the same rule:

```swift
DesignToolbarSearchField(text: $query,
                         prompt: "Search this page",
                         focused: $focused,
                         onClear: { query = "" }) {
    DesignKeyboardHint("command", "K")
}
```

## Documentation

- DocC landing page:
  `Sources/ContainedDesignSystem/ContainedDesignSystem.docc/ContainedDesignSystem.md`
- App-level guidance:
  `../../docs/architecture/Design-System.md`
- Navigation package:
  `../ContainedNavigation/README.md`

## Verification

Build and test the package by itself:

```sh
swift build --package-path Packages/ContainedDesignSystem
swift test --package-path Packages/ContainedDesignSystem
```

Build it through the app graph:

```sh
swift build
swift test
```
