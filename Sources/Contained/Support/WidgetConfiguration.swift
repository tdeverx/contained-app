import AppKit
import ContainedDesignSystem

struct WidgetConfiguration: Codable, Hashable, Sendable {
    static let schemaVersion = 4

    var schemaVersion: Int = Self.schemaVersion
    var enabled: Bool = true
    var metric: GraphMetric = .cpu
    var secondaryMetric: GraphMetric?
    var tint: AppTint?
    var icon: String = ""
    var style: GraphStyle = .area
    var areaUsesGradient = true
    var interpolation: WidgetInterpolation = .catmullRom
    var lineWidth: Double = 1.5
    var pointSize: Double = 18
    var barWidth: Double = 4
    var showIcon: Bool = true
    var showText: Bool = true

    enum CodingKeys: String, CodingKey {
        case schemaVersion, enabled, metric, secondaryMetric, tint, icon, style, areaUsesGradient
        case interpolation, lineWidth, pointSize, barWidth, showIcon, showText
    }

    init() {}

    init(enabled: Bool = true,
         metric: GraphMetric = .cpu,
         secondaryMetric: GraphMetric? = nil,
         tint: AppTint? = nil,
         icon: String = "",
         style: GraphStyle = .area,
         areaUsesGradient: Bool = true,
         interpolation: WidgetInterpolation = .catmullRom,
         lineWidth: Double = 1.5,
         pointSize: Double = 18,
         barWidth: Double = 4,
         showIcon: Bool = true,
         showText: Bool = true) {
        self.schemaVersion = Self.schemaVersion
        self.enabled = enabled
        self.metric = metric
        self.secondaryMetric = secondaryMetric
        self.tint = tint
        self.icon = icon
        self.style = style
        self.areaUsesGradient = areaUsesGradient
        self.interpolation = interpolation
        self.lineWidth = lineWidth
        self.pointSize = pointSize
        self.barWidth = barWidth
        self.showIcon = showIcon
        self.showText = showText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        metric = try container.decodeIfPresent(GraphMetric.self, forKey: .metric) ?? .cpu
        secondaryMetric = try container.decodeIfPresent(GraphMetric.self, forKey: .secondaryMetric)
        tint = try container.decodeIfPresent(AppTint.self, forKey: .tint)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        style = try container.decodeIfPresent(GraphStyle.self, forKey: .style) ?? .area
        areaUsesGradient = try container.decodeIfPresent(Bool.self, forKey: .areaUsesGradient) ?? true
        interpolation = try container.decodeIfPresent(WidgetInterpolation.self, forKey: .interpolation) ?? .catmullRom
        lineWidth = try container.decodeIfPresent(Double.self, forKey: .lineWidth) ?? 1.5
        pointSize = try container.decodeIfPresent(Double.self, forKey: .pointSize) ?? 18
        barWidth = try container.decodeIfPresent(Double.self, forKey: .barWidth) ?? 4
        showIcon = try container.decodeIfPresent(Bool.self, forKey: .showIcon) ?? true
        showText = try container.decodeIfPresent(Bool.self, forKey: .showText) ?? true
        schemaVersion = Self.schemaVersion
    }

    static func defaultWidgets() -> [WidgetConfiguration] {
        [
            WidgetConfiguration(enabled: true, metric: .cpu, style: .area),
            WidgetConfiguration(enabled: true, metric: .memory, style: .area),
            WidgetConfiguration(enabled: true, metric: .netRx, style: .area),
            WidgetConfiguration(enabled: true, metric: .netTx, style: .area),
            WidgetConfiguration(enabled: false, metric: .diskRead, style: .area)
        ]
    }

    var resolvedSystemImage: String {
        guard !icon.isEmpty,
              NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil else {
            return metric.systemImage
        }
        return icon
    }
}
