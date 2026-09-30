import Foundation

extension AppleContainerClient {
    func storageCapacity() async throws -> Core.System.StorageCapacity? {
        guard let path = try await systemStatus().appRoot else { return nil }
        return HostStorageScanner.capacity(at: URL(fileURLWithPath: path))
    }

    func storageAnalysis() async throws -> Core.System.StorageAnalysis {
        guard let path = try await systemStatus().appRoot else { throw Core.System.StorageError.unavailable }
        let root = URL(fileURLWithPath: path).standardizedFileURL
        async let usage = try? diskUsage()
        async let containers = listContainers(all: true)
        async let builders = storageBuilders()
        let known = try await containers
        let builderSnapshots = try await builders
        let measurement = try await Task.detached(priority: .utility) {
            try HostStorageScanner.scan(root: root, knownContainers: Set(known.map(\.id)),
                                        builderIDs: Set(builderSnapshots.map(\.id)))
        }.value
        let now = Date()
        let bindIDs = known.filter { snapshot in
            snapshot.state == .running &&
                now.timeIntervalSince(snapshot.startedDate ?? now) >= 86_400 &&
                snapshot.configuration.mounts.contains { mount in
                    mount.type == "bind" || mount.type == "virtiofs"
                }
        }.map(\.id).sorted()
        return Core.System.StorageAnalysis(runtimeKind: descriptor.kind, measuredAt: now,
                                           allocatedBytes: measurement.categories,
                                           resourceAllocatedBytes: measurement.resources,
                                           capacity: HostStorageScanner.capacity(at: root),
                                           runtimeReported: await usage, isComplete: measurement.complete,
                                           unsupportedEntries: measurement.unsupported.sorted(),
                                           longRunningBindContainerIDs: bindIDs)
    }

    func cleanupPlan(_ action: Core.System.CleanupAction, resourceLimit: Int?) async throws -> Core.System.CleanupPlan {
        if action.risk == .compaction {
            let data = try await runner.run(ContainerCommands.version)
            let version = AppleContainerCLILocator.parseVersion(String(decoding: data, as: UTF8.self))
            guard AppleContainerCLILocator.isSupported(version) else {
                throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containerStorageCleanup)
            }
        }
        let inventory = try await storageInventory()
        let all = inventory.identities(for: action)
        let ids = resourceLimit.map { Array(all.prefix(max(0, $0))) } ?? all
        guard ids.allSatisfy({ !$0.isEmpty && !$0.hasPrefix("-") }) else { throw Core.System.StorageError.unavailable }
        let commands = storageCommands(action, ids: ids, builders: inventory.builders)
        let analysis = try? await storageAnalysis()
        let bytes: UInt64?
        switch action {
        case .stoppedContainers, .resetBuilderCache, .unusedVolumes:
            let prefix = action == .unusedVolumes ? "volumes/" : "containers/"
            bytes = analysis.flatMap { value in
                guard value.isComplete else { return nil }
                return ids.reduce(0) { $0 + (value.resourceAllocatedBytes[prefix + $1] ?? 0) }
            }
        default: bytes = nil
        }
        return Core.System.CleanupPlan(id: UUID(), runtimeKind: descriptor.kind, action: action,
                                       resourceIDs: ids, commands: commands, candidateAllocatedBytes: bytes,
                                       createdAt: Date(), validationToken: try inventory.token(), resourceLimit: resourceLimit)
    }

    func executeCleanup(_ plan: Core.System.CleanupPlan) async throws -> Core.System.CleanupResult {
        guard Date().timeIntervalSince(plan.createdAt) < 300 else { throw Core.System.StorageError.stalePlan }
        let before = try? await storageAnalysis()
        // Refresh every prerequisite. Never turn a failed inventory read into a deletion decision.
        let inventory = try await storageInventory()
        guard try inventory.token() == plan.validationToken else { throw Core.System.StorageError.inventoryChanged }
        let all = inventory.identities(for: plan.action)
        let ids = plan.resourceLimit.map { Array(all.prefix(max(0, $0))) } ?? all
        guard ids == plan.resourceIDs,
              storageCommands(plan.action, ids: ids, builders: inventory.builders) == plan.commands else {
            throw Core.System.StorageError.inventoryChanged
        }
        var completed = 0
        var failures: [String] = []
        for command in plan.commands {
            do {
                try Task.checkCancellation()
                _ = try await runner.run(command)
                completed += 1
            } catch {
                failures.append((error as? any Core.Error.PackageError)?.packageErrorCode ?? "storageCommandFailed")
                // Cache reset must not delete a builder if its stop failed.
                if plan.action == .resetBuilderCache || error is CancellationError { break }
            }
        }
        return Core.System.CleanupResult(action: plan.action, completedCount: completed,
                                         failureCodes: failures, before: before, after: try? await storageAnalysis())
    }

    private func storageInventory() async throws -> AppleStorageInventory {
        async let containers = listContainers(all: true)
        async let builders = storageBuilders()
        async let images = images()
        async let volumes = volumes()
        async let networks = networks()
        let builderSnapshots = try await builders
        let builderIDs = Set(builderSnapshots.map(\.id))
        return try await AppleStorageInventory(containers: containers.filter { !builderIDs.contains($0.id) },
                                               builders: builderSnapshots, images: images,
                                               volumes: volumes, networks: networks)
    }

    private func storageBuilders() async throws -> [Core.Container.Snapshot] {
        let data = try await runner.run(ContainerCommands.builderStatus)
        return try Core.Container.JSON.decode([Core.Container.Snapshot].self, from: data, runtimeKind: descriptor.kind)
    }

    private func storageCommands(_ action: Core.System.CleanupAction, ids: [String],
                                 builders: [Core.Container.Snapshot]) -> [[String]] {
        guard !ids.isEmpty else { return [] }
        switch action {
        case .compactRunningContainers, .compactRunningBuilder:
            return ids.map { ContainerCommands.cleanContainers([$0]) }
        case .resetBuilderCache:
            return (builders.contains { $0.state == .running } ? [ContainerCommands.builderStop] : []) + [ContainerCommands.builderDelete]
        case .stoppedContainers: return ids.map { ContainerCommands.deleteContainers([$0], force: false) }
        case .danglingImages, .unusedImages: return ids.map { ContainerCommands.imageDelete([$0]) }
        case .unusedVolumes: return ids.map { ContainerCommands.volumeDelete([$0]) }
        case .unusedNetworks: return ids.map { ContainerCommands.networkDelete([$0]) }
        }
    }
}
