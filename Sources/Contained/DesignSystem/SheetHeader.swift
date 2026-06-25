import SwiftUI

/// Standard sheet header: a title (with optional subtitle), a flexible spacer, a cancel/close glass
/// button, and a trailing slot for confirm/primary actions or a progress spinner. Replaces the
/// hand-rolled header `HStack` + `GlassCircleButton` chain repeated across every sheet, so spacing,
/// padding, and the cancel affordance stay consistent.
struct SheetHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var cancelIcon: String = "xmark"
    var cancelHelp: String = "Cancel"
    let onCancel: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            GlassCircleButton(systemName: cancelIcon, help: cancelHelp, isCancel: true, action: onCancel)
            trailing()
        }
        .padding(Tokens.Space.l)
    }
}

extension SheetHeader where Trailing == EmptyView {
    /// Header with only a cancel/close button (no primary action).
    init(title: String, subtitle: String? = nil, cancelIcon: String = "xmark",
         cancelHelp: String = "Cancel", onCancel: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, cancelIcon: cancelIcon, cancelHelp: cancelHelp,
                  onCancel: onCancel) { EmptyView() }
    }
}
