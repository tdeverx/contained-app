import SwiftUI
import AppKit
import ContainedCore

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

/// Local-only personalization store. Resolution cascades **per-container override → image default →
/// app image default → built-in default**. Persisted to UserDefaults today (migrated to SwiftData in
/// WS7). The CLI and the containers themselves stay clean — no labels are ever written.
@MainActor
@Observable
final class PersonalizationStore {
    private var overrides: [String: Personalization]      // keyed by container id (== stable name)
    private var imageDefaults: [String: Personalization]   // keyed by image reference
    private var volumeStyles: [String: Personalization]    // keyed by volume name
    private(set) var defaultImageStyle: Personalization
    private let defaults: UserDefaults
    private enum Keys {
        static let overrides = "personalizationOverrides"
        static let imageDefaults = "personalizationImageDefaults"
        static let volumeStyles = "personalizationVolumeStyles"
        static let defaultImageStyle = "personalizationDefaultImageStyle"
        static let migrated = "personalizationLabelsMigrated"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        overrides = Self.load(defaults, Keys.overrides)
        imageDefaults = Self.load(defaults, Keys.imageDefaults)
        volumeStyles = Self.load(defaults, Keys.volumeStyles)
        defaultImageStyle = Self.loadStyle(defaults, Keys.defaultImageStyle) ?? Personalization()
    }

    func backupSnapshot() -> PersonalizationBackup {
        PersonalizationBackup(overrides: overrides,
                              imageDefaults: imageDefaults,
                              volumeStyles: volumeStyles,
                              defaultImageStyle: defaultImageStyle)
    }

    func applyBackup(_ snapshot: PersonalizationBackup, replace: Bool) {
        if replace {
            overrides = snapshot.overrides
            imageDefaults = snapshot.imageDefaults
            volumeStyles = snapshot.volumeStyles
        } else {
            overrides.merge(snapshot.overrides) { _, imported in imported }
            imageDefaults.merge(snapshot.imageDefaults) { _, imported in imported }
            volumeStyles.merge(snapshot.volumeStyles) { _, imported in imported }
        }
        defaultImageStyle = snapshot.defaultImageStyle
        persist(Keys.overrides, overrides)
        persist(Keys.imageDefaults, imageDefaults)
        persist(Keys.volumeStyles, volumeStyles)
        Self.persist(defaults, Keys.defaultImageStyle, defaultImageStyle)
    }

    func purgeOrphans(liveContainerIDs: Set<String>, liveImageRefs: Set<String>) -> Int {
        let before = overrides.count + imageDefaults.count + volumeStyles.count
        overrides = overrides.filter { liveContainerIDs.contains($0.key) }
        imageDefaults = imageDefaults.filter { key, _ in
            key.hasPrefix("image-group:") || liveImageRefs.contains(key)
        }
        persist(Keys.overrides, overrides)
        persist(Keys.imageDefaults, imageDefaults)
        persist(Keys.volumeStyles, volumeStyles)
        return before - (overrides.count + imageDefaults.count + volumeStyles.count)
    }

