import SwiftUI
import ContainedCore

/// Image row identity chip. If the image has a saved default style, this displays it and opens the
/// same compact customization popover used by container cards.
struct ImageStyleButton: View {
    let image: ContainedCore.ImageResource
    let style: Personalization

    @State private var hovering = false
    @State private var showingCustomize = false

    var body: some View {
        Button { showingCustomize = true } label: {
            Image(systemName: hovering ? "paintbrush.pointed.fill" : style.symbol)
                .font(.system(size: 15))
                .foregroundStyle(style.color)
                .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Customize image style")
        .accessibilityLabel("Customize \(Format.shortImage(image.reference)) image style")
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(target: .image(reference: image.reference), presentation: .popover)
        }
    }
}
