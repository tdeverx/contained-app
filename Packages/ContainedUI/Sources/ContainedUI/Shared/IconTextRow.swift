import SwiftUI

struct SharedIconTextRow<Title: View, Accessory: View>: View {
    var systemImage: String
    var tint: Color
    var iconFont: Font
    var iconWidth: CGFloat
    var rowSpacing: CGFloat
    var titleSubtitleSpacing: CGFloat
    var subtitle: String?
    var subtitleMonospaced: Bool
    var horizontalPadding: CGFloat?
    var verticalPadding: CGFloat
    var fillsWidth: Bool
    var action: (() -> Void)?
    @ViewBuilder var title: () -> Title
    @ViewBuilder var accessory: () -> Accessory

    init(systemImage: String,
         tint: Color = .secondary,
         iconFont: Font = .callout,
         iconWidth: CGFloat = UI.Tokens.IconSize.rowIconColumn,
         rowSpacing: CGFloat = UI.Tokens.Space.m,
         titleSubtitleSpacing: CGFloat = UI.Tokens.Card.compactTextSpacing,
         subtitle: String? = nil,
         subtitleMonospaced: Bool = false,
         horizontalPadding: CGFloat? = nil,
         verticalPadding: CGFloat = UI.Tokens.Space.s,
         fillsWidth: Bool = false,
         action: (() -> Void)? = nil,
         @ViewBuilder title: @escaping () -> Title,
         @ViewBuilder accessory: @escaping () -> Accessory) {
        self.systemImage = systemImage
        self.tint = tint
        self.iconFont = iconFont
        self.iconWidth = iconWidth
        self.rowSpacing = rowSpacing
        self.titleSubtitleSpacing = titleSubtitleSpacing
        self.subtitle = subtitle
        self.subtitleMonospaced = subtitleMonospaced
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.fillsWidth = fillsWidth
        self.action = action
        self.title = title
        self.accessory = accessory
    }

    var body: some View {
        row
            .padding(.horizontal, horizontalPadding ?? 0)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { action?() }
    }

    private var row: some View {
        HStack(spacing: rowSpacing) {
            Image(systemName: systemImage)
                .font(iconFont)
                .foregroundStyle(tint)
                .frame(width: iconWidth)
            VStack(alignment: .leading, spacing: titleSubtitleSpacing) {
                title()
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(subtitleMonospaced ? .system(.caption, design: .monospaced) : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: UI.Tokens.Space.s)
            accessory()
        }
    }
}
