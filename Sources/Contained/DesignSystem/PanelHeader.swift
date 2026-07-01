import SwiftUI

/// Standard in-window panel header for toolbar morphs and embedded panels.
struct PanelHeader<Trailing: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    var padding: CGFloat = Tokens.Space.s
    var leadingReserve: CGFloat = 0
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.s) {
            if leadingReserve > 0 {
                Color.clear
                    .frame(width: leadingReserve, height: Tokens.Toolbar.buttonGroupHeight)
            }
            GlassButtonItem(systemName: symbol, help: title, isLabel: true)
                .frame(width: Tokens.Toolbar.buttonGroupHeight,
                       height: Tokens.Toolbar.buttonGroupHeight,
                       alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity,
                   minHeight: Tokens.Toolbar.buttonGroupHeight,
                   alignment: .leading)
            trailing()
        }
        .frame(minHeight: Tokens.Toolbar.buttonGroupHeight)
        .padding(padding)
    }
}
