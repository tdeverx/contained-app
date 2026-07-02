import SwiftUI

public struct MorphToolbarSafeAreaExclusion: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let top = MorphToolbarSafeAreaExclusion(rawValue: 1 << 0)
    public static let bottom = MorphToolbarSafeAreaExclusion(rawValue: 1 << 1)
    public static let both: MorphToolbarSafeAreaExclusion = [.top, .bottom]
}

public enum MorphSafeAreaPadding: CGFloat, Equatable, Sendable {
    case none = 0
    case small = 8
    case medium = 16
    case large = 24
}

public struct MorphSafeAreaPolicy: Equatable, Sendable {
    public var excluding: MorphToolbarSafeAreaExclusion
    public var padding: MorphSafeAreaPadding
    public var includesSystemInsets: Bool

    public init(excluding: MorphToolbarSafeAreaExclusion = .both,
                padding: MorphSafeAreaPadding = .small,
                includesSystemInsets: Bool = true) {
        self.excluding = excluding
        self.padding = padding
        self.includesSystemInsets = includesSystemInsets
    }

    public static let fullBleed = MorphSafeAreaPolicy(excluding: [], padding: .none)
    public static let toolbarChrome = MorphSafeAreaPolicy(excluding: [], padding: .small)
    public static let content = MorphSafeAreaPolicy(excluding: .both, padding: .medium)
}

public struct MorphSafeAreaManager: Equatable, Sendable {
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

    public func insets(_ policy: MorphSafeAreaPolicy = .content) -> EdgeInsets {
        let padding = policy.padding.rawValue
        let systemInsets = policy.includesSystemInsets ? system : EdgeInsets()
        // On an edge that excludes its toolbar, the band *is* the inset — the padding doesn't stack on
        // top of it. Edges without a toolbar exclusion get the padding instead.
        return EdgeInsets(top: systemInsets.top + (policy.excluding.contains(.top) ? topToolbarHeight : padding),
                          leading: systemInsets.leading + padding,
                          bottom: systemInsets.bottom + (policy.excluding.contains(.bottom) ? bottomToolbarHeight : padding),
                          trailing: systemInsets.trailing + padding)
    }

    public func bounds(in size: CGSize, policy: MorphSafeAreaPolicy = .content) -> CGRect {
        let safeInsets = insets(policy)
        return CGRect(x: safeInsets.leading,
                      y: safeInsets.top,
                      width: max(1, size.width - safeInsets.leading - safeInsets.trailing),
                      height: max(1, size.height - safeInsets.top - safeInsets.bottom))
    }
}

public extension EnvironmentValues {
    @Entry var morphSafeAreas = MorphSafeAreaManager()
}
