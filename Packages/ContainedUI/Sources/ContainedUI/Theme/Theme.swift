import SwiftUI

public extension UI.Theme {
/// Material/elevation constants for reusable design surfaces. Keep glass, shadow, and stroke choices
/// here so collapsed controls and expanded panels do not drift into near-duplicates.
enum Material {
    public static let toolbarHoverFill = Color.white.opacity(0.1)
    public static func toolbarInteractiveHoverFill(for colorScheme: ColorScheme) -> Color {
        Color.white.opacity(colorScheme == .light ? 0.2 : 0.1)
    }
    public static let floatingPanelStroke = Color.white.opacity(0.18)
    public static let floatingPanelShadow = Color.black.opacity(0.24)
    public static let floatingPanelShadowRadius: CGFloat = 24
    public static let floatingPanelShadowY: CGFloat = 12
}

/// A system color or custom sRGB hex value, used consistently for host accent choices and
/// per-surface personalization. The preset list mirrors SwiftUI's standard named colors;
/// `.multicolor` follows `Color.accentColor`.
struct Tint: RawRepresentable, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    public let rawValue: String

    public static let multicolor = Tint(canonicalRawValue: "multicolor")
    public static let gray = Tint(canonicalRawValue: "gray")
    public static let red = Tint(canonicalRawValue: "red")
    public static let orange = Tint(canonicalRawValue: "orange")
    public static let yellow = Tint(canonicalRawValue: "yellow")
    public static let green = Tint(canonicalRawValue: "green")
    public static let mint = Tint(canonicalRawValue: "mint")
    public static let teal = Tint(canonicalRawValue: "teal")
    public static let cyan = Tint(canonicalRawValue: "cyan")
    public static let blue = Tint(canonicalRawValue: "blue")
    public static let indigo = Tint(canonicalRawValue: "indigo")
    public static let purple = Tint(canonicalRawValue: "purple")
    public static let pink = Tint(canonicalRawValue: "pink")
    public static let brown = Tint(canonicalRawValue: "brown")
    public static let black = Tint(canonicalRawValue: "black")
    public static let white = Tint(canonicalRawValue: "white")

    public static let allCases: [Tint] = [
        .multicolor, .gray, .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown, .black, .white,
    ]

    public init?(rawValue: String) {
        let migratedRawValue: String
        switch rawValue.lowercased() {
        case "graphite": migratedRawValue = Self.gray.rawValue
        case "azure": migratedRawValue = Self.blue.rawValue
        case "coral": migratedRawValue = Self.orange.rawValue
        case "amber": migratedRawValue = Self.yellow.rawValue
        default: migratedRawValue = rawValue.lowercased()
        }

        if Self.allCases.contains(where: { $0.rawValue == migratedRawValue }) {
            self.init(canonicalRawValue: migratedRawValue)
        } else if let hex = Self.normalizedHex(migratedRawValue) {
            self.init(canonicalRawValue: hex)
        } else {
            return nil
        }
    }

    public init?(hex: String) {
        guard let normalized = Self.normalizedHex(hex) else { return nil }
        self.init(canonicalRawValue: normalized)
    }

    private init(canonicalRawValue: String) {
        rawValue = canonicalRawValue
    }

    public var id: String { rawValue }
    public var followsAccent: Bool { self == .multicolor }
    public var isCustom: Bool { rawValue.hasPrefix("#") }
    public var hexValue: String? { isCustom ? rawValue : nil }

    public var color: Color {
        switch rawValue {
        case Self.multicolor.rawValue: return .accentColor
        case Self.gray.rawValue: return .gray
        case Self.red.rawValue: return .red
        case Self.orange.rawValue: return .orange
        case Self.yellow.rawValue: return .yellow
        case Self.green.rawValue: return .green
        case Self.mint.rawValue: return .mint
        case Self.teal.rawValue: return .teal
        case Self.cyan.rawValue: return .cyan
        case Self.blue.rawValue: return .blue
        case Self.indigo.rawValue: return .indigo
        case Self.purple.rawValue: return .purple
        case Self.pink.rawValue: return .pink
        case Self.brown.rawValue: return .brown
        case Self.black.rawValue: return .black
        case Self.white.rawValue: return .white
        default:
            guard let components = rgbComponents else { return .accentColor }
            return Color(.sRGB,
                         red: Double(components.red) / 255,
                         green: Double(components.green) / 255,
                         blue: Double(components.blue) / 255)
        }
    }

    public var contrastingColor: Color {
        guard let components = rgbComponents else { return .primary }
        let luminance = (0.299 * Double(components.red)
                         + 0.587 * Double(components.green)
                         + 0.114 * Double(components.blue)) / 255
        return luminance > 0.58 ? .black : .white
    }

    public static func normalizedHex(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard digits.count == 6, UInt32(digits, radix: 16) != nil else { return nil }
        return "#" + digits.uppercased()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let tint = Tint(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid tint value: \(rawValue)")
        }
        self = tint
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private var rgbComponents: (red: UInt8, green: UInt8, blue: UInt8)? {
        guard let hexValue else { return nil }
        let digits = hexValue.dropFirst()
        guard let value = UInt32(digits, radix: 16) else { return nil }
        return (UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF))
    }
}

