import SwiftUI
import AppKit
import ContainedCore

/// Resolved visual style for a container card: a colored icon plus an optional colored glass
/// background with adjustable opacity and gradient. Stored entirely locally (never written back to
/// the container as labels), keyed by container id (per-container override) or image reference
/// (image-level default).
struct Personalization: Codable, Hashable, Sendable {
    var tint: AppTint = .multicolor
    var icon: String = ""            // SF Symbol name; empty = default
    var nickname: String = ""
    var fillBackground: Bool = true
    var backgroundOpacity: Double = Self.defaultBackgroundOpacity
    var gradient: Bool = true
    var gradientAngle: Double = Self.defaultGradientAngle   // degrees, 0 = leading→trailing, clockwise
    var graphMetric: GraphMetric = .cpu

    static let defaultSymbol = "shippingbox.fill"
    // The shipped default: a colored gradient wash at 40%, angled 135°. Plain (no background) is
    // still one toggle away in Customize.
    static let defaultBackgroundOpacity = 0.40
    static let defaultGradientAngle = 135.0

    var color: Color { tint.color }

    var symbol: String {
        guard !icon.isEmpty,
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

    /// Build from a container's legacy `contained.*` labels — used **only** for the one-time import
    /// of styles created by older versions that injected labels. Nothing writes these labels anymore.
    init(migratingLabels labels: [String: String]) {
        tint = AppTint.parse(labels["contained.tint"])
        icon = labels["contained.icon"] ?? ""
        nickname = labels["contained.nickname"] ?? ""
        fillBackground = labels["contained.bg"] == "1"
        backgroundOpacity = labels["contained.bgOpacity"].flatMap(Double.init) ?? Self.defaultBackgroundOpacity
        gradient = labels["contained.gradient"] == "1"
        gradientAngle = labels["contained.bgAngle"].flatMap(Double.init) ?? Self.defaultGradientAngle
        graphMetric = labels["contained.graph"].flatMap(GraphMetric.init) ?? .cpu
    }

    /// True if a label set carries any legacy `contained.*` personalization worth importing.
    static func hasLegacyLabels(_ labels: [String: String]) -> Bool {
        labels.keys.contains { $0.hasPrefix("contained.") && $0 != "contained.restart" && $0 != "contained.stack" }
    }
}

/// Local-only personalization store. Resolution cascades **per-container override → image default →
/// built-in default**. Persisted to UserDefaults today (migrated to SwiftData in WS7). The CLI and
/// the containers themselves stay clean — no labels are ever written.
@MainActor
@Observable
final class PersonalizationStore {
    private var overrides: [String: Personalization]      // keyed by container id (== stable name)
    private var imageDefaults: [String: Personalization]   // keyed by image reference
    private var volumeStyles: [String: Personalization]    // keyed by volume name
    private let defaults: UserDefaults
    private enum Keys {
        static let overrides = "personalizationOverrides"
        static let imageDefaults = "personalizationImageDefaults"
        static let volumeStyles = "personalizationVolumeStyles"
        static let migrated = "personalizationLabelsMigrated"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        overrides = Self.load(defaults, Keys.overrides)
        imageDefaults = Self.load(defaults, Keys.imageDefaults)
        volumeStyles = Self.load(defaults, Keys.volumeStyles)
    }

    func backupSnapshot() -> PersonalizationBackup {
        PersonalizationBackup(overrides: overrides, imageDefaults: imageDefaults)
    }

    func applyBackup(_ snapshot: PersonalizationBackup, replace: Bool) {
        if replace {
            overrides = snapshot.overrides
            imageDefaults = snapshot.imageDefaults
        } else {
            overrides.merge(snapshot.overrides) { _, imported in imported }
            imageDefaults.merge(snapshot.imageDefaults) { _, imported in imported }
        }
        persist(Keys.overrides, overrides)
        persist(Keys.imageDefaults, imageDefaults)
    }

    func purgeOrphans(liveContainerIDs: Set<String>, liveImageRefs: Set<String>) -> Int {
        let before = overrides.count + imageDefaults.count
        overrides = overrides.filter { liveContainerIDs.contains($0.key) }
        imageDefaults = imageDefaults.filter { liveImageRefs.contains($0.key) }
        persist(Keys.overrides, overrides)
        persist(Keys.imageDefaults, imageDefaults)
        return before - (overrides.count + imageDefaults.count)
    }

    private static func load(_ defaults: UserDefaults, _ key: String) -> [String: Personalization] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Personalization].self, from: data) else { return [:] }
        return decoded
    }

    /// Resolve a container's effective style: per-container override → image default → built-in.
    func resolved(id: String, image: String, groupID: String? = nil) -> Personalization {
        overrides[id] ?? imageDefault(for: image, groupID: groupID) ?? Personalization()
    }

    // MARK: Per-container overrides

    func hasOverride(id: String) -> Bool { overrides[id] != nil }

    func setOverride(_ personalization: Personalization, for id: String) {
        overrides[id] = personalization
        persist(Keys.overrides, overrides)
    }

    func clearOverride(id: String) {
        overrides[id] = nil
        persist(Keys.overrides, overrides)
    }

    // MARK: Image-level defaults

    func imageDefault(for image: String) -> Personalization? { imageDefaults[image] }

    func imageDefault(for image: String, groupID: String?) -> Personalization? {
        imageDefaults[image] ?? groupID.flatMap { imageDefaults[Self.imageGroupKey($0)] }
    }

    func imageGroupDefault(for groupID: String) -> Personalization? {
        imageDefaults[Self.imageGroupKey(groupID)]
    }

    func setImageDefault(_ personalization: Personalization, for image: String) {
        imageDefaults[image] = personalization
        persist(Keys.imageDefaults, imageDefaults)
    }

    func setImageGroupDefault(_ personalization: Personalization, for groupID: String) {
        imageDefaults[Self.imageGroupKey(groupID)] = personalization
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

    // MARK: Volume styles (direct, keyed by volume name)

    func volumeStyle(for name: String) -> Personalization? { volumeStyles[name] }

    func setVolumeStyle(_ personalization: Personalization, for name: String) {
        volumeStyles[name] = personalization
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

    private func persist(_ key: String, _ value: [String: Personalization]) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

struct PersonalizationBackup: Codable, Equatable {
    var overrides: [String: Personalization]
    var imageDefaults: [String: Personalization]
}
