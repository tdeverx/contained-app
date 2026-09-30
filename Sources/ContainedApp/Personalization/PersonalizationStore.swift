import SwiftUI
import ContainedCore

/// Local-only personalization store. Resolution cascades per-container override, image default,
/// app image default, then the built-in default. The CLI and containers stay clean: card styling is
/// never written back to runtime labels.
@MainActor
@Observable
final class PersonalizationStore {
    private var overrides: [String: Personalization] = [:]      // keyed by container id (== stable name)
    private var imageDefaults: [String: Personalization] = [:]   // keyed by image reference
    private var volumeStyles: [String: Personalization] = [:]    // keyed by volume name
    private(set) var defaultImageStyle = Personalization()
    private var loadedSuccessfully = false
    private let database: AppDatabase
    private enum Keys {
        static let overrides = "personalizationOverrides"
        static let imageDefaults = "personalizationImageDefaults"
        static let volumeStyles = "personalizationVolumeStyles"
        static let defaultImageStyle = "personalizationDefaultImageStyle"
    }
    private static let imageReferencePrefix = "image-ref:"
    private static let imageGroupReferencePrefix = "image-group-ref:"
    private static let legacyImageGroupPrefix = "image-group:"

    init(database: AppDatabase = AppDatabase()) {
        self.database = database
        loadIfNeeded()
    }

    @discardableResult
    private func loadIfNeeded() -> Bool {
        if loadedSuccessfully { return true }
        guard database.canPersist,
              let records = try? database.fetchRequired(PersonalizationRecord.self),
              let images = try? database.fetchRequired(ImageRecord.self) else { return false }
        overrides = Self.load(database, Keys.overrides, records: records)
        let loadedImageDefaults = Self.load(database, Keys.imageDefaults, records: records)
        imageDefaults = Self.migratedImageDefaults(loadedImageDefaults, records: images)
        volumeStyles = Self.load(database, Keys.volumeStyles, records: records)
        defaultImageStyle = Self.loadStyle(database, Keys.defaultImageStyle, records: records) ?? Personalization()
        if imageDefaults != loadedImageDefaults {
            Self.persist(database, Keys.imageDefaults, imageDefaults)
        }
        loadedSuccessfully = database.canPersist
        return loadedSuccessfully
    }

    func backupSnapshot() -> PersonalizationBackup {
        loadIfNeeded()
        return PersonalizationBackup(overrides: overrides,
                              imageDefaults: imageDefaults,
                              volumeStyles: volumeStyles,
                              defaultImageStyle: defaultImageStyle)
    }

    func applyBackup(_ snapshot: PersonalizationBackup, replace: Bool) {
        guard database.canPersist, loadIfNeeded(),
              let images = try? database.fetchRequired(ImageRecord.self) else { return }
        let importedImageDefaults = Self.migratedImageDefaults(snapshot.imageDefaults, records: images)
        if replace {
            overrides = snapshot.overrides
            imageDefaults = importedImageDefaults
            volumeStyles = snapshot.volumeStyles
        } else {
            overrides.merge(snapshot.overrides) { _, imported in imported }
            imageDefaults.merge(importedImageDefaults) { _, imported in imported }
            volumeStyles.merge(snapshot.volumeStyles) { _, imported in imported }
        }
        defaultImageStyle = snapshot.defaultImageStyle
        persist(Keys.overrides, overrides)
        persist(Keys.imageDefaults, imageDefaults)
        persist(Keys.volumeStyles, volumeStyles)
        Self.persist(database, Keys.defaultImageStyle, defaultImageStyle)
    }

    func purgeOrphans(liveContainerIDs: Set<String>, liveImageRefs: Set<String>) -> Int {
        guard database.canPersist, loadIfNeeded() else { return 0 }
        let before = overrides.count + imageDefaults.count + volumeStyles.count
        let normalizedLiveImageRefs = Set(liveImageRefs.map(Core.Registry.ImageReference.normalizedKey))
        overrides = overrides.filter { liveContainerIDs.contains($0.key) }
        imageDefaults = imageDefaults.filter { key, _ in
            if key.hasPrefix(Self.legacyImageGroupPrefix) { return true }
            if let reference = Self.reference(from: key, prefix: Self.imageReferencePrefix) {
                return normalizedLiveImageRefs.contains(reference)
            }
            if let reference = Self.reference(from: key, prefix: Self.imageGroupReferencePrefix) {
                return normalizedLiveImageRefs.contains(reference)
            }
            return normalizedLiveImageRefs.contains(Core.Registry.ImageReference.normalizedKey(key))
        }
        persist(Keys.overrides, overrides)
        persist(Keys.imageDefaults, imageDefaults)
        persist(Keys.volumeStyles, volumeStyles)
        return before - (overrides.count + imageDefaults.count + volumeStyles.count)
    }

