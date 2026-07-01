import SwiftUI
import AppKit

/// Design tokens — the single source of truth for spacing, radii, and type used across the app.
enum Tokens {
    enum Radius {
        /// Radius delta between nested glass levels: sheet → card → control → key cap.
        static let step: CGFloat = 6
        static let control: CGFloat = 10
        static let card: CGFloat = 16
        static let sheet: CGFloat = 22
        static let keyCap: CGFloat = control - step
        static let iconChip: CGFloat = control

        /// Radius for a shape inset inside a parent with the same corner center.
        static func inset(from outer: CGFloat, by inset: CGFloat) -> CGFloat {
            max(0, outer - inset)
        }
    }
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    enum CardSize {
        // Generous max widths so the adaptive grid stretches the fitted columns to fill the row,
        // rather than capping them tightly and leaving trailing dead space on wide windows.
        static let compactMin: CGFloat = 230
        static let compactMax: CGFloat = 400
        static let largeMin: CGFloat = 300
        static let largeMax: CGFloat = 520
    }
    /// Canonical sheet dimensions — pass to `.frame(Tokens.SheetSize.form)`. Replaces ad-hoc
    /// `width:height:` literals so every sheet snaps to one of a few sizes.
    enum SheetSize {
        static let small = CGSize(width: 420, height: 280)    // confirmations, short forms
        static let form = CGSize(width: 560, height: 680)     // the run/edit form
        static let console = CGSize(width: 560, height: 540)  // streamed-progress / logs
        static let inspector = CGSize(width: 600, height: 560) // JSON inspector, history
        static let wide = CGSize(width: 720, height: 560)     // build workspace
    }
    /// Morph-panel dimensions shared by toolbar origins and panel content.
    enum PanelSize {
        // Global floor applied in MorphGeometry.fittedSize — panels never shrink below these or exceed
        // the available window area (handled separately via margin clamping). The height floor is tiny
        // so content-hugging panels can collapse close to their header when there's little to show.
        static let minWidth: CGFloat = 300
        static let minHeight: CGFloat = 50

        static let add = CGSize(width: 440, height: 300)
        static let palette = CGSize(width: 560, height: 480)
        static let updatesOrigin = CGSize(width: 440, height: 300)
        static let images = CGSize(width: 520, height: 520)
        static let imageDetail = CGSize(width: 560, height: 520)
        static let activityOrigin = CGSize(width: 460, height: 360)
        static let activity = CGSize(width: 560, height: 520)
        static let templatesOrigin = CGSize(width: 440, height: 300)
        static let templates = CGSize(width: 460, height: 480)
        static let system = CGSize(width: 580, height: 600)
        static let settings = CGSize(width: 560, height: 560)
    }
    /// Icon-button / chip dimensions used across menus and headers.
    enum IconSize {
        static let rowMenu: CGFloat = 22   // ellipsis row menus
        static let control: CGFloat = 28   // sheet-header circle buttons
        static let chip: CGFloat = 30      // small status chips
        static let headerChip: CGFloat = 34 // detail-header chips
    }
    /// Fixed widths for compact form controls where stable alignment matters more than fluid sizing.
    enum FormWidth {
        static let shortReadout: CGFloat = 44
        static let memoryReadout: CGFloat = 64
        static let port: CGFloat = 70
        static let containerPort: CGFloat = 80
        static let userID: CGFloat = 90
    }

