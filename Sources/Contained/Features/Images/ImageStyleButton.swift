import SwiftUI
import ContainedCore

/// Image row identity chip. If the image has a saved default style, this displays it and opens the
/// same compact customization popover used by container cards.
struct ImageStyleButton: View {
    let reference: String
    let style: Personalization
    let target: CustomizeSheet.Target

    @State private var hovering = false
    @State private var showingCustomize = false

    var body: some View {
        Button { showingCustomize = true } label: {
            Image(systemName: hovering ? "paintbrush.pointed.fill" : style.symbol)
                .font(.title3)
                .foregroundStyle(style.color)
                .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Customize image style")
        .accessibilityLabel("Customize \(Format.shortImage(reference)) image style")
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(target: target, presentation: .popover)
        }
    }
}

/// A generic identity chip that opens the customize popover for any `CustomizeSheet.Target` (images,
/// volumes, …). Mirrors `ImageStyleButton` but isn't image-specific.
struct CardStyleButton: View {
    let style: Personalization
    let target: CustomizeSheet.Target
    var help = "Customize"

    @State private var hovering = false
    @State private var showingCustomize = false

    var body: some View {
        Button { showingCustomize = true } label: {
            Image(systemName: hovering ? "paintbrush.pointed.fill" : style.symbol)
                .font(.title3)
                .foregroundStyle(style.color)
                .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(target: target, presentation: .popover)
        }
    }
}
