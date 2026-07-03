import SwiftUI

public extension UI.State {
struct ActivityStatus: Equatable, Sendable {
    public var title: String
    public var detail: String
    public var fraction: Double?

    public init(title: String, detail: String = "", fraction: Double? = nil) {
        self.title = title
        self.detail = detail
        self.fraction = fraction
    }
}

/// The app's single "something is happening" asset, driven by plain status text. One source of
/// truth for the spinner + title (+ progress) so the same operation reads identically wherever it
/// surfaces — currently the bottom-left status capsule, which morphs from the idle service status into
/// this while a long-running operation (e.g. an image pull) is in flight.
///
/// `.inline` is the compact one-line form sized for a toolbar capsule; `.expanded` is the taller card
/// with a linear progress bar and the streaming detail line.
struct ActivityStatusIndicator: View {
    public enum Style { case inline, expanded }

    public let activity: UI.State.ActivityStatus
    public var style: Style = .inline

    public init(activity: UI.State.ActivityStatus, style: Style = .inline) {
        self.activity = activity
        self.style = style
    }

    public var body: some View {
        switch style {
        case .inline:   inlineBody
        case .expanded: expandedBody
        }
    }

    private var inlineBody: some View {
        HStack(spacing: UI.Tokens.Toolbar.searchIconGap) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
                .frame(width: UI.Tokens.Toolbar.buttonItemHeight - UI.Tokens.Toolbar.iconInnerPadding * 2)
            Text(activity.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)
            if let percent = percentText {
                Text(percent)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.trailing, UI.Tokens.Toolbar.iconInnerPadding * 2)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: UI.Tokens.Space.s) {
                ProgressView().controlSize(.small)
                Text(activity.title).font(.callout.weight(.medium))
                Spacer(minLength: 0)
                if let percent = percentText {
                    Text(percent).font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            if let fraction = activity.fraction {
                ProgressView(value: fraction).progressViewStyle(.linear)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
            if !activity.detail.isEmpty {
                Text(activity.detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var percentText: String? {
        guard let fraction = activity.fraction else { return nil }
        return "\(Int((fraction * 100).rounded()))%"
    }
}
}

#Preview("Activity Status") {
    VStack(alignment: .leading, spacing: UI.Tokens.Space.l) {
        UI.State.ActivityStatusIndicator(activity: UI.State.ActivityStatus(title: "Pulling image",
                                                                           detail: "sha256:preview",
                                                                           fraction: 0.64),
                                         style: .inline)
            .padding(UI.Tokens.Space.s)
            .materialCapsuleSurface(shadow: false)

        UI.State.ActivityStatusIndicator(activity: UI.State.ActivityStatus(title: "Building image",
                                                                           detail: "RUN swift build",
                                                                           fraction: 0.42),
                                         style: .expanded)
            .padding(UI.Tokens.Space.l)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 420)
}
