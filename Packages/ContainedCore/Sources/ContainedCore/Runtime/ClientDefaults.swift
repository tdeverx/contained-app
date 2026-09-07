import Foundation

extension RuntimeContainerClient {
    var recreateVerificationDelay: Duration { .zero }

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
        let originalWasRunning = try? await containerSnapshot(matching: originalID)?.state == .running
        let expectedImageIdentities = try await resolvedImageIdentities(for: replacement.image)
        _ = try? await stop([originalID])
        let deletedOriginal: Bool
        do {
            deletedOriginal = try await deleteContainerIfPresent(originalID, force: true)
        } catch {
            throw Core.Container.RecreateFailure(phase: .deleteOriginal,
                                                 recovery: .notNeeded,
                                                 primaryError: error)
        }

        var createdReplacementID: String?
        do {
            let result = try await createContainer(replacement)
            createdReplacementID = result.id ?? replacement.name
            try await verifyReplacement(id: createdReplacementID,
                                        expectedImageIdentities: expectedImageIdentities,
                                        mustBeRunning: originalWasRunning == true)
            return result
        } catch {
            let replacementError = error
            if let createdReplacementID, !createdReplacementID.isEmpty {
                _ = try? await deleteContainerIfPresent(createdReplacementID, force: true)
            }
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

    private func resolvedImageIdentities(for reference: String) async throws -> Set<String>? {
        guard let imageClient = self as? any RuntimeImageClient else { return nil }
        let images = try await imageClient.inspectImage(reference)
        let identities = images.reduce(into: Set<String>()) { result, image in
            result.insert(Self.normalizedImageIdentity(image.id))
            if let digest = image.digest {
                result.insert(Self.normalizedImageIdentity(digest))
            }
        }
        return identities.isEmpty ? nil : identities
    }

    private func verifyReplacement(id: String?,
                                   expectedImageIdentities: Set<String>?,
                                   mustBeRunning: Bool) async throws {
        guard let id, !id.isEmpty else {
            throw RecreateVerificationError.replacementUnavailable(id: "")
        }
        try await Task.sleep(for: recreateVerificationDelay)
        guard let replacement = try await containerSnapshot(matching: id) else {
            throw RecreateVerificationError.replacementUnavailable(id: id)
        }
        if let expectedImageIdentities {
            guard let digest = replacement.configuration.image.descriptor?.digest,
                  expectedImageIdentities.contains(Self.normalizedImageIdentity(digest)) else {
                throw RecreateVerificationError.imageMismatch(
                    expected: expectedImageIdentities.sorted(),
                    actual: replacement.configuration.image.descriptor?.digest
                )
            }
        }
        if mustBeRunning, replacement.state != .running {
            throw RecreateVerificationError.replacementNotRunning(id: id, state: replacement.rawState)
        }
    }

    private func containerSnapshot(matching id: String) async throws -> Core.Container.Snapshot? {
        try await listContainers(all: true).first {
            $0.id == id || $0.scopedID == id || $0.scopedID == descriptor.kind.scopedID(for: id)
        }
    }

    private static func normalizedImageIdentity(_ identity: String) -> String {
        identity.hasPrefix("sha256:") ? String(identity.dropFirst("sha256:".count)) : identity
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

private enum RecreateVerificationError: LocalizedError, Core.Error.PackageError {
    case replacementUnavailable(id: String)
    case replacementNotRunning(id: String, state: String)
    case imageMismatch(expected: [String], actual: String?)

    var packageName: String { "ContainedCore" }

    var packageErrorCode: String {
        switch self {
        case .replacementUnavailable: "recreateReplacementUnavailable"
        case .replacementNotRunning: "recreateReplacementNotRunning"
        case .imageMismatch: "recreateImageMismatch"
        }
    }

    var packageErrorContext: [String: String] { [:] }

    var errorDescription: String? {
        switch self {
        case .replacementUnavailable(let id):
            "Replacement container \(id) was not available after creation."
        case .replacementNotRunning(let id, let state):
            "Replacement container \(id) entered state \(state) during startup verification."
        case .imageMismatch(let expected, let actual):
            "Replacement resolved image \(actual ?? "unknown") instead of \(expected.joined(separator: ", "))."
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
