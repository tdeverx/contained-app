import SwiftUI
import ContainedUI

public extension UX.Panel {
struct BackdropStyle: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let dim = BackdropStyle(rawValue: 1 << 0)
    public static let blur = BackdropStyle(rawValue: 1 << 1)
    public static let blurAndDim: BackdropStyle = [.blur, .dim]
}
}

#Preview("Backdrop Styles") {
    HStack(spacing: UI.Layout.Spacing.m) {
        Text("Dim")
            .frame(width: 140, height: 90)
            .globalBackdrop(style: .dim, progress: 1)
        Text("Blur + dim")
            .frame(width: 140, height: 90)
            .globalBackdrop(style: .blurAndDim, progress: 1)
    }
    .padding(UI.Layout.Spacing.xl)
}
