import Foundation

struct StateMigrator {
    static let currentSchemaVersion = 1
    static let schemaVersionKey = "contained.state.schemaVersion"

    private var steps: [any MigrationStep] = []

    init(steps: [any MigrationStep] = []) {
        self.steps = steps
    }

    enum ReconcileResult: Equatable {
        case ready
        case newerOnDisk(Int)
    }

    func reconcile(defaults: UserDefaults = .standard) -> ReconcileResult {
        let stored = defaults.object(forKey: Self.schemaVersionKey) as? Int ?? Self.currentSchemaVersion
        if stored > Self.currentSchemaVersion {
            return .newerOnDisk(stored)
        }
        defaults.set(Self.currentSchemaVersion, forKey: Self.schemaVersionKey)
        return .ready
    }

    func migrateToCurrent(_ envelope: AppStateEnvelope) throws -> AppStateEnvelope {
        try migrate(envelope, to: Self.currentSchemaVersion)
    }

    func migrate(_ envelope: AppStateEnvelope, to targetVersion: Int) throws -> AppStateEnvelope {
        if envelope.schemaVersion == targetVersion { return envelope }
        if envelope.schemaVersion < targetVersion {
            return try chain(envelope, targetVersion: targetVersion, direction: .up)
        }
        return try chain(envelope, targetVersion: targetVersion, direction: .down)
    }

    private enum Direction { case up, down }

    private func chain(_ envelope: AppStateEnvelope,
                       targetVersion: Int,
                       direction: Direction) throws -> AppStateEnvelope {
        var working = envelope
        while working.schemaVersion != targetVersion {
            let nextVersion = direction == .up ? working.schemaVersion + 1 : working.schemaVersion - 1
            guard let step = step(from: working.schemaVersion, to: nextVersion) else {
                if direction == .down {
                    throw MigrationError.missingDowngradeStep(from: working.schemaVersion, to: nextVersion)
                }
                throw MigrationError.unsupportedFutureSchema(working.schemaVersion)
            }
            var migratedSections: [AppStateSection: JSONValue] = [:]
            for (name, value) in working.sections {
                migratedSections[name] = try direction == .up
                    ? step.upgrade(value, named: name)
                    : step.downgrade(value, named: name)
            }
            working = AppStateEnvelope(schemaVersion: nextVersion, sections: migratedSections)
        }
        return working
    }

    private func step(from: Int, to: Int) -> (any MigrationStep)? {
        steps.first { step in
            step.fromVersion == from && step.toVersion == to
        }
    }
}
