import Foundation
import Testing
@testable import ContainedCore

@Suite("Storage management")
struct StorageManagementTests {
    @Test func candidatesProtectRunningStoppedAndBuilderReferences() throws {
        let running = try snapshot("running", state: "running", image: "used:latest", mount: "/store/volumes/data/volume.img", network: "custom")
        let stopped = try snapshot("stopped", state: "stopped", image: "old:latest", mount: "old-data", network: "stopped-net")
        let builder = try snapshot("buildkit", state: "running", image: "builder:latest")
        let inventory = AppleStorageInventory(containers: [running, stopped], builders: [builder],
                                               images: [image("used:latest"), image("old:latest"), image("builder:latest"), image("unused:latest")],
                                               volumes: [volume("data", source: "/store/volumes/data/volume.img"), volume("old-data"), volume("unused")],
                                               networks: [network("default"), network("custom"), network("stopped-net"), network("unused"), network("builtin", role: "builtin"), network("system", role: "system")])
        #expect(inventory.identities(for: .compactRunningContainers) == ["running"])
        #expect(inventory.identities(for: .compactRunningBuilder) == ["buildkit"])
        #expect(inventory.identities(for: .stoppedContainers) == ["stopped"])
        #expect(inventory.identities(for: .unusedImages) == ["unused:latest"])
        #expect(inventory.identities(for: .unusedVolumes) == ["unused"])
        #expect(inventory.identities(for: .unusedNetworks) == ["unused"])
        #expect(Core.System.CleanupAction.allCases.filter(\.automaticAllowed) == [.compactRunningContainers, .compactRunningBuilder])
    }

    @Test func oldCLICannotCreateACompactionPlan() async throws {
        let directory = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = StorageRunner(root: directory, inventory: emptyInventory(), version: "1.0.0")
        let client = AppleContainerClient(runner: runner)
        await #expect(throws: Core.Runtime.UnsupportedCapability.self) {
            _ = try await client.cleanupPlan(.compactRunningContainers, resourceLimit: nil)
        }
        #expect(await runner.mutations.isEmpty)
    }

    @Test func exactCommandsPartialFailuresAndObservedHostReclaim() async throws {
        let directory = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = directory.appendingPathComponent("containers/first/root.img")
        try FileManager.default.createDirectory(at: disk.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: 131_072).write(to: disk)
        var inventory = emptyInventory()
        inventory.containers = [try snapshot("first", state: "running"), try snapshot("second", state: "running")]
        let runner = StorageRunner(root: directory, inventory: inventory)
        let client = AppleContainerClient(runner: runner)
        let plan = try await client.cleanupPlan(.compactRunningContainers, resourceLimit: nil)
        #expect(plan.commands == [["clean", "first"], ["clean", "second"]])
        let result = try await client.executeCleanup(plan)
        #expect(result.completedCount == 1)
        #expect(result.failureCodes == ["nonZeroExit"])
        #expect((result.reclaimedHostBytes ?? 0) > 0)
        #expect(await runner.mutations == plan.commands)
    }

    @Test func changedInventoryRejectsDeletionAndBuilderStopFailurePreventsDelete() async throws {
        let directory = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: directory) }
        var inventory = emptyInventory()
        inventory.containers = [try snapshot("stopped", state: "stopped")]
        let runner = StorageRunner(root: directory, inventory: inventory)
        let client = AppleContainerClient(runner: runner)
        let plan = try await client.cleanupPlan(.stoppedContainers, resourceLimit: nil)
        inventory.containers = [try snapshot("stopped", state: "running")]
        await runner.replace(inventory)
        await #expect(throws: Core.System.StorageError.self) { _ = try await client.executeCleanup(plan) }
        #expect(await runner.mutations.isEmpty)
        inventory.builders = [try snapshot("buildkit", state: "running")]
        await runner.replace(inventory)
        let builderPlan = try await client.cleanupPlan(.resetBuilderCache, resourceLimit: nil)
        #expect(builderPlan.commands == [["builder", "stop"], ["builder", "delete"]])
        let result = try await client.executeCleanup(builderPlan)
        #expect(result.failureCodes == ["nonZeroExit"])
        #expect(await runner.mutations == [["builder", "stop"]])
    }

    @Test func scanDoesNotFollowSymlinksAndPolicyRequiresCompleteMeasurements() throws {
        let directory = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("other-file")
        try Data(repeating: 1, count: 8192).write(to: target)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("alias"), withDestinationURL: target)
        let measured = try HostStorageScanner.scan(root: directory, knownContainers: [], builderIDs: [])
        #expect(measured.complete)
        #expect(measured.unsupported.contains("symlink/alias"))
        #expect(measured.categories[.other, default: 0] >= 8192)
        #expect(measured.categories[.other, default: 0] < 16_384)
        let now = Date()
        var analysis = Core.System.StorageAnalysis(runtimeKind: .appleContainer, measuredAt: now,
                                                  allocatedBytes: [.containers: 200 * 1_073_741_824], resourceAllocatedBytes: [:],
                                                  capacity: .init(availableBytes: 100, totalBytes: 1000), runtimeReported: nil,
                                                  isComplete: false, unsupportedEntries: [], longRunningBindContainerIDs: [])
        var policy = Core.System.StorageCleanupPolicy()
        #expect(!policy.shouldRun(analysis: analysis, lastRun: nil))
        policy.enabled = true
        #expect(!policy.shouldRun(analysis: analysis, lastRun: nil))
        analysis = .init(runtimeKind: analysis.runtimeKind, measuredAt: now, allocatedBytes: analysis.allocatedBytes,
                         resourceAllocatedBytes: [:], capacity: analysis.capacity, runtimeReported: nil,
                         isComplete: true, unsupportedEntries: [], longRunningBindContainerIDs: [])
        #expect(policy.shouldRun(analysis: analysis, lastRun: nil, now: now))
        #expect(!policy.shouldRun(analysis: analysis, lastRun: now.addingTimeInterval(-3600), now: now))
        #expect(policy.shouldRun(analysis: analysis, lastRun: now.addingTimeInterval(-6 * 3600), now: now))
        policy.compactContainers = false
        #expect(!policy.shouldRun(analysis: analysis, lastRun: nil, now: now))
        policy.compactBuilder = true
        #expect(policy.shouldRun(analysis: analysis, lastRun: nil, now: now))
        #expect(Core.System.StorageCapacity(availableBytes: 100, totalBytes: 1000).isCritical)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ContainedStorageTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func emptyInventory() -> AppleStorageInventory {
        .init(containers: [], builders: [], images: [], volumes: [], networks: [])
    }

    private func snapshot(_ id: String, state: String, image: String = "alpine", mount: String = "data", network: String = "default") throws -> Core.Container.Snapshot {
        try Core.Container.JSON.decode(Core.Container.Snapshot.self, from: Data("""
        {"id":"\(id)","status":{"state":"\(state)"},"configuration":{"id":"\(id)","image":{"reference":"\(image)"},"initProcess":{},"mounts":[{"type":"volume","source":"\(mount)","destination":"/data"}],"networks":[{"network":"\(network)"}]}}
        """.utf8), runtimeKind: .appleContainer)
    }

    private func image(_ name: String) -> Core.Image.Resource {
        .init(configuration: .init(name: name, descriptor: nil, creationDate: nil), id: name, runtimeKind: .appleContainer)
    }
    private func volume(_ name: String, source: String? = nil) -> Core.Volume.Resource {
        .init(configuration: .init(name: name, source: source), runtimeKind: .appleContainer)
    }
    private func network(_ name: String, role: String? = nil) -> Core.Network.Resource {
        .init(configuration: .init(name: name, labels: role.map { ["com.apple.container.resource.role": $0] } ?? [:]),
              id: name, status: nil, runtimeKind: .appleContainer)
    }
}

