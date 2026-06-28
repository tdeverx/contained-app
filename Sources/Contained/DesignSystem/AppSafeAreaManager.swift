import SwiftUI

struct AppToolbarSafeAreaExclusion: OptionSet, Equatable {
    let rawValue: Int

    static let top = AppToolbarSafeAreaExclusion(rawValue: 1 << 0)
    static let bottom = AppToolbarSafeAreaExclusion(rawValue: 1 << 1)
    static let both: AppToolbarSafeAreaExclusion = [.top, .bottom]
}

enum AppSafeAreaPadding: CGFloat, Equatable {
    case none = 0
    case small = 8
    case medium = 16
    case large = 24
}

struct AppSafeAreaPolicy: Equatable {
    var excluding: AppToolbarSafeAreaExclusion = .both
    var padding: AppSafeAreaPadding = .small
    var includesSystemInsets = true

    static let fullBleed = AppSafeAreaPolicy(excluding: [], padding: .none)
    static let toolbarChrome = AppSafeAreaPolicy(excluding: [], padding: .small)
    static let content = AppSafeAreaPolicy(excluding: .both, padding: .medium)
}

struct AppSafeAreaManager: Equatable {
    var system: EdgeInsets = EdgeInsets()
    var topToolbarHeight: CGFloat = 0
    var bottomToolbarHeight: CGFloat = 0

    init(system: EdgeInsets = EdgeInsets(),
         topToolbarHeight: CGFloat = 0,
         bottomToolbarHeight: CGFloat = 0) {
        self.system = system
        self.topToolbarHeight = topToolbarHeight
        self.bottomToolbarHeight = bottomToolbarHeight
    }

    init(system: EdgeInsets = EdgeInsets(), toolbarHeight: CGFloat) {
        self.init(system: system, topToolbarHeight: toolbarHeight, bottomToolbarHeight: 0)
    }

    func insets(_ policy: AppSafeAreaPolicy = .content) -> EdgeInsets {
        let padding = policy.padding.rawValue
        let systemInsets = policy.includesSystemInsets ? system : EdgeInsets()
        // On an edge that excludes its toolbar, the band *is* the inset — the padding doesn't stack on
        // top of it. Edges without a toolbar exclusion get the padding instead.
        return EdgeInsets(top: systemInsets.top + (policy.excluding.contains(.top) ? topToolbarHeight : padding),
                          leading: systemInsets.leading + padding,
                          bottom: systemInsets.bottom + (policy.excluding.contains(.bottom) ? bottomToolbarHeight : padding),
                          trailing: systemInsets.trailing + padding)
    }

    func bounds(in size: CGSize, policy: AppSafeAreaPolicy = .content) -> CGRect {
        let safeInsets = insets(policy)
        return CGRect(x: safeInsets.leading,
                      y: safeInsets.top,
                      width: max(1, size.width - safeInsets.leading - safeInsets.trailing),
                      height: max(1, size.height - safeInsets.top - safeInsets.bottom))
    }
}

extension EnvironmentValues {
    @Entry var appSafeAreas = AppSafeAreaManager()
}
