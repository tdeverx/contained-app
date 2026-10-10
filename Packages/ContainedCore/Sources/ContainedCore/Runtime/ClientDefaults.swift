import Foundation

extension RuntimeContainerClient {
    var recreateVerificationDelay: Duration { .zero }

    /// Fetch only the immutable original, then verify it before any lifecycle mutation.
    func prepareRecoveryRequest(_ request: Core.Container.CreateRequest) async throws -> Core.Container.CreateRequest {
        try Task.checkCancellation()
        let pinned = Core.Registry.ImageReference.parse(request.image)
        guard pinned.isDigestReference else { return try await prepareCreateRequest(request) }
        do {
            if let images = self as? any RuntimeImageClient {
                let inventory = try await images.images()
                if !inventory.contains(where: {
                    Self.normalizedImageIdentity($0.id) == Self.normalizedImageIdentity(pinned.reference) ||
                    $0.digest.map(Self.normalizedImageIdentity) == Self.normalizedImageIdentity(pinned.reference)
                }) {
                    for try await _ in images.streamPull(request.image, platform: request.platform.isEmpty ? nil : request.platform) {
                        try Task.checkCancellation()
                    }
                }
            }
            // Cancellation can end an AsyncThrowingStream without yielding or throwing.
            try Task.checkCancellation()
            let prepared = try await prepareCreateRequest(request)
            _ = try await resolvedImageIdentities(for: prepared.image, pinnedReference: request.image)
            try Task.checkCancellation()
            return prepared
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Core.Container.RecoveryImageFailure(cause: .init(error))
        }
    }

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

