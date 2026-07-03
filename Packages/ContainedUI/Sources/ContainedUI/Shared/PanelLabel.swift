import SwiftUI

struct SharedPanelLabel: View {
    var title: String
    var info: String?
    var error: String?
    var highlighted: Bool
    var hovering: Bool
    var width: CGFloat?

    var body: some View {
        label
            .optionalFixedWidth(width)
    }

    private var label: some View {
        HStack(spacing: UI.Tokens.Space.xs) {
            Text(title)
                .foregroundStyle(labelColor)
            if let info {
                UI.Control.InfoButton(info, visible: hovering)
            }
        }
    }

    private var labelColor: Color {
        if error != nil { return .red }
        return highlighted ? .accentColor : .primary
    }
}

private extension View {
    @ViewBuilder
    func optionalFixedWidth(_ width: CGFloat?) -> some View {
        if let width {
            frame(width: width, alignment: .leading)
        } else {
            self
        }
    }
}
