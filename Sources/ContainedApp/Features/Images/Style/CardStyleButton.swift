import SwiftUI
import ContainedUI

/// Identity chip that opens the customize popover for any `CustomizeSheet.Target`.
struct CardStyleButton: View {
    @Environment(AppModel.self) private var app

    let style: Personalization
    let target: CustomizeSheet.Target
    var help = "Customize"
    var accessibilityLabel: String?

    @State private var hovering = false
    @State private var showingCustomize = false

    var body: some View {
        Button { showingCustomize = true } label: {
            UI.Card.IconChip(symbol: hovering ? "paintbrush.pointed.fill" : style.symbol,
                                 tint: style.color)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(accessibilityLabel ?? help)
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
            return app.personalization.hasAppearanceOverride(id: snapshot.scopedID)
        case .image(let reference), .imageTag(let reference, _):
            return app.personalization.hasImageAppearanceOverride(for: reference)
        case .imageGroup(let group):
            return app.personalization.hasImageGroupAppearanceOverride(for: group)
        case .volume:
            return true
        }
    }
}
