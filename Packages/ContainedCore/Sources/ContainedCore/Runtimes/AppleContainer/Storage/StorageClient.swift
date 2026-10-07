import Foundation

extension AppleContainerClient {
    func storageCapacity() async throws -> Core.System.StorageCapacity? {
        guard let path = try await systemStatus().appRoot else { return nil }
        return HostStorageScanner.capacity(at: URL(fileURLWithPath: path))
    }

    func storageAnalysis() async throws -> Core.System.StorageAnalysis {
        async let usage = try? diskUsage()
        async let containers = listContainers(all: true)
        async let builders = storageBuilders()
        let known = try await containers
        let builderSnapshots = try await builders
        let (root, measurement) = try await storageMeasurement(containers: known, builders: builderSnapshots)
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

    func cleanupPlan(_ action: Core.System.CleanupAction, resourceLimit: Int?, afterResourceID: String? = nil) async throws -> Core.System.CleanupPlan {
        try await cleanupPlans([action], resourceLimit: resourceLimit, afterResourceID: afterResourceID)[0]
    }

    func cleanupPlans(_ actions: [Core.System.CleanupAction]) async throws -> [Core.System.CleanupPlan] {
        try await cleanupPlans(actions, resourceLimit: nil, afterResourceID: nil)
    }

    private func cleanupPlans(_ actions: [Core.System.CleanupAction], resourceLimit: Int?, afterResourceID: String?) async throws -> [Core.System.CleanupPlan] {
        guard !actions.isEmpty else { return [] }
        if actions.contains(where: { $0.risk == .compaction }) {
            let data = try await runner.run(ContainerCommands.version)
            let version = AppleContainerCLILocator.parseVersion(String(decoding: data, as: UTF8.self))
            guard AppleContainerCLILocator.isSupported(version) else {
                throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containerStorageCleanup)
            }
        }
        let inventory = try await storageInventory()
        let candidates = try actions.map { action in
            let ids = storageCandidates(inventory.identities(for: action), limit: resourceLimit, after: afterResourceID)
            guard ids.allSatisfy({ !$0.isEmpty && !$0.hasPrefix("-") }) else { throw Core.System.StorageError.unavailable }
            return (action: action, ids: ids, commands: storageCommands(action, ids: ids, builders: inventory.builders))
        }
        let needsMeasurement = candidates.contains { !$0.ids.isEmpty && allocationPrefix(for: $0.action) != nil }
        let measurement: HostStorageScanner.Measurement?
        if needsMeasurement {
            measurement = (try? await storageMeasurement(containers: inventory.containers, builders: inventory.builders))?.measurement
        } else {
            measurement = nil
        }
        let validationToken = try inventory.token()
        let createdAt = Date()
        return candidates.map { candidate in
            let bytes: UInt64?
            if !candidate.ids.isEmpty, let prefix = allocationPrefix(for: candidate.action),
               let measurement, measurement.complete {
                bytes = candidate.ids.reduce(0) { $0 + (measurement.resources[prefix + $1] ?? 0) }
            } else {
                bytes = nil
            }
            return Core.System.CleanupPlan(id: UUID(), runtimeKind: descriptor.kind, action: candidate.action,
                                           resourceIDs: candidate.ids, commands: candidate.commands, candidateAllocatedBytes: bytes,
                                           createdAt: createdAt, validationToken: validationToken, resourceLimit: resourceLimit,
                                           afterResourceID: afterResourceID)
        }
    }

    private func allocationPrefix(for action: Core.System.CleanupAction) -> String? {
        switch action {
        case .stoppedContainers, .resetBuilderCache: "containers/"
        case .unusedVolumes: "volumes/"
        default: nil
        }
    }

    private func storageMeasurement(containers: [Core.Container.Snapshot], builders: [Core.Container.Snapshot]) async throws -> (root: URL, measurement: HostStorageScanner.Measurement) {
        guard let path = try await systemStatus().appRoot else { throw Core.System.StorageError.unavailable }
        let root = URL(fileURLWithPath: path).standardizedFileURL
        let measurement = try await Task.detached(priority: .utility) {
            try HostStorageScanner.scan(root: root, knownContainers: Set(containers.map(\.id)),
                                        builderIDs: Set(builders.map(\.id)))
        }.value
        return (root, measurement)
    }

    func executeCleanup(_ plan: Core.System.CleanupPlan) async throws -> Core.System.CleanupResult {
        guard Date().timeIntervalSince(plan.createdAt) < 300 else { throw Core.System.StorageError.stalePlan }
        let before = try? await storageAnalysis()
        // Refresh every prerequisite. Never turn a failed inventory read into a deletion decision.
        let inventory = try await storageInventory()
        guard try inventory.token() == plan.validationToken else { throw Core.System.StorageError.inventoryChanged }
        let all = inventory.identities(for: plan.action)
        let ids = storageCandidates(all, limit: plan.resourceLimit, after: plan.afterResourceID)
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

    private func storageCandidates(_ all: [String], limit: Int?, after cursor: String?) -> [String] {
        guard let limit else { return all }
        let start = cursor.flatMap { value in all.firstIndex { $0 > value } } ?? 0
        let rotated = Array(all.dropFirst(start)) + Array(all.prefix(start))
        return Array(rotated.prefix(max(0, limit)))
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