    private static func load(_ defaults: UserDefaults, _ key: String) -> [String: Personalization] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Personalization].self, from: data) else { return [:] }
        var migrated: [String: Personalization] = [:]
        var changed = false
        for (entryKey, entryValue) in decoded {
            let normalized = entryValue.normalizedForPersistence()
            if normalized != entryValue { changed = true }
            if !normalized.isDefault {
                migrated[entryKey] = normalized
            } else if decoded[entryKey] != nil {
                changed = true
            }
        }
        if changed {
            persist(defaults, key, migrated)
        }
        return migrated
    }

    private static func meaningful(_ personalization: Personalization?) -> Personalization? {
        guard let personalization, !personalization.isDefault else { return nil }
        return personalization.normalizedForPersistence()
    }

    /// Resolve a container's effective style: per-container override → image default → fallback.
    func resolved(id: String,
                  image: String,
                  groupID: String? = nil,
                  fallback: Personalization = Personalization()) -> Personalization {
        Self.meaningful(overrides[id]) ?? imageDefault(for: image, groupID: groupID) ?? fallback
    }

    // MARK: Per-container overrides

    func hasOverride(id: String) -> Bool { Self.meaningful(overrides[id]) != nil }

    func setOverride(_ personalization: Personalization, for id: String) {
        if personalization.isDefault {
            clearOverride(id: id)
            return
        }
        overrides[id] = personalization.normalizedForPersistence()
        persist(Keys.overrides, overrides)
    }

    func clearOverride(id: String) {
        overrides[id] = nil
        persist(Keys.overrides, overrides)
    }

    // MARK: Image-level defaults

    func imageDefault(for image: String) -> Personalization? { Self.meaningful(imageDefaults[image]) }

    func imageDefault(for image: String, groupID: String?) -> Personalization? {
        Self.meaningful(imageDefaults[image]) ?? groupID.flatMap { Self.meaningful(imageDefaults[Self.imageGroupKey($0)]) }
    }

    func imageGroupDefault(for groupID: String) -> Personalization? { Self.meaningful(imageDefaults[Self.imageGroupKey(groupID)]) }

    func setImageDefault(_ personalization: Personalization, for image: String) {
        if personalization.isDefault {
            clearImageDefault(for: image)
            return
        }
        imageDefaults[image] = personalization.normalizedForPersistence()
        persist(Keys.imageDefaults, imageDefaults)
    }

    func setImageGroupDefault(_ personalization: Personalization, for groupID: String) {
        if personalization.isDefault {
            clearImageGroupDefault(for: groupID)
            return
        }
        imageDefaults[Self.imageGroupKey(groupID)] = personalization.normalizedForPersistence()
        persist(Keys.imageDefaults, imageDefaults)
    }

    func clearImageDefault(for image: String) {
        imageDefaults[image] = nil
        persist(Keys.imageDefaults, imageDefaults)
    }

    func clearImageGroupDefault(for groupID: String) {
        imageDefaults[Self.imageGroupKey(groupID)] = nil
        persist(Keys.imageDefaults, imageDefaults)
    }

    static func imageGroupKey(_ groupID: String) -> String {
        "image-group:\(groupID)"
    }

    // MARK: App-wide image default

    func setDefaultImageStyle(_ personalization: Personalization) {
        defaultImageStyle = personalization.normalizedForPersistence()
        Self.persist(defaults, Keys.defaultImageStyle, defaultImageStyle)
    }

    // MARK: Volume styles (direct, keyed by volume name)

    func volumeStyle(for name: String) -> Personalization? { Self.meaningful(volumeStyles[name]) }

    func setVolumeStyle(_ personalization: Personalization, for name: String) {
        if personalization.isDefault {
            clearVolumeStyle(for: name)
            return
        }
        volumeStyles[name] = personalization.normalizedForPersistence()
        persist(Keys.volumeStyles, volumeStyles)
    }

    func clearVolumeStyle(for name: String) {
        volumeStyles[name] = nil
        persist(Keys.volumeStyles, volumeStyles)
    }

    // MARK: One-time migration

    /// Import legacy `contained.*` styles from existing containers into per-container overrides, once.
    /// Runs after the first container refresh so older users keep their card styles when we stop
    /// writing labels.
    func migrateLegacyLabelsIfNeeded(_ snapshots: [ContainerSnapshot]) {
        guard !defaults.bool(forKey: Keys.migrated) else { return }
        for snapshot in snapshots where Personalization.hasLegacyLabels(snapshot.configuration.labels) {
            if overrides[snapshot.id] == nil {
                overrides[snapshot.id] = Personalization(migratingLabels: snapshot.configuration.labels)
            }
        }
        persist(Keys.overrides, overrides)
        defaults.set(true, forKey: Keys.migrated)
    }

    private static func persist(_ defaults: UserDefaults, _ key: String, _ value: [String: Personalization]) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func loadStyle(_ defaults: UserDefaults, _ key: String) -> Personalization? {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Personalization.self, from: data) else { return nil }
        let normalized = decoded.normalizedForPersistence()
        if normalized != decoded { persist(defaults, key, normalized) }
        return normalized
    }

    private static func persist(_ defaults: UserDefaults, _ key: String, _ value: Personalization) {
        if let data = try? JSONEncoder().encode(value.normalizedForPersistence()) { defaults.set(data, forKey: key) }
    }

    private func persist(_ key: String, _ value: [String: Personalization]) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

struct PersonalizationBackup: Codable, Equatable {
    var overrides: [String: Personalization]
    var imageDefaults: [String: Personalization]
    var volumeStyles: [String: Personalization] = [:]
    var defaultImageStyle: Personalization = Personalization()
}
