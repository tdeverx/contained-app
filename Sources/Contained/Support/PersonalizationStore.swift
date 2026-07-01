import SwiftUI
import ContainedCore

/// Local-only personalization store. Resolution cascades per-container override, image default,
/// app image default, then the built-in default. The CLI and containers stay clean: card styling is
/// never written back to runtime labels.
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

    /// Resolve a container's effective style: per-container override -> image default -> fallback.
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

    // MARK: Volume styles

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
