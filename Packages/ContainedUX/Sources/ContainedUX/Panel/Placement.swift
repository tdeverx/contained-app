import CoreGraphics
import SwiftUI
import ContainedUI

public extension UX.Panel {
enum Placement: Equatable, Sendable {
    case anchored
    case centered
}
}

#Preview("Panel Placement") {
    VStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
        Text("Anchored panels grow from a measured source.")
        Text("Centered panels use the safe content bounds.")
            .foregroundStyle(.secondary)
    }
    .padding(UI.Layout.Spacing.l)
    .background(.regularMaterial,
                in: RoundedRectangle(cornerRadius: UI.Panel.Radius.surface,
                                     style: .continuous))
    .padding(UI.Layout.Spacing.xl)
    .frame(width: 360)
}
