import Foundation

extension AppStateEnvelope {
    @MainActor
    static func make(from app: AppModel, sections selected: Set<AppStateSection>) throws -> AppStateEnvelope {
        var sections: [AppStateSection: JSONValue] = [:]
        if selected.contains(.settings) {
            sections[.settings] = try JSONValue(app.settings.backupSnapshot())
        }
        if selected.contains(.personalization) {
            sections[.personalization] = try JSONValue(app.personalization.backupSnapshot())
        }
        if selected.contains(.healthChecks) {
            sections[.healthChecks] = try JSONValue(app.healthChecks.backupSnapshot())
        }
        if selected.contains(.templates) {
            sections[.templates] = try JSONValue(app.historyStore.templatesSnapshot())
        }
        if selected.contains(.history) {
            sections[.history] = try JSONValue(app.historyStore.historySnapshot())
        }
        if selected.contains(.caches) {
            sections[.caches] = .object([])
        }
        return AppStateEnvelope(sections: sections)
    }
}

extension JSONValue {
    init<T: Encodable>(_ value: T) throws {
        let data = try JSONEncoder.containedBackup().encode(value)
        self = try JSONDecoder.containedBackup().decode(JSONValue.self, from: data)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder.containedBackup().encode(self)
        return try JSONDecoder.containedBackup().decode(T.self, from: data)
    }
}