    /// The app toolbar band — custom (non-native) controls sized to macOS 26 Liquid Glass toolbar
    /// proportions (tuned against Finder). `controlHeight` is shared by every band element (glass
    /// button groups and the search field) so they align on one baseline; `groupRadius` is the
    /// concentric capsule for them. Glyphs are a touch smaller than the capsule with horizontal glass
    /// padding around them, matching the airy native look.
    enum Toolbar {
        // Exact spec: controls are 36pt tall (length hugs content), with 8pt of padding around the band
        // (horizontal, top — matched below — and between groups), so the band is 8 + 36 + 8 = 52.
        static let band: CGFloat = 52           // title-bar band height
        static let controlHeight: CGFloat = 36  // glass groups + search field share this height
        // Button glyphs use `.headline` + `.imageScale(.large)` (see ToolbarControls) so they scale
        // with Dynamic Type — no fixed point size token.
        static let iconInnerPadding: CGFloat = 4 // padding around the glyph inside the 28 item
        static let buttonItemHeight: CGFloat = 28
        static let buttonGroupHeight: CGFloat = 36
        static let outerPadding: CGFloat = 8    // band inset from the window edges
        // The toolbar now spans the whole window (no sidebar), so its leading edge must clear the
        // traffic-light cluster (close/min/zoom ≈ 70pt) plus a little breathing room.
        static let leadingInset: CGFloat = 80   // band inset on the left, past the traffic lights
        static let trafficLightsWidth: CGFloat = 82 // close/min/zoom cluster width — the Settings slot min width
        static let groupPaddingH: CGFloat = 0   // horizontal glass margin inside a group
        static let groupSpacing: CGFloat = 8    // spacing between buttons / groups
        static let searchMaxWidth: CGFloat = 380
        // Search field internals.
        static let searchInnerPadding: CGFloat = iconInnerPadding * 2 // matches glass button edge inset
        static let searchIconGap: CGFloat = 6       // gap between icon and text
        static let searchOpenHeaderHeight: CGFloat = 48 // taller header row once the palette expands
        // The search icon + text use the semantic `.body` style (13pt on macOS; text adds medium weight),
        // so they scale with Dynamic Type — no fixed point size tokens.
        /// Padding above the controls (and matched below) — the controls sit on the native toolbar line.
        static let topPadding: CGFloat = 8
        static var groupRadius: CGFloat { controlHeight / 2 }  // concentric capsule
    }
}

extension View {
    /// Apply a canonical sheet size from `Tokens.SheetSize`.
    func frame(_ size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}

/// Material/elevation constants for reusable app surfaces. Keep glass, shadow, and stroke choices
/// here so collapsed controls and expanded panels do not drift into near-duplicates.
enum AppMaterial {
    static let toolbarHoverFill = Color.white.opacity(0.1)
    static func toolbarInteractiveHoverFill(for colorScheme: ColorScheme) -> Color {
        Color.white.opacity(colorScheme == .light ? 0.2 : 0.1)
    }
    static let floatingPanelStroke = Color.white.opacity(0.18)
    static let floatingPanelShadow = Color.black.opacity(0.24)
    static let floatingPanelShadowRadius: CGFloat = 24
    static let floatingPanelShadowY: CGFloat = 12
}

/// A curated color, used identically for the app accent (Settings) and per-card personalization
/// (icon + optional background wash) so the palette is consistent everywhere. `.multicolor` is the
/// "follow the app accent" option: it resolves to `Color.accentColor`, which the root sets to the
/// chosen accent tint — so a container left on `.multicolor` tracks whatever the app accent is.
enum AppTint: String, CaseIterable, Identifiable, Codable, Sendable {
    case multicolor, graphite, azure, teal, coral, indigo, green, amber, pink

    var id: String { rawValue }

    var displayName: String { self == .multicolor ? "App Accent" : rawValue.capitalized }

    /// True for the "follow the app accent" option (rendered with a marker in the swatch row).
    var followsAppAccent: Bool { self == .multicolor }

    var color: Color {
        switch self {
        case .multicolor: return .accentColor
        case .graphite:   return Color(red: 0.45, green: 0.46, blue: 0.50)
        case .azure:      return Color(red: 0.14, green: 0.52, blue: 0.92)
        case .teal:       return Color(red: 0.11, green: 0.62, blue: 0.50)
        case .coral:      return Color(red: 0.85, green: 0.35, blue: 0.19)
        case .indigo:     return Color(red: 0.33, green: 0.29, blue: 0.72)
        case .green:      return Color(red: 0.39, green: 0.60, blue: 0.13)
        case .amber:      return Color(red: 0.73, green: 0.46, blue: 0.09)
        case .pink:       return Color(red: 0.83, green: 0.21, blue: 0.34)
        }
    }

