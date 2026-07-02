import SwiftUI

/// Root namespace for reusable interaction, placement, and morphing systems.
public enum UX {}

public extension UX {
    enum Toolbar {}
    enum Panel {}
    enum Morph {}
    enum SafeArea {}
    enum Measurement {}
}

public extension UX.Panel {
    typealias Placement = PanelPlacement
    typealias BackdropStyle = PanelBackdropStyle
}

public extension UX.Morph {
    typealias Target = MorphTargetConfig
    typealias Geometry = MorphGeometryEngine
    typealias Frame = MorphFrameGeometry
    typealias Expander = MorphExpander
    typealias SingleSurface = MorphSingleSurface
    typealias SingleSurfaceExpander = MorphSingleSurfaceExpander
}

public extension UX.SafeArea {
    typealias ToolbarExclusion = ToolbarSafeAreaExclusion
    typealias Padding = SafeAreaPadding
    typealias Policy = SafeAreaPolicy
    typealias Manager = SafeAreaManager
}

public extension UX.Measurement {
    typealias SourceFrameReader = ContainedUX.SourceFrameReader
    typealias SourceFramesKey = ContainedUX.SourceFramesKey
}
