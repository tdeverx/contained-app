import SwiftUI
import AppKit

/// Behind-window vibrancy so the desktop shows through the content area (blurred). No SwiftUI
/// equivalent for `.behindWindow` blending — flagged AppKit bridge.
struct VisualEffectBackground: NSViewRepresentable {
    var material: UI.Theme.WindowMaterial
    var blendingMode: NSVisualEffectView.BlendingMode

    init(material: UI.Theme.WindowMaterial = .fullScreenUI,
         blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blendingMode
        view.state = .active
        view.material = material.visualEffectMaterial
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.blendingMode = blendingMode
        view.material = material.visualEffectMaterial
    }
}

private extension UI.Theme.WindowMaterial {
    /// Glass cases fall back to a sensible vibrancy material for places that need a behind-window
    /// layer, such as root content backing.
    var visualEffectMaterial: NSVisualEffectView.Material {
        switch self {
        case .glassClear, .glassRegular: return .fullScreenUI
        case .fullScreenUI:          return .fullScreenUI
        case .underWindowBackground: return .underWindowBackground
        case .underPageBackground:   return .underPageBackground
        case .windowBackground:      return .windowBackground
        case .contentBackground:     return .contentBackground
        case .sidebar:               return .sidebar
        case .headerView:            return .headerView
        case .titlebar:              return .titlebar
        case .sheet:                 return .sheet
        case .popover:               return .popover
        case .menu:                  return .menu
        case .selection:             return .selection
        case .hudWindow:             return .hudWindow
        case .toolTip:               return .toolTip
        }
    }
}

/// Stable root-owned backing for the detail column. Pages render above this layer instead of
/// applying their own window material. Translucency is always on — legibility under low-contrast
/// wallpapers is left to the OS "Reduce transparency" accessibility setting.
public extension UI.Theme {
struct BackgroundLayer: View {
    public var material: UI.Theme.WindowMaterial

    public init(material: UI.Theme.WindowMaterial = .fullScreenUI) {
        self.material = material
    }

    public var body: some View {
        VisualEffectBackground(material: material)
            .ignoresSafeArea()
    }
}
}

#Preview("Visual Effect Background") {
    ZStack {
        UI.Theme.BackgroundLayer(material: .fullScreenUI)
        Text("Background layer")
            .padding(UI.Tokens.Space.l)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)
    }
    .frame(width: 360, height: 220)
}
