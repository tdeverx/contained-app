import Foundation

public extension Core.Runtime {
struct ContainerMigrationResult: Sendable, Equatable {
    public var source: Core.Container.Snapshot
    public var target: Core.Container.Snapshot
    public var sourceDocument: Core.Schema.Document
    public var targetDocument: Core.Schema.Document

    public init(source: Core.Container.Snapshot,
                target: Core.Container.Snapshot,
                sourceDocument: Core.Schema.Document,
                targetDocument: Core.Schema.Document) {
        self.source = source
        self.target = target
        self.sourceDocument = sourceDocument
        self.targetDocument = targetDocument
    }
}

enum ContainerMigrationError: Error, Equatable, Sendable {
    case imageUnavailable
    case stabilizationTimedOut
}
}

extension Core.Runtime.ContainerMigrationError: Core.Error.PackageError {
    public var packageName: String { "ContainedCore" }
    public var packageErrorCode: String {
        switch self {
        case .imageUnavailable: return "containerMigrationImageUnavailable"
        case .stabilizationTimedOut: return "containerMigrationStabilizationTimedOut"
        }
    }

    public var packageErrorContext: [String: String] { [:] }
}

extension Core.Runtime.ContainerMigrationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            Core.Localization.string("containerMigration.imageUnavailable",
                                     defaultValue: "The image could not be made available on the target runtime.")
        case .stabilizationTimedOut:
            Core.Localization.string("containerMigration.stabilizationTimedOut",
                                     defaultValue: "The target container did not become healthy in time.")
        }
    }
}

public extension Core.Orchestrator {
    func migrateContainer(_ source: Core.Container.Snapshot,
                          sourceDocument: Core.Schema.Document,
                          targetRuntimeKind: Core.Runtime.Kind,
                          healthCheck: Core.Container.HealthCheck?,
                          stabilizationTimeout: TimeInterval = 120,
                          pollInterval: TimeInterval = 2,
                          onPullProgress: (@Sendable (String) async -> Void)? = nil) async throws -> Core.Runtime.ContainerMigrationResult {
        try requireMigrationRuntimePair(source: source.runtimeKind, target: targetRuntimeKind)
        try await stop([source.id], runtimeKind: source.runtimeKind)

        guard try await ensureImage(source.image,
                                    runtimeKind: targetRuntimeKind,
                                    onPullProgress: onPullProgress) else {
            throw Core.Runtime.ContainerMigrationError.imageUnavailable
        }

        let targetDocument = migrationTargetDocument(sourceDocument,
                                                     targetRuntimeKind: targetRuntimeKind)
        let result = try await createContainer(targetDocument)
        let targetID = result.id ?? source.id
        guard let target = try await waitForMigratedContainer(id: targetID,
                                                              runtimeKind: targetRuntimeKind,
                                                              healthCheck: healthCheck,
                                                              stabilizationTimeout: stabilizationTimeout,
                                                              pollInterval: pollInterval) else {
            throw Core.Runtime.ContainerMigrationError.stabilizationTimedOut
        }

        try await deleteContainers([source.id], force: true, runtimeKind: source.runtimeKind)
        return Core.Runtime.ContainerMigrationResult(source: source,
                                                     target: target,
                                                     sourceDocument: sourceDocument,
                                                     targetDocument: targetDocument)
    }

    private func requireMigrationRuntimePair(source: Core.Runtime.Kind,
                                             target: Core.Runtime.Kind) throws {
        _ = try requireRuntime(source, capability: .containers)
        _ = try requireRuntime(target, capability: .containers)
    }

    private func migrationTargetDocument(_ sourceDocument: Core.Schema.Document,
                                         targetRuntimeKind: Core.Runtime.Kind) -> Core.Schema.Document {
        var document = sourceDocument
        document.operation = .containerCreate
        document.runtimeKind = targetRuntimeKind
        document.set(.runtimeKind, .string(targetRuntimeKind.rawValue))
        let definition = schemaDefinition(for: .containerCreate, runtimeKind: targetRuntimeKind)
        return document.migrated(to: definition)
    }

    private func ensureImage(_ reference: String,
                             runtimeKind: Core.Runtime.Kind,
                             onPullProgress: (@Sendable (String) async -> Void)?) async throws -> Bool {
        let target = Core.Registry.ImageReference.normalizedKey(reference)
        let images = try await requireRuntime(runtimeKind, capability: .images).images()
        if images.contains(where: { Core.Registry.ImageReference.normalizedKey($0.reference) == target }) {
            return true
        }
        do {
            for try await line in streamPull(reference, platform: nil, runtimeKind: runtimeKind) {
                await onPullProgress?(line)
            }
            return true
        } catch {
            return false
        }
    }

    private func waitForMigratedContainer(id: String,
                                          runtimeKind: Core.Runtime.Kind,
                                          healthCheck: Core.Container.HealthCheck?,
                                          stabilizationTimeout: TimeInterval,
                                          pollInterval: TimeInterval) async throws -> Core.Container.Snapshot? {
        let deadline = Date().addingTimeInterval(stabilizationTimeout)
        repeat {
            let snapshots = try await requireRuntime(runtimeKind, capability: .containers)
                .listContainers(all: true)
                .map { $0.scoped(to: runtimeKind) }
            if let target = snapshots.first(where: { $0.id == id }) {
                if let healthCheck, healthCheck.isActive {
                    if (try? await execCapture(target.id, healthCheck.command, runtimeKind: runtimeKind)) != nil {
                        return target
                    }
                } else if target.state == .running {
                    return target
                }
            }
            if Date() >= deadline { break }
            let seconds = max(0, pollInterval)
            if seconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } else {
                await Task.yield()
            }
        } while !Task.isCancelled
        return nil
    }
}
