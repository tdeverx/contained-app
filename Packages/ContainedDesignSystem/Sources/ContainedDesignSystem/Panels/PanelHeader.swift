import SwiftUI

/// Standard in-window panel header for toolbar morphs and embedded panels.
public struct PanelHeader<Trailing: View>: View {
    public let symbol: String
    public let title: String
    public var subtitle: String?
    public var padding: CGFloat = DesignTokens.Space.s
    public var leadingReserve: CGFloat = 0
    @ViewBuilder var trailing: () -> Trailing

    public init(symbol: String,
                title: String,
                subtitle: String? = nil,
                padding: CGFloat = DesignTokens.Space.s,
                leadingReserve: CGFloat = 0,
                @ViewBuilder trailing: @escaping () -> Trailing) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.padding = padding
        self.leadingReserve = leadingReserve
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.s) {
            if leadingReserve > 0 {
                Color.clear
                    .frame(width: leadingReserve, height: DesignTokens.Toolbar.buttonGroupHeight)
            }
            GlassButtonItem(systemName: symbol, help: title, isLabel: true)
                .frame(width: DesignTokens.Toolbar.buttonGroupHeight,
                       height: DesignTokens.Toolbar.buttonGroupHeight,
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
                   minHeight: DesignTokens.Toolbar.buttonGroupHeight,
                   alignment: .leading)
            trailing()
        }
        .frame(minHeight: DesignTokens.Toolbar.buttonGroupHeight)
        .padding(padding)
    }
}
