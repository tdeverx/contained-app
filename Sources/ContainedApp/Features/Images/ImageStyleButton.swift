import SwiftUI
import ContainedDesignSystem
import ContainedCore

/// Image row identity chip. If the image has a saved default style, this displays it and opens the
/// same compact customization popover used by container cards.
struct ImageStyleButton: View {
    @Environment(AppModel.self) private var app

    let reference: String
    let style: Personalization
    let target: CustomizeSheet.Target

    @State private var hovering = false
    @State private var showingCustomize = false

    var body: some View {
        Button { showingCustomize = true } label: {
            DesignCardIconChip(symbol: hovering ? "paintbrush.pointed.fill" : style.symbol,
                                 tint: style.color)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Customize image style")
        .accessibilityLabel(AppText.customizeImageStyleAccessibility(Format.shortImage(reference)))
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(target: target,
                           presentation: .popover,
                           initialStyle: style,
                           initiallyOverridesInheritedStyle: target.hasOwnStyle(in: app))
        }
    }
}

/// A generic identity chip that opens the customize popover for any `CustomizeSheet.Target` (images,
/// volumes, …). Mirrors `ImageStyleButton` but isn't image-specific.
struct CardStyleButton: View {
    @Environment(AppModel.self) private var app

    let style: Personalization
    let target: CustomizeSheet.Target
    var help = "Customize"

    @State private var hovering = false
    @State private var showingCustomize = false

    var body: some View {
        Button { showingCustomize = true } label: {
            DesignCardIconChip(symbol: hovering ? "paintbrush.pointed.fill" : style.symbol,
                                 tint: style.color)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(target: target,
                           presentation: .popover,
                           initialStyle: style,
                           initiallyOverridesInheritedStyle: target.hasOwnStyle(in: app))
        }
    }
}

private extension CustomizeSheet.Target {
    @MainActor
    func hasOwnStyle(in app: AppModel) -> Bool {
        switch self {
        case .container(let snapshot):
            return app.personalization.hasOverride(id: snapshot.id)
        case .image(let reference), .imageTag(let reference, _):
            return app.personalization.imageDefault(for: reference) != nil
        case .imageGroup(let id, _):
            return app.personalization.imageGroupDefault(for: id) != nil
        case .volume:
            return true
        }
    }
}
