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
/// applying their own window material.
struct ContentBackgroundLayer: View {
    var reduceTransparency: Bool
    var material: NSVisualEffectView.Material = .fullScreenUI

    var body: some View {
        Group {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                VisualEffectBackground(material: material)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Background for the detail content. When translucent, the window itself is already clear so
    /// the desktop shows through directly and the cards provide the only glass — adding a vibrancy
    /// layer here would double-frost and wash the cards out. Under Reduce Transparency we use a
    /// solid backing instead (and the window is made opaque).
    @ViewBuilder
    func contentBackground(reduceTransparency: Bool,
                           material: NSVisualEffectView.Material = .fullScreenUI) -> some View {
        if reduceTransparency {
            self.background(Color(nsColor: .windowBackgroundColor))
        } else {
            self.background(VisualEffectBackground(material: material).ignoresSafeArea())
        }
    }
}
