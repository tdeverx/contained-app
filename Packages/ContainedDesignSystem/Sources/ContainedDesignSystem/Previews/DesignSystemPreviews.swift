import SwiftUI

#Preview("Design Card") {
    DesignCardPreview()
        .padding(DesignTokens.Space.xl)
        .frame(width: 420)
        .environment(\.cardMaterial, .glassRegular)
        .environment(\.buttonMaterial, .glassClear)
}

#Preview("Design Controls") {
    VStack(alignment: .leading, spacing: DesignTokens.Space.l) {
        PanelSection(header: "Controls") {
            PanelRow(title: "Tint") {
                TintSelector(selection: .constant(.azure)) { tint in
                    tint.rawValue.capitalized
                }
            }
            PanelRow(title: "Actions") {
                DesignActionGroup([
                    DesignAction(systemName: "play.fill", help: "Start") {},
                    DesignAction(systemName: "stop.fill", help: "Stop", role: .destructive) {}
                ])
            }
        }

        CommandPreviewBar(command: ["container", "run", "--name", "preview-web", "nginx"],
                          copyHelp: "Copy command",
                          copiedAccessibilityLabel: "Copied")
    }
    .padding(DesignTokens.Space.xl)
    .frame(width: 520)
    .environment(\.buttonMaterial, .glassClear)
}

private struct DesignCardPreview: View {
    @State private var page = "overview"

    private let pages = [
        DesignCardPageControlItem(id: "overview", title: "Overview", systemImage: "rectangle.grid.1x2"),
        DesignCardPageControlItem(id: "stats", title: "Stats", systemImage: "chart.xyaxis.line"),
    ]

    var body: some View {
        DesignCard(size: .large,
                   isExpanded: true,
                   title: "preview-web",
                   subtitle: "docker.io/library/nginx:latest",
                   pages: DesignCardPages(items: pages,
                                          selection: page,
                                          tint: .accentColor,
                                          closeLabel: "Close",
                                          onSelect: { page = $0 },
                                          onClose: {})) {
            DesignCardIconChip(symbol: "shippingbox.fill", tint: .accentColor)
        } titleAccessory: {
            DesignBadgeText(text: "Running")
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            DesignCardInsetSection(title: "Live") {
                LiveSparkline(samples: [0.1, 0.2, 0.18, 0.4, 0.34, 0.55],
                              color: .accentColor,
                              scale: .fraction)
                    .frame(height: DesignTokens.DesignCard.sparklineHeight)
            }
        } footerLeading: {
            DesignCardFooterChip(isSelected: true, tint: .accentColor, help: "CPU", action: {}) {
                Image(systemName: "cpu")
            } text: {
                DesignCardMetricText(text: "42%")
            }
        } footerActions: {
            DesignCardFooterButton(systemName: "play.fill", help: "Start", tint: .accentColor) {}
        } widget: {
            DesignCardWidgetGroup {
                DesignCardFooterMini {
                    Image(systemName: "memorychip")
                } text: {
                    DesignCardMetricText(text: "420 MB")
                }
            }
        }
    }
}
