import SwiftUI
import AppKit

/// Design tokens — the single source of truth for spacing, radii, and type used across the app.
enum Tokens {
    enum Radius {
        static let control: CGFloat = 10
        static let card: CGFloat = 16
        static let sheet: CGFloat = 22
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
    /// Icon-button / chip dimensions used across menus and headers.
    enum IconSize {
        static let rowMenu: CGFloat = 22   // ellipsis row menus
        static let control: CGFloat = 28   // sheet-header circle buttons
        static let chip: CGFloat = 30      // small status chips
        static let headerChip: CGFloat = 34 // detail-header chips
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
        static let iconInnerPadding: CGFloat = 5 // padding around the glyph inside the 36 button
        static let outerPadding: CGFloat = 8    // band inset from the detail-column edges
        static let groupPaddingH: CGFloat = 8   // horizontal glass margin inside a group
        static let groupSpacing: CGFloat = 8    // spacing between buttons / groups
        static let searchMaxWidth: CGFloat = 380
        // Search field internals.
        static let searchInnerPadding: CGFloat = 10 // padding inside the collapsed search capsule
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

    /// Parse a `contained.tint` label value, falling back to multicolor.
    static func parse(_ raw: String?) -> AppTint {
        guard let raw, let tint = AppTint(rawValue: raw.lowercased()) else { return .multicolor }
        return tint
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
}

enum CardDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case compact, large
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// The behind-window vibrancy material used for the main content area. A curated, ordered subset of
/// `NSVisualEffectView.Material` (lightest → most opaque) so the picker reads sensibly.
enum WindowMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    case fullScreenUI, underWindowBackground, underPageBackground,
         windowBackground, contentBackground, sidebar, headerView, titlebar,
         sheet, popover, menu, selection, hudWindow, toolTip

    var id: String { rawValue }

    var displayName: String {
        switch self {
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

    var nsMaterial: NSVisualEffectView.Material {
        switch self {
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
}

private struct SheetMaterial: ViewModifier {
    @Environment(\.modalMaterial) private var material
    func body(content: Content) -> some View {
        content
            .background {
                VisualEffectBackground(material: material.nsMaterial, blendingMode: .withinWindow)
                    .ignoresSafeArea()
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

private struct FloatingPanelMaterial: ViewModifier {
    @Environment(\.modalMaterial) private var material

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous)
        content
            .background {
                ExteriorShadow(cornerRadius: Tokens.Radius.sheet,
                               color: .black.opacity(0.24),
                               radius: 24,
                               y: 12)
            }
            .background {
                VisualEffectBackground(material: material.nsMaterial, blendingMode: .withinWindow)
                    .clipShape(shape)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
    }
}

extension View {
    /// In-window floating panel material. Unlike `.sheet`, this samples the live app content instead
    /// of the dimmed system-modal backdrop, so thin materials actually read thin.
    func floatingPanelMaterial() -> some View { modifier(FloatingPanelMaterial()) }
}