private actor StorageRunner: Core.Command.Running {
    let root: URL
    var inventory: AppleStorageInventory
    let version: String
    var mutations: [[String]] = []
    init(root: URL, inventory: AppleStorageInventory, version: String = "1.4.1") {
        self.root = root; self.inventory = inventory; self.version = version
    }
    func replace(_ value: AppleStorageInventory) { inventory = value }
    func run(_ arguments: [String], stdin: Data?, priority: Core.Command.ExecutionPriority) async throws -> Data {
        let encoder = JSONEncoder()
        switch arguments {
        case ContainerCommands.version: return Data("container version \(version)\n".utf8)
        case ContainerCommands.systemStatus:
            return try encoder.encode(Core.System.Status(status: "running", appRoot: root.path, installRoot: "/usr/local", apiServerVersion: version, apiServerCommit: nil, apiServerBuild: nil, apiServerAppName: nil))
        case ContainerCommands.systemDF:
            return Data(#"{"containers":{"active":0,"total":0,"sizeInBytes":0,"reclaimable":0},"images":{"active":0,"total":0,"sizeInBytes":0,"reclaimable":0},"volumes":{"active":0,"total":0,"sizeInBytes":0,"reclaimable":0}}"#.utf8)
        case ContainerCommands.list(all: true): return try encoder.encode(inventory.containers)
        case ContainerCommands.builderStatus: return try encoder.encode(inventory.builders)
        case ContainerCommands.imageList(): return try encoder.encode(inventory.images)
        case ContainerCommands.volumeList(): return try encoder.encode(inventory.volumes)
        case ContainerCommands.networkList(): return try encoder.encode(inventory.networks)
        default:
            mutations.append(arguments)
            if arguments == ["clean", "first"] {
                let handle = try FileHandle(forWritingTo: root.appendingPathComponent("containers/first/root.img"))
                try handle.truncate(atOffset: 0)
                try handle.close()
                return Data()
            }
            throw Core.Command.Error.nonZeroExit(code: 1, stderr: "private path and token must never be reported", command: arguments.joined(separator: " "))
        }
    }
    nonisolated func stream(_ arguments: [String], priority: Core.Command.ExecutionPriority) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

@Suite("Live storage audit", .enabled(if: ProcessInfo.processInfo.environment["CONTAINED_LIVE_STORAGE_AUDIT"] == "1"))
struct LiveStorageAuditTests {
    @Test func compactionPreviewCanReadTheLiveInventoryWithoutExecutingCommands() async throws {
        let core = try #require(Core.Orchestrator.live())
        let plan = try await core.cleanupPlan(.compactRunningContainers, runtimeKind: .appleContainer)
        print("Live compaction preview: \(plan.resourceIDs.count) identities, \(plan.commands.count) commands; no execution")
        #expect(plan.resourceIDs.count == plan.commands.count)
        #expect(plan.commands.allSatisfy { $0.count == 2 && $0.first == "clean" })
    }

    @Test func allocatedSpaceIsReadableWithoutMutatingContainers() async throws {
        let core = try #require(Core.Orchestrator.live())
        let analysis = try await core.storageAnalysis(runtimeKind: .appleContainer)
        print("Storage allocation bytes: \(analysis.totalAllocatedBytes), complete: \(analysis.isComplete)")
        for category in Core.System.StorageCategory.allCases {
            print("\(category.rawValue): \(analysis.allocatedBytes[category] ?? 0)")
        }
        #expect(analysis.totalAllocatedBytes > 0)
        #expect(analysis.capacity != nil)
    }
}
