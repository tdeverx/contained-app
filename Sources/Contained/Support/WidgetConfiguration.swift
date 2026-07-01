import AppKit

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

enum GraphStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case area
    case line
    case bar
    case points
    case multiLine
    case range
    case scatter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .area: return "Area"
        case .line: return "Line"
        case .bar: return "Bar"
        case .points: return "Points"
        case .multiLine: return "Multi-Line"
        case .range: return "Range"
        case .scatter: return "Scatter"
        }
    }

    var requiresSecondaryMetric: Bool {
        switch self {
        case .multiLine, .range, .scatter: return true
        case .area, .line, .bar, .points: return false
        }
    }

    func resolvedSecondaryMetric(primary: GraphMetric,
                                 requested: GraphMetric?,
                                 options: [GraphMetric]) -> GraphMetric? {
        guard requiresSecondaryMetric else { return nil }
        if let requested, requested != primary, options.contains(requested) {
            return requested
        }
        return options.first { $0 != primary }
    }

    var usesLineOptions: Bool {
        switch self {
        case .area, .line, .multiLine: return true
        case .bar, .points, .range, .scatter: return false
        }
    }

    var usesPointOptions: Bool {
        switch self {
        case .points, .scatter: return true
        case .area, .line, .bar, .multiLine, .range: return false
        }
    }

    var usesBarOptions: Bool {
        switch self {
        case .bar, .range: return true
        case .area, .line, .points, .multiLine, .scatter: return false
        }
    }
}

enum WidgetInterpolation: String, CaseIterable, Identifiable, Codable, Sendable {
    case linear, catmullRom, cardinal, monotone, stepStart, stepCenter, stepEnd

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .catmullRom: return "Smooth"
        case .cardinal: return "Cardinal"
        case .monotone: return "Monotone"
        case .stepStart: return "Step Start"
        case .stepCenter: return "Step Center"
        case .stepEnd: return "Step End"
        }
    }
}
