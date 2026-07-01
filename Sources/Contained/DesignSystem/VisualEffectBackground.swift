import SwiftUI
import AppKit

/// Behind-window vibrancy so the desktop shows through the content area (blurred). No SwiftUI
/// equivalent for `.behindWindow` blending — flagged AppKit bridge.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blendingMode
        view.state = .active
        view.material = material
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.blendingMode = blendingMode
        view.material = material
    }
}

/// Stable root-owned backing for the detail column. Pages render above this layer instead of
/// applying their own window material. Translucency is always on — legibility under low-contrast
/// wallpapers is left to the OS "Reduce transparency" accessibility setting.
struct ContentBackgroundLayer: View {
    var material: NSVisualEffectView.Material = .fullScreenUI

    var body: some View {
        VisualEffectBackground(material: material)
            .ignoresSafeArea()
    }
}
