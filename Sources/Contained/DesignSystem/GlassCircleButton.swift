import SwiftUI

/// A circular Liquid Glass icon button that matches the round glass buttons in the window toolbar.
/// Use `.glassProminent` for the primary action, `.glass` otherwise; `role: .destructive` tints it.
struct GlassCircleButton: View {
    let systemName: String
    var prominent: Bool = false
    var role: ButtonRole? = nil
    var tint: Color? = nil
    var help: String = ""
    /// Bind Escape to this button (sheet cancel/close), applied to the real Button so it actually fires.
    var isCancel: Bool = false
    var action: () -> Void

    var body: some View {
        if prominent {
            base.buttonStyle(.glassProminent)
        } else {
            base.buttonStyle(.glass)
        }
    }

    private var base: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: Tokens.IconSize.rowMenu, height: Tokens.IconSize.rowMenu)
        }
        .buttonBorderShape(.circle)
        .tint(role == .destructive ? .red : tint)
        .help(help)
        .accessibilityLabel(help.isEmpty ? systemName : help)
        .keyboardShortcut(isCancel ? .cancelAction : nil)
    }
}
