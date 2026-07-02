import SwiftUI

/// Standard sheet header: a title (with optional subtitle), a flexible spacer, a cancel/close glass
/// button, and a trailing slot for confirm/primary actions or a progress spinner. Replaces the
/// hand-rolled header `HStack` + `GlassCircleButton` chain repeated across every sheet, so spacing,
/// padding, and the cancel affordance stay consistent.
public struct SheetHeader<Trailing: View>: View {
    public let title: String
    public var subtitle: String? = nil
    public var cancelIcon: String = "xmark"
    public var cancelHelp: String
    public let onCancel: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    public init(title: String,
                subtitle: String? = nil,
                cancelIcon: String = "xmark",
                cancelHelp: String,
                onCancel: @escaping () -> Void,
                @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.cancelIcon = cancelIcon
        self.cancelHelp = cancelHelp
        self.onCancel = onCancel
        self.trailing = trailing
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: cancelIcon, help: cancelHelp, isCancel: true, action: onCancel)
            }
            trailing()
        }
        .padding(DesignTokens.Space.l)
    }
}

public extension SheetHeader where Trailing == EmptyView {
    /// Header with only a cancel/close button (no primary action).
    init(title: String, subtitle: String? = nil, cancelIcon: String = "xmark",
         cancelHelp: String, onCancel: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, cancelIcon: cancelIcon, cancelHelp: cancelHelp,
                  onCancel: onCancel) { EmptyView() }
    }
}
