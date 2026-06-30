import Foundation
import Testing
@testable import Contained

struct MigrationTests {
    @Test func envelopeRoundTripPreservesUnknownFields() throws {
        let raw = """
        {
          "schemaVersion": 1,
          "sections": {
            "settings": {
              "known": true,
              "futureObject": { "nested": "kept" },
              "futureArray": [1, "two", false]
            }
          }
        }
        """
        let envelope = try JSONDecoder.containedBackup().decode(AppStateEnvelope.self, from: Data(raw.utf8))
        let migrated = try StateMigrator().migrateToCurrent(envelope)
        let data = try JSONEncoder.containedBackup().encode(migrated)
        let decoded = try JSONDecoder.containedBackup().decode(AppStateEnvelope.self, from: data)

        #expect(decoded.sections[.settings]?["futureObject"]?["nested"] == .string("kept"))
        #expect(decoded.sections[.settings]?["futureArray"] != nil)
    }

    @Test func newerSchemaRequiresDowngradeChoice() {
        let defaults = UserDefaults(suiteName: "ContainedMigrationTests-\(UUID().uuidString)")!
        defaults.set(StateMigrator.currentSchemaVersion + 1, forKey: StateMigrator.schemaVersionKey)

        #expect(StateMigrator().reconcile(defaults: defaults) == .newerOnDisk(StateMigrator.currentSchemaVersion + 1))
    }
}
