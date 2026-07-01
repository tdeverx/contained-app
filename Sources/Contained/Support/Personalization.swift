import SwiftUI
import AppKit

/// Resolved visual style for a container card: a colored icon plus an optional colored glass
/// background with adjustable opacity and gradient. Stored entirely locally (never written back to
/// the container as labels), keyed by container id (per-container override) or image reference
/// (image-level default).
struct Personalization: Codable, Hashable, Sendable {
    /// Bump this whenever the stored shape changes so old records can be upgraded on load.
    static let schemaVersion = 2

    var schemaVersion: Int = Self.schemaVersion
    var tint: AppTint = .multicolor
    var iconEnabled: Bool = true
    var icon: String = ""            // SF Symbol name; empty = default
    var nickname: String = ""
    var fillBackground: Bool = true
    var backgroundOpacity: Double = Self.defaultBackgroundOpacity
    var gradient: Bool = true
    var gradientAngle: Double = Self.defaultGradientAngle   // degrees, 0 = leading→trailing, clockwise
    var backgroundBlendMode: ColorLayerBlendMode = .softLight
    var widgets: [WidgetConfiguration] = WidgetConfiguration.defaultWidgets()
    var showStatusIndicator: Bool = true
    var showStatusIcon: Bool = true
    var showStatusText: Bool = true

    static let defaultSymbol = "shippingbox.fill"
    // The shipped default: a colored gradient wash at 40%, angled 135°. Plain (no background) is
    // still one toggle away in Customize.
    static let defaultBackgroundOpacity = 0.40
    static let defaultGradientAngle = 135.0

    var color: Color { tint.color }

    var graphMetric: GraphMetric {
        get { widgets.first(where: { $0.enabled })?.metric ?? widgets.first?.metric ?? .cpu }
        set {
            if widgets.indices.contains(0) {
                widgets[0].metric = newValue
            }
        }
    }

    var graphStyle: GraphStyle {
        get { widgets.first(where: { $0.enabled })?.style ?? widgets.first?.style ?? .area }
        set {
            if widgets.indices.contains(0) {
                widgets[0].style = newValue
            }
        }
    }

    var symbol: String {
        guard iconEnabled,
              !icon.isEmpty,
              NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil else {
            return Self.defaultSymbol
        }
        return icon
    }

    func displayName(fallback id: String) -> String {
        nickname.isEmpty ? id : nickname
    }

    /// True when this is the untouched built-in style (nothing worth persisting).
    var isDefault: Bool { self == Personalization() }