    func previewCreateCommand(for request: Core.Container.CreateRequest, start: Bool) throws -> Core.Command.Preview {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containers)
    }

    @discardableResult func createContainer(_ request: Core.Container.CreateRequest, start: Bool) async throws -> Core.Container.CreateResult {
        throw Core.Runtime.UnsupportedCapability(kind: descriptor.kind, capability: .containers)
    }

    /// Explicit recovery only creates a missing object; it never deletes a colliding workload.
    func restoreContainer(_ request: Core.Container.CreateRequest, originalWasRunning: Bool) async throws -> Core.Container.CreateResult {
        let pinnedReference = request.image
        guard !request.name.isEmpty, try await containerSnapshot(matching: request.name) == nil else {
            throw RecreateVerificationError.recoveryNameInUse
        }
        let request = try await prepareRecoveryRequest(request)
        let identities = try await resolvedImageIdentities(for: request.image, pinnedReference: pinnedReference)
        try Task.checkCancellation()
        let result = try await createContainer(request, start: originalWasRunning)
        try await verifyReplacement(id: result.id ?? request.name,
                                    expectedImageIdentities: identities,
                                    requiredState: originalWasRunning ? .running : .stopped)
        return result
    }

    @discardableResult func recreateContainer(originalID: String,
                                             replacement: Core.Container.CreateRequest,
                                             rollback: Core.Container.CreateRequest) async throws -> Core.Container.CreateResult {
        // Resolve runtime-owned resources before touching the original. Adapters may need inventory
        // lookups to turn inspected implementation details back into stable create arguments.
        let replacementReference = replacement.image
        let rollbackReference = rollback.image
        let replacement = try await prepareCreateRequest(replacement)
        let rollback = try await prepareRecoveryRequest(rollback)
        let original = try await containerSnapshot(matching: originalID)
        let originalWasRunning = original?.state == .running
        let expectedImageIdentities = try await resolvedImageIdentities(for: replacement.image, pinnedReference: replacementReference)
        // Resolve rollback before teardown too; a moving tag must not turn restoration into an update.
        let rollbackImageIdentities = try await resolvedImageIdentities(for: rollback.image, pinnedReference: rollbackReference)
        try Task.checkCancellation()
        let stoppedOriginal = (try? await stop([originalID])) != nil
        let deletedOriginal: Bool
        do {
            deletedOriginal = try await deleteContainerIfPresent(originalID, force: true)
        } catch {
            let deletionError = error
            if originalWasRunning, stoppedOriginal {
                do {
                    _ = try await start([originalID])
                    try await verifyReplacement(id: originalID,
                                                expectedImageIdentities: rollbackImageIdentities,
                                                requiredState: .running)
                } catch {
                    throw Core.Container.RecreateFailure(phase: .deleteOriginal,
                                                         recovery: .restoreFailed,
                                                         primaryError: deletionError,
                                                         recoveryError: error)
                }
                throw Core.Container.RecreateFailure(phase: .deleteOriginal,
                                                     recovery: .originalRestored,
                                                     primaryError: deletionError)
            }
            throw Core.Container.RecreateFailure(phase: .deleteOriginal,
                                                 recovery: .notNeeded,
                                                 primaryError: deletionError)
        }

        var createdReplacementID: String?
        do {
            let result = try await createContainer(replacement, start: true)
            createdReplacementID = result.id ?? replacement.name
            try await verifyReplacement(id: createdReplacementID,
                                        expectedImageIdentities: expectedImageIdentities,
                                        requiredState: originalWasRunning ? .running : nil)
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
                let restored = try await createContainer(rollback, start: originalWasRunning)
                try await verifyReplacement(id: restored.id ?? rollback.name,
                                            expectedImageIdentities: rollbackImageIdentities,
                                            requiredState: originalWasRunning ? .running : .stopped)
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

    private func resolvedImageIdentities(for reference: String, pinnedReference: String? = nil) async throws -> Set<String>? {
        guard let imageClient = self as? any RuntimeImageClient else { return nil }
        let images = try await imageClient.inspectImage(reference)
        let identities = images.reduce(into: Set<String>()) { result, image in
            result.insert(Self.normalizedImageIdentity(image.id))
            if let digest = image.digest {
                result.insert(Self.normalizedImageIdentity(digest))
            }
        }
        let pinned = Core.Registry.ImageReference.parse(pinnedReference ?? reference)
        if pinned.isDigestReference {
            let expected = Self.normalizedImageIdentity(pinned.reference)
            guard identities.contains(expected) else {
                throw RecreateVerificationError.imageMismatch(expected: [expected], actual: images.first?.digest)
            }
            return [expected]
        }
        return identities.isEmpty ? nil : identities
    }

    private func verifyReplacement(id: String?,
                                   expectedImageIdentities: Set<String>?,
                                   requiredState: Core.Runtime.Status?) async throws {
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
        if requiredState == .running, replacement.state != .running {
            throw RecreateVerificationError.replacementNotRunning(id: id, state: replacement.rawState)
        }
        if requiredState == .stopped, replacement.state != .stopped {
            throw RecreateVerificationError.replacementNotStopped(id: id, state: replacement.rawState)
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
    case recoveryNameInUse
    case replacementUnavailable(id: String)
    case replacementNotRunning(id: String, state: String)
    case replacementNotStopped(id: String, state: String)
    case imageMismatch(expected: [String], actual: String?)

    var packageName: String { "ContainedCore" }

    var packageErrorCode: String {
        switch self {
        case .recoveryNameInUse: "recreateRecoveryNameInUse"
        case .replacementUnavailable: "recreateReplacementUnavailable"
        case .replacementNotRunning: "recreateReplacementNotRunning"
        case .replacementNotStopped: "recreateReplacementNotStopped"
        case .imageMismatch: "recreateImageMismatch"
        }
    }

    var packageErrorContext: [String: String] { [:] }

    var errorDescription: String? {
        switch self {
        case .recoveryNameInUse:
            "Recovery requires a missing container name. An existing container will not be replaced or deleted."
        case .replacementUnavailable(let id):
            "Replacement container \(id) was not available after creation."
        case .replacementNotRunning(let id, let state):
            "Replacement container \(id) entered state \(state) during startup verification."
        case .replacementNotStopped(let id, let state):
            "Restored container \(id) entered state \(state) instead of remaining stopped."
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
