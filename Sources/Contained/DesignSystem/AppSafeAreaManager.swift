import SwiftUI

enum AppSafeAreaScope {
    /// The usable app body including the toolbar/titlebar band. Good for toolbar-origin morphs that
    /// should stay visually close to the source control.
    case includingToolbar
    /// The usable app body below the toolbar/titlebar band. Good for normal page content.
    case excludingToolbar
}

struct AppSafeAreaManager: Equatable {
    var system: EdgeInsets = EdgeInsets()
    var toolbarHeight: CGFloat = 0
    var horizontalPadding: CGFloat = Tokens.Space.s
    var bottomPadding: CGFloat = Tokens.Space.l

    func morphInsets(_ scope: AppSafeAreaScope) -> EdgeInsets {
        let top = switch scope {
        case .includingToolbar:
            system.top + Tokens.Space.s
        case .excludingToolbar:
            system.top + toolbarHeight + Tokens.Space.s
        }
        return EdgeInsets(top: top,
                          leading: system.leading + horizontalPadding,
                          bottom: system.bottom + bottomPadding,
                          trailing: system.trailing + horizontalPadding)
    }
}

extension EnvironmentValues {
    @Entry var appSafeAreas = AppSafeAreaManager()
}
