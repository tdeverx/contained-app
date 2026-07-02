#if CONTAINED_UI_PREVIEWS
import SwiftUI

#Preview("Card") {
    CardPreview()
        .padding(UI.Tokens.Space.xl)
        .frame(width: 420)
        .environment(\.cardMaterial, .glassRegular)
        .environment(\.buttonMaterial, .glassClear)
}

#Preview("Controls") {
    VStack(alignment: .leading, spacing: UI.Tokens.Space.l) {
        UI.Panel.Section(header: "Controls") {
            UI.Panel.Row(title: "Tint") {
                UI.Control.TintSelector(selection: .constant(.azure)) { tint in
                    tint.rawValue.capitalized
                }
            }
            UI.Panel.Row(title: "Actions") {
                UI.Action.Group([
                    UI.Action.Item(systemName: "play.fill", help: "Start") {},
                    UI.Action.Item(systemName: "stop.fill", help: "Stop", role: .destructive) {}
                ])
            }
        }

        UI.Command.PreviewBar(command: ["container", "run", "--name", "preview-web", "nginx"],
                          copyHelp: "Copy command",
                          copiedAccessibilityLabel: "Copied")
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 520)
    .environment(\.buttonMaterial, .glassClear)
}

private struct CardPreview: View {
    @State private var page = "overview"

    private let pages = [
        UI.Card.Page(id: "overview", title: "Overview", systemImage: "rectangle.grid.1x2"),
        UI.Card.Page(id: "stats", title: "Stats", systemImage: "chart.xyaxis.line"),
    ]

    var body: some View {
        UI.Card.Scaffold(size: .large,
                   isExpanded: true,
                   title: "preview-web",
                   subtitle: "docker.io/library/nginx:latest",
                   pages: UI.Card.Pages(items: pages,
                                          selection: page,
                                          tint: .accentColor,
                                          closeLabel: "Close",
                                          onSelect: { page = $0 },
                                          onClose: {})) {
            UI.Card.IconChip(symbol: "shippingbox.fill", tint: .accentColor)
        } titleAccessory: {
            UI.Badge.Text(text: "Running")
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            UI.Card.InsetSection(title: "Live") {
                UI.Chart.Sparkline(samples: [0.1, 0.2, 0.18, 0.4, 0.34, 0.55],
                              color: .accentColor,
                              scale: .fraction)
                    .frame(height: UI.Tokens.Card.sparklineHeight)
            }
        } footerLeading: {
            UI.Card.FooterChip(isSelected: true, tint: .accentColor, help: "CPU", action: {}) {
                Image(systemName: "cpu")
            } text: {
                UI.Card.MetricText(text: "42%")
            }
        } footerActions: {
            UI.Card.FooterButton(systemName: "play.fill", help: "Start", tint: .accentColor) {}
        } widget: {
            UI.Card.WidgetGroup {
                UI.Card.FooterMini {
                    Image(systemName: "memorychip")
                } text: {
                    UI.Card.MetricText(text: "420 MB")
                }
            }
        }
    }
}
#endif
