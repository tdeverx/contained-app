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
        static let compactMin: CGFloat = 240
        static let compactMax: CGFloat = 280
        static let largeMin: CGFloat = 300
        static let largeMax: CGFloat = 360
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

enum BackdropStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case mesh, solid
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// The behind-window vibrancy material used for the main content area. A curated, ordered subset of
/// `NSVisualEffectView.Material` (lightest → most opaque) so the picker reads sensibly.
enum WindowMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    case fullScreenUI, hudWindow, underWindowBackground, popover, sidebar,
         headerView, menu, contentBackground, windowBackground, underPageBackground

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullScreenUI:        return "Full-screen UI (default)"
        case .hudWindow:           return "HUD"
        case .underWindowBackground: return "Under Window"
        case .popover:             return "Popover"
        case .sidebar:             return "Sidebar"
        case .headerView:          return "Header"
        case .menu:                return "Menu"
        case .contentBackground:   return "Content"
        case .windowBackground:    return "Window"
        case .underPageBackground: return "Under Page"
        }
    }

    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .fullScreenUI:          return .fullScreenUI
        case .hudWindow:             return .hudWindow
        case .underWindowBackground: return .underWindowBackground
        case .popover:               return .popover
        case .sidebar:               return .sidebar
        case .headerView:            return .headerView
        case .menu:                  return .menu
        case .contentBackground:     return .contentBackground
        case .windowBackground:      return .windowBackground
        case .underPageBackground:   return .underPageBackground
        }
    }
}

/// The material painted behind modal sheets. Maps onto SwiftUI's `Material` so sheets stay
/// consistent with the platform's blur stops.
enum ModalMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    case ultraThin, thin, regular, thick, ultraThick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ultraThin:  return "Ultra Thin"
        case .thin:       return "Thin"
        case .regular:    return "Regular (default)"
        case .thick:      return "Thick"
        case .ultraThick: return "Ultra Thick"
        }
    }

    var material: Material {
        switch self {
        case .ultraThin:  return .ultraThin
        case .thin:       return .thin
        case .regular:    return .regular
        case .thick:      return .thick
        case .ultraThick: return .ultraThick
        }
    }
}

extension EnvironmentValues {
    /// The user-chosen modal material, seeded at the app root and inherited by presented sheets.
    @Entry var modalMaterial: ModalMaterial = .regular
}

private struct SheetMaterial: ViewModifier {
    @Environment(\.modalMaterial) private var material
    func body(content: Content) -> some View { content.background(material.material) }
}

extension View {
    /// Standard sheet background — the user-chosen modal material (read from the environment).
    /// Replaces ad-hoc `.background(.regularMaterial)` so every sheet honors the setting.
    func sheetMaterial() -> some View { modifier(SheetMaterial()) }
}
