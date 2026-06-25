import SwiftUI
import AppKit

/// Behind-window vibrancy so the desktop shows through the content area (blurred). No SwiftUI
/// equivalent for `.behindWindow` blending — flagged AppKit bridge.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

extension View {
    /// Background for the detail content. When translucent, the window itself is already clear so
    /// the desktop shows through directly and the cards provide the only glass — adding a vibrancy
    /// layer here would double-frost and wash the cards out. Under Reduce Transparency we use a
    /// solid backing instead (and the window is made opaque).
    @ViewBuilder
    func contentBackground(reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            self.background(Color(nsColor: .windowBackgroundColor))
        } else {
            self.background(VisualEffectBackground().ignoresSafeArea())
        }
    }
}
