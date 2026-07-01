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
            ResourceCardHeader {
                ResourceCardIconChip(symbol: symbol, tint: tint)
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: title)
                    if !subtitle.isEmpty {
                        ResourceCardMonospacedSubtitleText(text: subtitle)
                    }
                }
            } trailing: {
                accessory()
            }
        }
    }
}
