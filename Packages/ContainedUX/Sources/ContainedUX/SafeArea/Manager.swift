import SwiftUI
import ContainedUI

public extension UX.SafeArea {
struct ToolbarExclusion: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let top = UX.SafeArea.ToolbarExclusion(rawValue: 1 << 0)
    public static let bottom = UX.SafeArea.ToolbarExclusion(rawValue: 1 << 1)
    public static let both: UX.SafeArea.ToolbarExclusion = [.top, .bottom]
}

enum Padding: CGFloat, Equatable, Sendable {
    case none = 0
    case small = 8
    case medium = 16
    case large = 24
}

struct Policy: Equatable, Sendable {
    public var excluding: UX.SafeArea.ToolbarExclusion
    public var padding: UX.SafeArea.Padding
    public var includesSystemInsets: Bool

    public init(excluding: UX.SafeArea.ToolbarExclusion = .both,
                padding: UX.SafeArea.Padding = .small,
                includesSystemInsets: Bool = true) {
        self.excluding = excluding
        self.padding = padding
        self.includesSystemInsets = includesSystemInsets
    }

    public static let fullBleed = UX.SafeArea.Policy(excluding: [], padding: .none)
    public static let toolbarChrome = UX.SafeArea.Policy(excluding: [], padding: .small)
    public static let content = UX.SafeArea.Policy(excluding: .both, padding: .medium)
}

struct Manager: Equatable, Sendable {
    public var system: EdgeInsets
    public var topToolbarHeight: CGFloat
    public var bottomToolbarHeight: CGFloat

    public init(system: EdgeInsets = EdgeInsets(),
                topToolbarHeight: CGFloat = 0,
                bottomToolbarHeight: CGFloat = 0) {
        self.system = system
        self.topToolbarHeight = topToolbarHeight
        self.bottomToolbarHeight = bottomToolbarHeight
    }

    public init(system: EdgeInsets = EdgeInsets(), toolbarHeight: CGFloat) {
        self.init(system: system, topToolbarHeight: toolbarHeight, bottomToolbarHeight: 0)
    }

    public func insets(_ policy: UX.SafeArea.Policy = .content) -> EdgeInsets {
        let padding = policy.padding.rawValue
        let systemInsets = policy.includesSystemInsets ? system : EdgeInsets()
        // On an edge that excludes its toolbar, the band *is* the inset — the padding doesn't stack on
        // top of it. Edges without a toolbar exclusion get the padding instead.
        return EdgeInsets(top: systemInsets.top + (policy.excluding.contains(.top) ? topToolbarHeight : padding),
                          leading: systemInsets.leading + padding,
                          bottom: systemInsets.bottom + (policy.excluding.contains(.bottom) ? bottomToolbarHeight : padding),
                          trailing: systemInsets.trailing + padding)
    }

    public func bounds(in size: CGSize, policy: UX.SafeArea.Policy = .content) -> CGRect {
        let safeInsets = insets(policy)
        return CGRect(x: safeInsets.leading,
                      y: safeInsets.top,
                      width: max(1, size.width - safeInsets.leading - safeInsets.trailing),
                      height: max(1, size.height - safeInsets.top - safeInsets.bottom))
    }
}
}

public extension EnvironmentValues {
    @Entry var morphSafeAreaManager = UX.SafeArea.Manager()
}

#Preview("Morph Safe Area") {
    SafeAreaManagerPreview()
        .frame(width: 420, height: 260)
}

private struct SafeAreaManagerPreview: View {
    private let manager = UX.SafeArea.Manager(topToolbarHeight: UI.Toolbar.Size.band,
                                              bottomToolbarHeight: UI.Toolbar.Size.band)

    var body: some View {
        GeometryReader { proxy in
            let bounds = manager.bounds(in: proxy.size, policy: .content)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: UI.Card.Radius.expanded, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: bounds.width, height: bounds.height)
                    .position(x: bounds.midX, y: bounds.midY)
                Text("content bounds")
                    .font(.caption)
                    .padding(UI.Layout.Spacing.s)
            }
        }
        .padding(UI.Layout.Spacing.xl)
    }
}
