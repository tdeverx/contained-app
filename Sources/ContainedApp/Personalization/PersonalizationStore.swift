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
    private let database: AppDatabase
    private enum Keys {
        static let overrides = "personalizationOverrides"
        static let imageDefaults = "personalizationImageDefaults"
        static let volumeStyles = "personalizationVolumeStyles"
        static let defaultImageStyle = "personalizationDefaultImageStyle"
    }

    init(database: AppDatabase = AppDatabase()) {
        self.database = database
        overrides = Self.load(database, Keys.overrides)
        imageDefaults = Self.load(database, Keys.imageDefaults)
        volumeStyles = Self.load(database, Keys.volumeStyles)
        defaultImageStyle = Self.loadStyle(database, Keys.defaultImageStyle) ?? Personalization()
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
        Self.persist(database, Keys.defaultImageStyle, defaultImageStyle)
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

    private static func load(_ database: AppDatabase, _ scope: String) -> [String: Personalization] {
        let decoded = Dictionary(uniqueKeysWithValues: database.fetch(PersonalizationRecord.self)
            .filter { $0.scopeRaw == scope }
            .compactMap { record -> (String, Personalization)? in
                do {
                    return (record.key, try JSONDecoder().decode(Personalization.self, from: record.valueData))
                } catch {
                    fatalError("Unable to decode personalization \(scope)/\(record.key): \(error)")
                }
            })
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
            persist(database, scope, migrated)
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
        Self.persist(database, Keys.defaultImageStyle, defaultImageStyle)
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

    private static func persist(_ database: AppDatabase, _ scope: String, _ values: [String: Personalization]) {
        let wanted = Set(values.keys)
        for record in database.fetch(PersonalizationRecord.self) where record.scopeRaw == scope && !wanted.contains(record.key) {
            database.context.delete(record)
        }
        for (key, value) in values {
            let data: Data
            do {
                data = try JSONEncoder().encode(value.normalizedForPersistence())
            } catch {
                fatalError("Unable to encode personalization \(scope)/\(key): \(error)")
            }
            if let record = database.fetch(PersonalizationRecord.self).first(where: { $0.scopeRaw == scope && $0.key == key }) {
                record.valueData = data
                record.updatedAt = Date()
            } else {
                database.context.insert(PersonalizationRecord(key: key, scopeRaw: scope, valueData: data))
            }
        }
        database.save()
    }

    private static func loadStyle(_ database: AppDatabase, _ key: String) -> Personalization? {
        guard let record = database.fetch(PersonalizationRecord.self).first(where: { $0.scopeRaw == key && $0.key == "default" }) else { return nil }
        let decoded: Personalization
        do {
            decoded = try JSONDecoder().decode(Personalization.self, from: record.valueData)
        } catch {
            fatalError("Unable to decode personalization \(key)/default: \(error)")
        }
        let normalized = decoded.normalizedForPersistence()
        if normalized != decoded { persist(database, key, normalized) }
        return normalized
    }

    private static func persist(_ database: AppDatabase, _ scope: String, _ value: Personalization) {
        let data: Data
        do {
            data = try JSONEncoder().encode(value.normalizedForPersistence())
        } catch {
            fatalError("Unable to encode personalization \(scope)/default: \(error)")
        }
        if let record = database.fetch(PersonalizationRecord.self).first(where: { $0.scopeRaw == scope && $0.key == "default" }) {
            record.valueData = data
            record.updatedAt = Date()
        } else {
            database.context.insert(PersonalizationRecord(key: "default", scopeRaw: scope, valueData: data))
        }
        database.save()
    }

    private func persist(_ key: String, _ value: [String: Personalization]) {
        Self.persist(database, key, value)
    }
}

struct PersonalizationBackup: Codable, Equatable {
    var overrides: [String: Personalization]
    var imageDefaults: [String: Personalization]
    var volumeStyles: [String: Personalization] = [:]
    var defaultImageStyle: Personalization = Personalization()
}
