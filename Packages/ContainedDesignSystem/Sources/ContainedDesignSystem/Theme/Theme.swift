import SwiftUI
import AppKit

/// Material/elevation constants for reusable design surfaces. Keep glass, shadow, and stroke choices
/// here so collapsed controls and expanded panels do not drift into near-duplicates.
public enum DesignMaterial {
    public static let toolbarHoverFill = Color.white.opacity(0.1)
    public static func toolbarInteractiveHoverFill(for colorScheme: ColorScheme) -> Color {
        Color.white.opacity(colorScheme == .light ? 0.2 : 0.1)
    }
    public static let floatingPanelStroke = Color.white.opacity(0.18)
    public static let floatingPanelShadow = Color.black.opacity(0.24)
    public static let floatingPanelShadowRadius: CGFloat = 24
    public static let floatingPanelShadowY: CGFloat = 12
}

/// A curated color, used consistently for host accent choices and per-surface personalization.
/// `.multicolor` follows `Color.accentColor`, so package callers can decide whether that means a
/// global accent, a scoped accent, or the platform default.
public enum DesignTint: String, CaseIterable, Identifiable, Codable, Sendable {
    case multicolor, graphite, azure, teal, coral, indigo, green, amber, pink

    public var id: String { rawValue }

    /// True for the "follow the host accent" option (rendered with a marker in the swatch row).
    public var followsAccent: Bool { self == .multicolor }

    public var color: Color {
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

    /// Parse a legacy `contained.tint` label value, falling back to multicolor.
    public static func parse(_ raw: String?) -> DesignTint {
        guard let raw, let tint = DesignTint(rawValue: raw.lowercased()) else { return .multicolor }
        return tint
    }
}

public enum ColorLayerBlendMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case normal, softLight, overlay, multiply, screen

    public var id: String { rawValue }

    public var blendMode: BlendMode {
        switch self {
        case .normal: return .normal
        case .softLight: return .softLight
        case .overlay: return .overlay
        case .multiply: return .multiply
        case .screen: return .screen
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The AppKit appearance to force on the app. `nil` for `.system` releases the override so the app
    /// tracks the live OS appearance — `.preferredColorScheme(nil)` alone doesn't reliably re-sync a
    /// window that was previously pinned, so we set `NSApplication.appearance` directly.
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

public enum CardDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case small, medium, large
    public var id: String { rawValue }
    public var resourceSize: DesignCardSize {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }

    public init(stored raw: String?) {
        if raw == "compact" {
            self = .medium
        } else {
            self = CardDensity(rawValue: raw ?? "") ?? .medium
        }
    }
}

/// The behind-window vibrancy material used for the main content area. A curated, ordered subset of
/// `NSVisualEffectView.Material` (lightest → most opaque) so the picker reads sensibly.
public enum WindowMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    // Liquid Glass options (rendered with `.glassEffect`, not an `NSVisualEffectView`).
    case glassClear, glassRegular
    // System vibrancy materials.
    case fullScreenUI, underWindowBackground, underPageBackground,
         windowBackground, contentBackground, sidebar, headerView, titlebar,
         sheet, popover, menu, selection, hudWindow, toolTip

    public var id: String { rawValue }

    /// True for the Liquid Glass options, which render via `.glassEffect` rather than vibrancy.
    public var isGlass: Bool { self == .glassClear || self == .glassRegular }

    /// The Liquid Glass variant for the glass cases (nil for vibrancy materials).
    public var glass: Glass? {
        switch self {
        case .glassClear:   return .clear
        case .glassRegular: return .regular
        default:            return nil
        }
    }

    /// The vibrancy material. Glass cases fall back to a sensible default for the rare place that
    /// needs a behind-window material (e.g. the root content backing, which can't be glass).
    public var nsMaterial: NSVisualEffectView.Material {
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

public extension EnvironmentValues {
    /// The user-chosen modal material, seeded at the app root and inherited by presented sheets.
    @Entry var modalMaterial: WindowMaterial = .sheet
    /// The user-chosen toolbar-control (button) material, seeded at the app root.
    @Entry var buttonMaterial: WindowMaterial = .glassClear
    /// The user-chosen design-card material, seeded at the app root.
    @Entry var cardMaterial: WindowMaterial = .glassRegular
    /// Optional color/gradient wash layered into toolbar button groups.
    @Entry var buttonTintStyle: DesignButtonTintStyle = .disabled
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

public extension View {
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
    var cornerRadius = DesignTokens.Radius.sheet
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
                                   color: DesignMaterial.floatingPanelShadow,
                                   radius: DesignMaterial.floatingPanelShadowRadius,
                                   y: DesignMaterial.floatingPanelShadowY)
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
                shape.strokeBorder(DesignMaterial.floatingPanelStroke, lineWidth: 1)
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

public extension View {
    /// In-window floating panel material. Unlike `.sheet`, this samples the live app content instead
    /// of the dimmed system-modal backdrop, so thin materials actually read thin.
    func floatingPanelMaterial(cornerRadius: CGFloat = DesignTokens.Radius.sheet,
                               showsShadow: Bool = true) -> some View {
        modifier(FloatingPanelMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow))
    }

    /// Standard interactive glass used by toolbar buttons and collapsed toolbar search.
    func toolbarControlMaterial<S: Shape>(in shape: S) -> some View {
        modifier(ToolbarControlMaterial(shape: shape))
    }
}
