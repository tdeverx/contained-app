import SwiftUI

/// A glass list row: leading icon chip, title + subtitle, trailing accessory.
struct ResourceRow<Accessory: View>: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: String
    var subtitle: String = ""
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.m) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.medium)).lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: Tokens.Space.s)
                accessory()
            }
        }
    }
}
