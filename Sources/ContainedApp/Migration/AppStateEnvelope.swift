import Foundation

enum AppStateSection: String, Codable, CaseIterable, Identifiable, Sendable {
    case settings
    case personalization
    case healthChecks
    case templates
    case history
    case caches

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .settings: return AppText.string("backup.section.settings", defaultValue: "Settings")
        case .personalization: return AppText.string("backup.section.personalization", defaultValue: "Personalization")
        case .healthChecks: return AppText.string("backup.section.healthChecks", defaultValue: "Health checks")
        case .templates: return AppText.string("backup.section.templates", defaultValue: "Templates")
        case .history: return AppText.string("backup.section.history", defaultValue: "Activity history")
        case .caches: return AppText.string("backup.section.caches", defaultValue: "Caches")
        }
    }
}

struct AppStateEnvelope: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var sections: [AppStateSection: JSONValue]

    init(schemaVersion: Int = StateMigrator.currentSchemaVersion,
         sections: [AppStateSection: JSONValue] = [:]) {
        self.schemaVersion = schemaVersion
        self.sections = sections
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let sectionContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .sections)
        var decoded: [AppStateSection: JSONValue] = [:]
        for key in sectionContainer.allKeys {
            guard let section = AppStateSection(rawValue: key.stringValue) else { continue }
            decoded[section] = try sectionContainer.decode(JSONValue.self, forKey: key)
        }
        sections = decoded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        var sectionContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .sections)
        for (section, value) in sections {
            try sectionContainer.encode(value, forKey: DynamicCodingKey(section.rawValue))
        }
    }
}

extension JSONEncoder {
    static func containedBackup() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static func containedBackup() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