    init() {}

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case tint, iconEnabled, icon, nickname, fillBackground, backgroundOpacity, gradient, gradientAngle
        case backgroundBlendMode
        case widgets, showStatusIndicator, showStatusIcon, showStatusText, graphMetric, graphStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        tint = try container.decodeIfPresent(AppTint.self, forKey: .tint) ?? .multicolor
        iconEnabled = try container.decodeIfPresent(Bool.self, forKey: .iconEnabled) ?? true
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        fillBackground = try container.decodeIfPresent(Bool.self, forKey: .fillBackground) ?? true
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)
            ?? Self.defaultBackgroundOpacity
        gradient = try container.decodeIfPresent(Bool.self, forKey: .gradient) ?? true
        gradientAngle = try container.decodeIfPresent(Double.self, forKey: .gradientAngle)
            ?? Self.defaultGradientAngle
        backgroundBlendMode = try container.decodeIfPresent(ColorLayerBlendMode.self, forKey: .backgroundBlendMode)
            ?? .softLight
        showStatusIndicator = try container.decodeIfPresent(Bool.self, forKey: .showStatusIndicator) ?? true
        showStatusIcon = try container.decodeIfPresent(Bool.self, forKey: .showStatusIcon) ?? true
        showStatusText = try container.decodeIfPresent(Bool.self, forKey: .showStatusText) ?? true
        if let decodedWidgets = try container.decodeIfPresent([WidgetConfiguration].self, forKey: .widgets),
           !decodedWidgets.isEmpty {
            widgets = Self.normalizedWidgets(decodedWidgets)
        } else {
            let metric = try container.decodeIfPresent(GraphMetric.self, forKey: .graphMetric) ?? .cpu
            let style = try container.decodeIfPresent(GraphStyle.self, forKey: .graphStyle) ?? .area
            widgets = Self.normalizedWidgets([
                WidgetConfiguration(enabled: true, metric: metric, style: style),
                WidgetConfiguration(enabled: true, metric: .memory, style: .area),
                WidgetConfiguration(enabled: true, metric: .netRx, style: .area),
                WidgetConfiguration(enabled: true, metric: .netTx, style: .area)
            ])
        }
        schemaVersion = Self.schemaVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
        try container.encode(tint, forKey: .tint)
        try container.encode(iconEnabled, forKey: .iconEnabled)
        try container.encode(icon, forKey: .icon)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(fillBackground, forKey: .fillBackground)
        try container.encode(backgroundOpacity, forKey: .backgroundOpacity)
        try container.encode(gradient, forKey: .gradient)
        try container.encode(gradientAngle, forKey: .gradientAngle)
        try container.encode(backgroundBlendMode, forKey: .backgroundBlendMode)
        try container.encode(widgets, forKey: .widgets)
        try container.encode(showStatusIndicator, forKey: .showStatusIndicator)
        try container.encode(showStatusIcon, forKey: .showStatusIcon)
        try container.encode(showStatusText, forKey: .showStatusText)
        try container.encode(graphMetric, forKey: .graphMetric)
        try container.encode(graphStyle, forKey: .graphStyle)
    }

    /// Build from a container's legacy `contained.*` labels — used **only** for the one-time import
    /// of styles created by older versions that injected labels. Nothing writes these labels anymore.
    init(migratingLabels labels: [String: String]) {
        schemaVersion = Self.schemaVersion
        tint = AppTint.parse(labels["contained.tint"])
        iconEnabled = true
        icon = labels["contained.icon"] ?? ""
        nickname = labels["contained.nickname"] ?? ""
        fillBackground = labels["contained.bg"] == "1"
        backgroundOpacity = labels["contained.bgOpacity"].flatMap(Double.init) ?? Self.defaultBackgroundOpacity
        gradient = labels["contained.gradient"] == "1"
        gradientAngle = labels["contained.bgAngle"].flatMap(Double.init) ?? Self.defaultGradientAngle
        backgroundBlendMode = .softLight
        showStatusIndicator = true
        showStatusIcon = true
        showStatusText = true
        let metric = labels["contained.graph"].flatMap(GraphMetric.init) ?? .cpu
        let style = labels["contained.graphStyle"].flatMap(GraphStyle.init) ?? .area
        widgets = Self.normalizedWidgets([
            WidgetConfiguration(enabled: true, metric: metric, style: style),
            WidgetConfiguration(enabled: true, metric: .memory, style: .area),
            WidgetConfiguration(enabled: true, metric: .netRx, style: .area),
            WidgetConfiguration(enabled: true, metric: .netTx, style: .area)
        ])
    }

    /// True if a label set carries any legacy `contained.*` personalization worth importing.
    static func hasLegacyLabels(_ labels: [String: String]) -> Bool {
        labels.keys.contains { $0.hasPrefix("contained.") && $0 != "contained.restart" && $0 != "contained.stack" }
    }

    mutating func normalizeWidgets() {
        widgets = Self.normalizedWidgets(widgets)
    }

    func normalizedForPersistence() -> Personalization {
        var copy = self
        copy.schemaVersion = Self.schemaVersion
        copy.normalizeWidgets()
        return copy
    }

    mutating func normalizeVolumeWidgets() {
        normalizeWidgets()
        if widgets.indices.contains(0) {
            widgets[0].enabled = true
            widgets[0].metric = .diskRead
            widgets[0].style = .area
        }
        if widgets.indices.contains(1) {
            widgets[1].enabled = true
            widgets[1].metric = .diskWrite
            widgets[1].style = .area
        }
        for index in 2..<widgets.count {
            widgets[index].enabled = false
            widgets[index].metric = .diskRead
            widgets[index].style = .area
        }
    }

    func widget(at index: Int) -> WidgetConfiguration {
        guard widgets.indices.contains(index) else { return WidgetConfiguration() }
        return widgets[index]
    }

    mutating func setWidget(_ widget: WidgetConfiguration, at index: Int) {
        guard widgets.indices.contains(index) else { return }
        widgets[index] = widget
    }

    private static func normalizedWidgets(_ widgets: [WidgetConfiguration]) -> [WidgetConfiguration] {
        let targetCount = Self.widgetSlotCount
        var result = Array(widgets.prefix(targetCount))
        if result.count < targetCount {
            result.append(contentsOf: Array(repeating: WidgetConfiguration(enabled: false),
                                            count: targetCount - result.count))
        }
        return result
    }

    static let widgetSlotCount = 5
}
