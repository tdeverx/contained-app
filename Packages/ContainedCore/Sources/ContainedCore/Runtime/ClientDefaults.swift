import Foundation

extension RuntimeContainerClient {
    func prepareCreateRequest(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateRequest {
        request
    }

    func listContainers() async throws -> [Core.Container.Snapshot] {
        try await listContainers(all: true)
    }

    func stats() async throws -> [Core.Metrics.ContainerStats] {
        try await stats(ids: [])
    }

    func streamStats() -> AsyncThrowingStream<[Core.Metrics.RuntimeStatsSnapshot], Error> {
        streamStats(ids: [])
    }

    func streamLogs(id: String, follow: Bool, tail: Int?) -> AsyncThrowingStream<String, Error> {
        streamLogs(id: id, follow: follow, tail: tail, boot: false)
    }

    func streamLogs(id: String) -> AsyncThrowingStream<String, Error> {
        streamLogs(id: id, follow: true, tail: 200, boot: false)
    }

    func previewCreateCommand(for request: Core.Container.CreateRequest) throws -> Core.Command.Preview {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containers)
    }

    @discardableResult func createContainer(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containers)
    }

    @discardableResult func recreateContainer(originalID: String,
                                             replacement: Core.Container.CreateRequest,
                                             rollback: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
        // Resolve runtime-owned resources before touching the original. Adapters may need inventory
        // lookups to turn inspected implementation details back into stable create arguments.
        let replacement = try await prepareCreateRequest(replacement)
        let rollback = try await prepareCreateRequest(rollback)
        _ = try? await stop([originalID])
        let deletedOriginal: Bool
        do {
            deletedOriginal = try await deleteContainerIfPresent(originalID, force: true)
        } catch {
            throw Core.Container.RecreateFailure(phase: .deleteOriginal,
                                                 recovery: .notNeeded,
                                                 primaryError: error)
        }

        do {
            return try await createContainer(replacement)
        } catch {
            let replacementError = error
            guard deletedOriginal else {
                throw Core.Container.RecreateFailure(phase: .createReplacement,
                                                     recovery: .notNeeded,
                                                     primaryError: replacementError)
            }
            do {
                _ = try await createContainer(rollback)
            } catch {
                throw Core.Container.RecreateFailure(phase: .restoreOriginal,
                                                     recovery: .restoreFailed,
                                                     primaryError: replacementError,
                                                     recoveryError: error)
            }
            throw Core.Container.RecreateFailure(phase: .createReplacement,
                                                 recovery: .originalRestored,
                                                 primaryError: replacementError)
        }
    }

    private func deleteContainerIfPresent(_ id: String, force: Bool) async throws -> Bool {
        if let current = try? await listContainers(all: true),
           !current.contains(where: { $0.id == id || $0.scopedID == id || $0.scopedID == descriptor.kind.scopedID(for: id) }) {
            return false
        }
        do {
            _ = try await deleteContainers([id], force: force)
            return true
        } catch let error as Core.Command.Error where error.isContainerNotFound {
            return false
        }
    }
}

private extension Core.Command.Error {
    var isContainerNotFound: Bool {
        guard case .nonZeroExit(_, let stderr, _) = self else { return false }
        let lowercased = stderr.lowercased()
        guard lowercased.contains("container") else { return false }
        return lowercased.contains("not found") || lowercased.contains("no such container")
    }
}

extension RuntimeImageClient {
    func streamPull(_ ref: String) -> AsyncThrowingStream<String, Error> {
        streamPull(ref, platform: nil)
    }

    func streamPush(_ ref: String) -> AsyncThrowingStream<String, Error> {
        streamPush(ref, platform: nil)
    }
}

extension RuntimeComposeClient {
    func translateCompose(_ project: Core.Compose.Project, baseDirectory: URL? = nil) throws -> Core.Compose.ImportPlan {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .composeImport)
    }

    func imageDefaults(for request: Core.Container.CreateRequest, in images: [Core.Image.Resource]) throws -> Core.Container.ImageDefaults? {
        nil
    }

    func coreSwitchPlan(for containerID: String, to target: Core.Runtime.Descriptor?) throws -> Core.Migration.Plan {
        Core.Migration.Plan(
            isAvailable: false,
            unavailableReason: .exportImportUnsupported,
            context: [
                "source": descriptor.kind.rawValue,
                "target": target?.kind.rawValue ?? "",
            ],
            source: descriptor.kind,
            target: target?.kind
        )
    }
}

extension RuntimeVolumeClient {
    @discardableResult func createVolume(name: String, size: String?) async throws -> Data {
        try await createVolume(name: name, size: size, labels: [:])
    }

    @discardableResult func createVolume(name: String) async throws -> Data {
        try await createVolume(name: name, size: nil, labels: [:])
    }
}

extension RuntimeNetworkClient {
    @discardableResult func createNetwork(name: String, subnet: String?, internalOnly: Bool) async throws -> Data {
        try await createNetwork(name: name, subnet: subnet, internalOnly: internalOnly, labels: [:])
    }

    @discardableResult func createNetwork(name: String) async throws -> Data {
        try await createNetwork(name: name, subnet: nil, internalOnly: false, labels: [:])
    }
}