enum ColorBlendMode: String, CaseIterable, Identifiable, Codable, Sendable {
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

enum Appearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, light, dark
    public var id: String { rawValue }
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

}

}

public extension UI.Card {
enum Density: String, CaseIterable, Identifiable, Codable, Sendable {
    case small, medium, large
    public var id: String { rawValue }
    public var resourceSize: UI.Card.Size {
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
            self = UI.Card.Density(rawValue: raw ?? "") ?? .medium
        }
    }
}
}

public extension UI.Theme {
/// The behind-window vibrancy material used for the main content area. A curated, ordered subset of
/// `NSVisualEffectView.Material` (lightest → most opaque) so the picker reads sensibly.
enum WindowMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
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

}
}

public extension EnvironmentValues {
    /// The app-selected accent rendered by controls that need an explicit color value, such as the
    /// "App Accent" swatch. Seed this beside `.tint(...)` at each scene root.
    @Entry var designSystemAccentColor: Color = .accentColor
    /// The user-chosen modal material, seeded at the app root and inherited by presented sheets.
    @Entry var modalMaterial: UI.Theme.WindowMaterial = .sheet
    /// The user-chosen toolbar-control (button) material, seeded at the app root.
    @Entry var buttonMaterial: UI.Theme.WindowMaterial = .glassClear
    /// The user-chosen design-card material, seeded at the app root.
    @Entry var cardMaterial: UI.Theme.WindowMaterial = .glassRegular
    /// Optional color/gradient wash layered into toolbar button groups.
    @Entry var buttonTintStyle: UI.Theme.ButtonTintStyle = .disabled
}

private struct SheetMaterial: ViewModifier {
    @Environment(\.modalMaterial) private var material
    func body(content: Content) -> some View {
        content
            .background {
                if let glass = material.glass {
                    Color.clear.glassEffect(glass, in: Rectangle()).ignoresSafeArea()
                } else {
                    VisualEffectBackground(material: material, blendingMode: .withinWindow)
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
    var cornerRadius = UI.Tokens.Radius.sheet
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
                                   color: UI.Theme.Material.floatingPanelShadow,
                                   radius: UI.Theme.Material.floatingPanelShadowRadius,
                                   y: UI.Theme.Material.floatingPanelShadowY)
                }
            }
            .background {
                if let glass = material.glass {
                    Color.clear.glassEffect(glass, in: shape)
                } else {
                    VisualEffectBackground(material: material, blendingMode: .withinWindow)
                        .clipShape(shape)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(UI.Theme.Material.floatingPanelStroke, lineWidth: 1)
            }
    }
}

private struct ToolbarControlMaterial<S: Shape>: ViewModifier {
    let shape: S
    var material: UI.Theme.WindowMaterial?
    @Environment(\.buttonMaterial) private var buttonMaterial

    func body(content: Content) -> some View {
        let resolvedMaterial = material ?? buttonMaterial
        if let glass = resolvedMaterial.glass {
            content.glassEffect(glass.interactive(), in: shape)
        } else {
            // A vibrancy material chosen for buttons — back the capsule with it and clip.
            content.background {
                VisualEffectBackground(material: resolvedMaterial, blendingMode: .withinWindow)
                    .clipShape(shape)
            }
        }
    }
}

public extension View {
    /// In-window floating panel material. Unlike `.sheet`, this samples the live app content instead
    /// of the dimmed system-modal backdrop, so thin materials actually read thin.
    func floatingPanelMaterial(cornerRadius: CGFloat = UI.Tokens.Radius.sheet,
                               showsShadow: Bool = true) -> some View {
        modifier(FloatingPanelMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow))
    }

    /// Standard interactive glass used by toolbar buttons and collapsed toolbar search.
    func toolbarControlMaterial<S: Shape>(in shape: S,
                                          material: UI.Theme.WindowMaterial? = nil) -> some View {
        modifier(ToolbarControlMaterial(shape: shape, material: material))
    }
}

#Preview("Theme Materials") {
    VStack(spacing: UI.Tokens.Space.l) {
        HStack(spacing: UI.Tokens.Space.s) {
            ForEach(UI.Theme.Tint.allCases) { tint in
                UI.Control.TintSwatch(color: tint.color, followsAccent: tint.followsAccent)
            }
        }

        Text("Floating panel material")
            .frame(maxWidth: .infinity)
            .padding(UI.Tokens.Space.l)
            .floatingPanelMaterial()

        Text("Toolbar control material")
            .padding(.horizontal, UI.Tokens.Space.l)
            .padding(.vertical, UI.Tokens.Space.s)
            .toolbarControlMaterial(in: Capsule())
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 420)
    .environment(\.modalMaterial, .glassRegular)
    .environment(\.buttonMaterial, .glassClear)
}
