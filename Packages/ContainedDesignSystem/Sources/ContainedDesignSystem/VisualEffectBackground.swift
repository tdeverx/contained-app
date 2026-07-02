import SwiftUI
import AppKit

/// Behind-window vibrancy so the desktop shows through the content area (blurred). No SwiftUI
/// equivalent for `.behindWindow` blending — flagged AppKit bridge.
public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material = .fullScreenUI,
                blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blendingMode
        view.state = .active
        view.material = material
        return view
    }

    public func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.blendingMode = blendingMode
        view.material = material
    }
}

/// Stable root-owned backing for the detail column. Pages render above this layer instead of
/// applying their own window material. Translucency is always on — legibility under low-contrast
/// wallpapers is left to the OS "Reduce transparency" accessibility setting.
public struct ContentBackgroundLayer: View {
    public var material: NSVisualEffectView.Material

    public init(material: NSVisualEffectView.Material = .fullScreenUI) {
        self.material = material
    }

    public var body: some View {
        VisualEffectBackground(material: material)
            .ignoresSafeArea()
    }
}