    /// Common color words that should also surface this tint in search (e.g. typing "purple" finds
    /// `indigo`, "blue" finds `azure`). Keeps the curated palette discoverable under everyday names.
    var searchAliases: [String] {
        switch self {
        case .multicolor: return ["default", "app accent", "system", "auto", "rainbow"]
        case .graphite:   return ["gray", "grey", "slate", "charcoal", "silver", "neutral", "mono"]
        case .azure:      return ["blue", "sky", "ocean", "cobalt"]
        case .teal:       return ["cyan", "aqua", "turquoise", "mint", "seafoam"]
        case .coral:      return ["orange", "salmon", "burnt", "terracotta", "rust"]
        case .indigo:     return ["purple", "violet", "blurple", "royal"]
        case .green:      return ["lime", "olive", "emerald", "forest", "moss"]
        case .amber:      return ["yellow", "gold", "honey", "mustard"]
        case .pink:       return ["magenta", "rose", "fuchsia", "crimson", "hot pink"]
        }
    }

    /// Parse a legacy `contained.tint` label value, falling back to multicolor.
    static func parse(_ raw: String?) -> AppTint {
        guard let raw, let tint = AppTint(rawValue: raw.lowercased()) else { return .multicolor }
        return tint
    }
}

enum ColorLayerBlendMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case normal, softLight, overlay, multiply, screen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .softLight: return "Soft Light"
        case .overlay: return "Overlay"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        }
    }

    var blendMode: BlendMode {
        switch self {
        case .normal: return .normal
        case .softLight: return .softLight
        case .overlay: return .overlay
        case .multiply: return .multiply
        case .screen: return .screen
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The AppKit appearance to force on the app. `nil` for `.system` releases the override so the app
    /// tracks the live OS appearance — `.preferredColorScheme(nil)` alone doesn't reliably re-sync a
    /// window that was previously pinned, so we set `NSApplication.appearance` directly.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum CardDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case small, medium, large
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var resourceSize: ResourceCardSize {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }

    init(stored raw: String?) {
        if raw == "compact" {
            self = .medium
        } else {
            self = CardDensity(rawValue: raw ?? "") ?? .medium
        }
    }
}

/// The behind-window vibrancy material used for the main content area. A curated, ordered subset of
/// `NSVisualEffectView.Material` (lightest → most opaque) so the picker reads sensibly.
enum WindowMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    // Liquid Glass options (rendered with `.glassEffect`, not an `NSVisualEffectView`).
    case glassClear, glassRegular
    // System vibrancy materials.
    case fullScreenUI, underWindowBackground, underPageBackground,
         windowBackground, contentBackground, sidebar, headerView, titlebar,
         sheet, popover, menu, selection, hudWindow, toolTip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glassClear:          return "Glass (Clear)"
        case .glassRegular:        return "Glass (Regular)"
        case .fullScreenUI:        return "Full-screen UI (default)"
        case .underWindowBackground: return "Under Window"
        case .underPageBackground: return "Under Page"
        case .windowBackground:    return "Window"
        case .contentBackground:   return "Content"
        case .sidebar:             return "Sidebar"
        case .headerView:          return "Header"
        case .titlebar:            return "Titlebar"
        case .sheet:               return "Sheet"
        case .popover:             return "Popover"
        case .menu:                return "Menu"
        case .selection:           return "Selection"
        case .hudWindow:           return "HUD"
        case .toolTip:             return "Tooltip"
        }
    }

    /// True for the Liquid Glass options, which render via `.glassEffect` rather than vibrancy.
    var isGlass: Bool { self == .glassClear || self == .glassRegular }

    /// The Liquid Glass variant for the glass cases (nil for vibrancy materials).
    var glass: Glass? {
        switch self {
        case .glassClear:   return .clear
        case .glassRegular: return .regular
        default:            return nil
        }
    }

    /// The vibrancy material. Glass cases fall back to a sensible default for the rare place that
    /// needs a behind-window material (e.g. the root content backing, which can't be glass).
    var nsMaterial: NSVisualEffectView.Material {
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

extension EnvironmentValues {
    /// The user-chosen modal material, seeded at the app root and inherited by presented sheets.
    @Entry var modalMaterial: WindowMaterial = .sheet
    /// The user-chosen toolbar-control (button) material, seeded at the app root.
    @Entry var buttonMaterial: WindowMaterial = .glassClear
    /// The user-chosen resource-card material, seeded at the app root.
    @Entry var cardMaterial: WindowMaterial = .glassRegular
    /// Optional color/gradient wash layered into glass buttons.
    @Entry var buttonTintStyle: GlassButtonTintStyle = .disabled
}

private struct SheetMaterial: ViewModifier {
    @Environment(\.modalMaterial) private var material
    func body(content: Content) -> some View {
        content
            .background {
                if let glass = material.glass {
                    Color.clear.glassEffect(glass, in: Rectangle()).ignoresSafeArea()
                } else {
                    VisualEffectBackground(material: material.nsMaterial, blendingMode: .withinWindow)
                        .ignoresSafeArea()
                }
            }
            .presentationBackground(.clear)
    }
}

extension View {
    /// Standard sheet background — the user-chosen modal material (read from the environment).
    /// Replaces ad-hoc `.background(.regularMaterial)` so every sheet honors the setting.
    func sheetMaterial() -> some View { modifier(SheetMaterial()) }

    /// Apply the sheet material only when `active`. Popovers bring their own native vibrant
    /// background, and layering an `NSVisualEffectView` + `presentationBackground(.clear)` inside one
    /// leaves controls unpainted until the first mouse event — so popover presentations pass `false`.
    @ViewBuilder
    func sheetMaterial(_ active: Bool) -> some View {
        if active { modifier(SheetMaterial()) } else { self }
    }
}

private struct FloatingPanelMaterial: AnimatableModifier {
    @Environment(\.modalMaterial) private var material
    var cornerRadius = Tokens.Radius.sheet
    var showsShadow = true

    nonisolated var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if showsShadow {
                    ExteriorShadow(cornerRadius: cornerRadius,
                                   color: AppMaterial.floatingPanelShadow,
                                   radius: AppMaterial.floatingPanelShadowRadius,
                                   y: AppMaterial.floatingPanelShadowY)
                }
            }
            .background {
                if let glass = material.glass {
                    Color.clear.glassEffect(glass, in: shape)
                } else {
                    VisualEffectBackground(material: material.nsMaterial, blendingMode: .withinWindow)
                        .clipShape(shape)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(AppMaterial.floatingPanelStroke, lineWidth: 1)
            }
    }
}

private struct ToolbarControlMaterial<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.buttonMaterial) private var buttonMaterial

    func body(content: Content) -> some View {
        if let glass = buttonMaterial.glass {
            content.glassEffect(glass.interactive(), in: shape)
        } else {
            // A vibrancy material chosen for buttons — back the capsule with it and clip.
            content.background {
                VisualEffectBackground(material: buttonMaterial.nsMaterial, blendingMode: .withinWindow)
                    .clipShape(shape)
            }
        }
    }
}

extension View {
    /// In-window floating panel material. Unlike `.sheet`, this samples the live app content instead
    /// of the dimmed system-modal backdrop, so thin materials actually read thin.
    func floatingPanelMaterial(cornerRadius: CGFloat = Tokens.Radius.sheet,
                               showsShadow: Bool = true) -> some View {
        modifier(FloatingPanelMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow))
    }

    /// Standard interactive glass used by toolbar buttons and collapsed toolbar search.
    func toolbarControlMaterial<S: Shape>(in shape: S) -> some View {
        modifier(ToolbarControlMaterial(shape: shape))
    }
}
