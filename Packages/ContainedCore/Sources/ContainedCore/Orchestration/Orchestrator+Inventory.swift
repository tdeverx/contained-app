import Foundation

public extension Core.Orchestrator {
    func containerInventory(all: Bool = true) async throws -> Core.Runtime.InventoryResult<Core.Container.Snapshot> {
        var snapshots: [Core.Container.Snapshot] = []
        var successes = 0
        var firstError: Swift.Error?
        var failures: [Core.Runtime.InventoryFailure] = []
        for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard runtimes[kind]?.descriptor.supports(.containers) == true else { continue }
            do {
                let runtime = try requireRuntime(kind,
                                                 capability: .containers,
                                                 as: (any RuntimeContainerClient).self)
                snapshots += try await runtime.listContainers(all: all).map { $0.scoped(to: kind) }
                successes += 1
            } catch {
                firstError = firstError ?? error
                failures.append(.init(resource: "containers", kind: kind, message: String(describing: error)))
            }
        }
        if successes == 0, let firstError { throw firstError }
        return Core.Runtime.InventoryResult(items: snapshots, failures: failures)
    }

    func listRuntimeContainers(all: Bool = true) async throws -> [Core.Container.Snapshot] {
        try await containerInventory(all: all).items
    }

    func networkInventory() async throws -> Core.Runtime.InventoryResult<Core.Network.Resource> {
        var networks: [Core.Network.Resource] = []
        var successes = 0
        var firstError: Swift.Error?
        var failures: [Core.Runtime.InventoryFailure] = []
        for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard runtimes[kind]?.descriptor.supports(.networks) == true else { continue }
            do {
                let runtime = try requireRuntime(kind,
                                                 capability: .networks,
                                                 as: (any RuntimeNetworkClient).self)
                networks += try await runtime.networks().map { $0.scoped(to: kind) }
                successes += 1
            } catch {
                firstError = firstError ?? error
                failures.append(.init(resource: "networks", kind: kind, message: String(describing: error)))
            }
        }
        if successes == 0, let firstError { throw firstError }
        return Core.Runtime.InventoryResult(items: networks, failures: failures)
    }

    func runtimeNetworks() async throws -> [Core.Network.Resource] {
        try await networkInventory().items
    }

    func volumeInventory() async throws -> Core.Runtime.InventoryResult<Core.Volume.Resource> {
        var volumes: [Core.Volume.Resource] = []
        var successes = 0
        var firstError: Swift.Error?
        var failures: [Core.Runtime.InventoryFailure] = []
        for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard runtimes[kind]?.descriptor.supports(.volumes) == true else { continue }
            do {
                let runtime = try requireRuntime(kind,
                                                 capability: .volumes,
                                                 as: (any RuntimeVolumeClient).self)
                volumes += try await runtime.volumes().map { $0.scoped(to: kind) }
                successes += 1
            } catch {
                firstError = firstError ?? error
                failures.append(.init(resource: "volumes", kind: kind, message: String(describing: error)))
            }
        }
        if successes == 0, let firstError { throw firstError }
        return Core.Runtime.InventoryResult(items: volumes, failures: failures)
    }

    func runtimeVolumes() async throws -> [Core.Volume.Resource] {
        try await volumeInventory().items
    }

    func imageInventory() async throws -> Core.Runtime.InventoryResult<Core.Image.Resource> {
        var images: [Core.Image.Resource] = []
        var successes = 0
        var firstError: Swift.Error?
        var failures: [Core.Runtime.InventoryFailure] = []
        for kind in runtimes.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard runtimes[kind]?.descriptor.supports(.images) == true else { continue }
            do {
                let runtime = try requireRuntime(kind,
                                                 capability: .images,
                                                 as: (any RuntimeImageClient).self)
                images += try await runtime.images().map { $0.scoped(to: kind) }
                successes += 1
            } catch {
                firstError = firstError ?? error
                failures.append(.init(resource: "images", kind: kind, message: String(describing: error)))
            }
        }
        if successes == 0, let firstError { throw firstError }
        return Core.Runtime.InventoryResult(items: images, failures: failures)
    }

    func runtimeImages() async throws -> [Core.Image.Resource] {
        try await imageInventory().items
    }
}