    private static func load(_ database: AppDatabase, _ scope: String, records: [PersonalizationRecord]) -> [String: Personalization] {
        let decoded = Dictionary(records.sorted { $0.updatedAt > $1.updatedAt }
            .filter { $0.scopeRaw == scope }
            .compactMap { record -> (String, Personalization)? in
                do {
                    return (record.key, try JSONDecoder().decode(Personalization.self, from: record.valueData))
                } catch {
                    fatalError("Unable to decode personalization \(scope)/\(record.key): \(error)")
                }
            }, uniquingKeysWith: { newest, _ in newest })
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

    /// Resolve appearance through image inheritance while retaining container-only metadata.
    func resolved(id: String,
                  image: String,
                  group: Core.Image.LocalTagGroup? = nil,
                  fallback: Personalization = Personalization()) -> Personalization {
        let inheritedAppearance = resolvedImageAppearance(for: image,
                                                          group: group,
                                                          fallback: fallback)
        guard let own = Self.meaningful(overrides[id]) else { return inheritedAppearance }
        var resolved = own.hasAppearanceCustomization ? own : inheritedAppearance
        resolved.applyContainerMetadata(from: own)
        return resolved
    }

    // MARK: Per-container overrides

    func hasOverride(id: String) -> Bool {
        loadIfNeeded()
        return Self.meaningful(overrides[id]) != nil
    }

    func hasAppearanceOverride(id: String) -> Bool {
        loadIfNeeded()
        return Self.meaningful(overrides[id])?.hasAppearanceCustomization == true
    }

    func override(for id: String) -> Personalization? {
        loadIfNeeded()
        return Self.meaningful(overrides[id])
    }

    /// Resolve tag appearance independently from tag and image-group nicknames.
    func resolvedImageAppearance(for image: String,
                                 group: Core.Image.LocalTagGroup? = nil,
                                 fallback: Personalization = Personalization()) -> Personalization {
        let groupStyle = group.flatMap(imageGroupDefault(for:))
        let inherited = groupStyle?.hasAppearanceCustomization == true ? groupStyle! : fallback
        let tagStyle = imageDefault(for: image)
        let resolved = tagStyle?.hasAppearanceCustomization == true ? tagStyle! : inherited
        return resolved.appearanceOnly()
    }

    func hasImageAppearanceOverride(for image: String) -> Bool {
        imageDefault(for: image)?.hasAppearanceCustomization == true
    }

    func hasImageGroupAppearanceOverride(for group: Core.Image.LocalTagGroup) -> Bool {
        imageGroupDefault(for: group)?.hasAppearanceCustomization == true
    }

    func setOverride(_ personalization: Personalization, for id: String) {
        guard database.canPersist, loadIfNeeded() else { return }
        if personalization.isDefault {
            clearOverride(id: id)
            return
        }
        overrides[id] = personalization.normalizedForPersistence()
        persist(Keys.overrides, overrides)
    }

    func clearOverride(id: String) {
        guard database.canPersist, loadIfNeeded() else { return }
        overrides[id] = nil
        persist(Keys.overrides, overrides)
    }

    // MARK: Image-level defaults

    func imageDefault(for image: String) -> Personalization? {
        loadIfNeeded()
        return Self.meaningful(imageDefaults[Self.imageReferenceKey(image)])
    }

    func imageDefault(for image: String, group: Core.Image.LocalTagGroup?) -> Personalization? {
        imageDefault(for: image) ?? group.flatMap(imageGroupDefault(for:))
    }

    func imageGroupDefault(for group: Core.Image.LocalTagGroup) -> Personalization? {
        loadIfNeeded()
        for key in Self.imageGroupReferenceKeys(group.references) {
            if let style = Self.meaningful(imageDefaults[key]) { return style }
        }
        return imageGroupDefault(forLegacyID: group.id)
    }

    func imageGroupDefault(forLegacyID groupID: String) -> Personalization? {
        loadIfNeeded()
        return Self.meaningful(imageDefaults[Self.legacyImageGroupKey(groupID)])
    }

    func setImageDefault(_ personalization: Personalization, for image: String) {
        guard database.canPersist, loadIfNeeded() else { return }
        if personalization.isDefault {
            clearImageDefault(for: image)
            return
        }
        imageDefaults[Self.imageReferenceKey(image)] = personalization.normalizedForPersistence()
        persist(Keys.imageDefaults, imageDefaults)
    }

    func setImageGroupDefault(_ personalization: Personalization, for group: Core.Image.LocalTagGroup) {
        guard database.canPersist, loadIfNeeded() else { return }
        if personalization.isDefault {
            clearImageGroupDefault(for: group)
            return
        }
        let style = personalization.normalizedForPersistence()
        for key in Self.imageGroupReferenceKeys(group.references) {
            imageDefaults[key] = style
        }
        imageDefaults[Self.legacyImageGroupKey(group.id)] = nil
        persist(Keys.imageDefaults, imageDefaults)
    }

    func clearImageDefault(for image: String) {
        guard database.canPersist, loadIfNeeded() else { return }
        imageDefaults[Self.imageReferenceKey(image)] = nil
        persist(Keys.imageDefaults, imageDefaults)
    }

    func clearImageGroupDefault(for group: Core.Image.LocalTagGroup) {
        guard database.canPersist, loadIfNeeded() else { return }
        for key in Self.imageGroupReferenceKeys(group.references) {
            imageDefaults[key] = nil
        }
        imageDefaults[Self.legacyImageGroupKey(group.id)] = nil
        persist(Keys.imageDefaults, imageDefaults)
    }

    /// Move digest-keyed group styles onto the group's logical references before inventory changes.
    func stabilizeImageGroupDefaults(for groups: [Core.Image.LocalTagGroup]) {
        guard database.canPersist, loadIfNeeded() else { return }
        var changed = false
        for group in groups {
            guard let style = imageGroupDefault(for: group) else { continue }
            for key in Self.imageGroupReferenceKeys(group.references) where imageDefaults[key] == nil {
                imageDefaults[key] = style
                changed = true
            }
            let legacyKey = Self.legacyImageGroupKey(group.id)
            if imageDefaults.removeValue(forKey: legacyKey) != nil { changed = true }
        }
        if changed { persist(Keys.imageDefaults, imageDefaults) }
    }

    // MARK: App-wide image default

    func setDefaultImageStyle(_ personalization: Personalization) {
        guard database.canPersist, loadIfNeeded() else { return }
        defaultImageStyle = personalization.normalizedForPersistence()
        Self.persist(database, Keys.defaultImageStyle, defaultImageStyle)
    }

    // MARK: Volume styles

    func volumeStyle(for name: String) -> Personalization? {
        loadIfNeeded()
        return Self.meaningful(volumeStyles[name])
    }

    func setVolumeStyle(_ personalization: Personalization, for name: String) {
        guard database.canPersist, loadIfNeeded() else { return }
        if personalization.isDefault {
            clearVolumeStyle(for: name)
            return
        }
        volumeStyles[name] = personalization.normalizedForPersistence()
        persist(Keys.volumeStyles, volumeStyles)
    }

    func clearVolumeStyle(for name: String) {
        guard database.canPersist, loadIfNeeded() else { return }
        volumeStyles[name] = nil
        persist(Keys.volumeStyles, volumeStyles)
    }

    private static func persist(_ database: AppDatabase, _ scope: String, _ values: [String: Personalization]) {
        database.performMutation {
            let records = try database.fetchRequired(PersonalizationRecord.self)
            let wanted = Set(values.keys)
            for record in records where record.scopeRaw == scope && !wanted.contains(record.key) {
                database.context.delete(record)
            }
            for (key, value) in values {
                let data: Data
                do {
                    data = try AppDatabase.encoded(value.normalizedForPersistence())
                } catch {
                    fatalError("Unable to encode personalization \(scope)/\(key): \(error)")
                }
                if let record = records.first(where: { $0.scopeRaw == scope && $0.key == key }) {
                    guard record.valueData != data else { continue }
                    record.valueData = data
                    record.updatedAt = Date()
                } else {
                    database.context.insert(PersonalizationRecord(key: key, scopeRaw: scope, valueData: data))
                }
            }
            database.save()
        }
    }

    private static func loadStyle(_ database: AppDatabase, _ key: String, records: [PersonalizationRecord]) -> Personalization? {
        guard let record = records.sorted(by: { $0.updatedAt > $1.updatedAt }).first(where: { $0.scopeRaw == key && $0.key == "default" }) else { return nil }
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
        database.performMutation {
            let records = try database.fetchRequired(PersonalizationRecord.self)
            let data: Data
            do {
                data = try AppDatabase.encoded(value.normalizedForPersistence())
            } catch {
                fatalError("Unable to encode personalization \(scope)/default: \(error)")
            }
            if let record = records.first(where: { $0.scopeRaw == scope && $0.key == "default" }) {
                guard record.valueData != data else { return }
                record.valueData = data
                record.updatedAt = Date()
            } else {
                database.context.insert(PersonalizationRecord(key: "default", scopeRaw: scope, valueData: data))
            }
            database.save()
        }
    }

    private func persist(_ key: String, _ value: [String: Personalization]) {
        Self.persist(database, key, value)
    }

    private static func migratedImageDefaults(_ values: [String: Personalization],
                                              records: [ImageRecord]) -> [String: Personalization] {
        let recordsByIdentity = Dictionary(records.map { ($0.identity, $0) },
                                           uniquingKeysWith: { first, _ in first })
        let ordered = values.sorted { lhs, rhs in
            let lhsCanonical = isCanonicalImageKey(lhs.key)
            let rhsCanonical = isCanonicalImageKey(rhs.key)
            if lhsCanonical != rhsCanonical { return lhsCanonical }
            return lhs.key < rhs.key
        }
        var migrated: [String: Personalization] = [:]
        for (key, style) in ordered {
            let targetKey: String
            if let reference = reference(from: key, prefix: imageReferencePrefix) {
                targetKey = imageReferenceKey(reference)
            } else if let reference = reference(from: key, prefix: imageGroupReferencePrefix) {
                targetKey = imageGroupReferenceKey(reference)
            } else if let identity = reference(from: key, prefix: legacyImageGroupPrefix) {
                guard let reference = recordsByIdentity[identity]?.primaryReference else {
                    migrated[key] = migrated[key] ?? style
                    continue
                }
                targetKey = imageGroupReferenceKey(reference)
            } else {
                targetKey = imageReferenceKey(key)
            }
            migrated[targetKey] = migrated[targetKey] ?? style
        }
        return migrated
    }

    private static func isCanonicalImageKey(_ key: String) -> Bool {
        key.hasPrefix(imageReferencePrefix) || key.hasPrefix(imageGroupReferencePrefix)
    }

    private static func imageReferenceKey(_ reference: String) -> String {
        imageReferencePrefix + Core.Registry.ImageReference.normalizedKey(reference)
    }

    private static func imageGroupReferenceKey(_ reference: String) -> String {
        imageGroupReferencePrefix + Core.Registry.ImageReference.normalizedKey(reference)
    }

    private static func imageGroupReferenceKeys(_ references: [String]) -> [String] {
        Array(Set(references.map(imageGroupReferenceKey))).sorted()
    }

    private static func legacyImageGroupKey(_ groupID: String) -> String {
        legacyImageGroupPrefix + groupID
    }

    private static func reference(from key: String, prefix: String) -> String? {
        guard key.hasPrefix(prefix) else { return nil }
        return String(key.dropFirst(prefix.count))
    }
}

struct PersonalizationBackup: Codable, Equatable {
    var overrides: [String: Personalization]
    var imageDefaults: [String: Personalization]
    var volumeStyles: [String: Personalization] = [:]
    var defaultImageStyle: Personalization = Personalization()
}
