import SwiftUI
import ContainedCore

private enum ImageUpdateSummaryScope {
    case localImages
    case containerImages

    var noun: String {
        switch self {
        case .localImages: AppText.imageUpdateImageNoun
        case .containerImages: AppText.imageUpdateContainerImageNoun
        }
    }

    var pluralTitle: String {
        switch self {
        case .localImages: AppText.imageUpdateImagesTitle
        case .containerImages: AppText.imageUpdateContainerImagesTitle
        }
    }
}

/// Image-update tracking: comparing the local digest of each image against the registry's current
/// manifest digest, on a throttled background sweep and on demand. Split out of `AppModel` because it
/// is a self-contained subsystem with its own persisted state (`imageUpdates`, `lastImageUpdateSweep`,
/// declared on the main type since stored properties can't live in an extension).
///
/// "Image updates" cover every local image; "container image updates" narrow the same machinery to
/// just the images that running/stopped containers were created from.
extension AppModel {

    // MARK: Status lookup

    /// The tracked update status for an image reference (defaults to an empty/unknown status).
    func imageUpdateStatus(for reference: String) -> Core.Image.UpdateStatus {
        let runtimeStatuses = localRuntimeTargets(for: reference).compactMap {
            imageUpdates[imageUpdateKey(reference, runtimeKind: $0)]
        }
        guard !runtimeStatuses.isEmpty else {
            return imageUpdates[imageUpdateKey(reference)] ?? Core.Image.UpdateStatus()
        }
        return aggregateUpdateStatus(runtimeStatuses)
    }

    /// The tracked update status for a local tag in one runtime.
    func imageUpdateStatus(for reference: String,
                           runtimeKind: Core.Runtime.Kind) -> Core.Image.UpdateStatus {
        imageUpdates[imageUpdateKey(reference, runtimeKind: runtimeKind)]
            ?? imageUpdates[imageUpdateKey(reference)]
            ?? Core.Image.UpdateStatus()
    }

    /// Combine registry state with the immutable image identity captured when a container was
    /// created. A successful pull makes the registry status current, but leaves the old container
    /// pointing at its previous identity until it is recreated.
    func containerImageUpdateState(for snapshot: Core.Container.Snapshot) -> Core.Image.ContainerUpdateState {
        let referenceKey = imageUpdateKey(snapshot.image)
        let localImage = images.first {
            $0.runtimeKind == snapshot.runtimeKind && imageUpdateKey($0.reference) == referenceKey
        }
        let localIdentities = [localImage?.id, localImage?.digest]
            .compactMap { $0 }
        return Core.Image.ContainerUpdateState.resolve(
            containerIdentity: snapshot.configuration.image.descriptor?.digest,
            localIdentities: localIdentities,
            trackedStatus: imageUpdateStatus(for: snapshot.image, runtimeKind: snapshot.runtimeKind)
        )
    }

    /// The normalized dictionary key for a reference, so `nginx` and `docker.io/library/nginx:latest`
    /// map to the same tracked status.
    func imageUpdateKey(_ reference: String) -> String {
        Core.Registry.ImageReference.normalizedKey(reference)
    }

    func imageUpdateKey(_ reference: String,
                        runtimeKind: Core.Runtime.Kind) -> String {
        runtimeKind.scopedID(for: imageUpdateKey(reference))
    }

    // MARK: Sweeps

    /// Check every local image against its registry. `manual` adds a summary banner (the silent
    /// background sweep stays quiet).
    func checkAllImageUpdates(manual: Bool = false) async {
        await runUpdateCheck(over: uniqueImageReferences(),
                             emptyMessage: AppText.noLocalImagesToCheck,
                             summary: .localImages,
                             manual: manual)
        lastImageUpdateSweep = Date()
    }

    /// Re-run the full sweep immediately with banners (the Settings "Check now" action).
    func runImageUpdateSweepNow() async {
        await checkAllImageUpdates(manual: true)
    }

    /// Check only the images that existing containers were created from.
    func checkContainerImageUpdates(manual: Bool = true) async {
        await runUpdateCheck(over: uniqueContainerImageReferences(),
                             emptyMessage: AppText.noContainerImagesToCheck,
                             summary: .containerImages,
                             manual: manual)
    }

    /// Pull every local image that has an update available. Returns the number pulled.
    @discardableResult
    func pullAvailableImageUpdates(manual: Bool = false) async -> Int {
        await pullUpdates(over: uniqueImageReferences(),
                          emptyMessage: AppText.noImageUpdatesAvailable,
                          summary: .localImages,
                          manual: manual)
    }

    /// Pull updates only for images backing existing containers. Returns the number pulled.
    @discardableResult
    func pullAvailableContainerImageUpdates(manual: Bool = true) async -> Int {
        await pullUpdates(over: uniqueContainerImageReferences(),
                          emptyMessage: AppText.noContainerImageUpdatesAvailable,
                          summary: .containerImages,
                          manual: manual)
    }

    // MARK: Single image

    /// Compare one image's local digest against the registry. `notify` controls per-image banners
    /// (off during bulk sweeps, which summarize once at the end).
    func checkImageUpdate(_ reference: String, notify: Bool = true) async {
        let runtimeKinds = localRuntimeTargets(for: reference)
        guard !runtimeKinds.isEmpty else {
            let key = imageUpdateKey(reference)
            imageUpdates[key] = .failed(localDigest: nil,
                                        message: AppText.string("updates.localDigestUnavailable.short", defaultValue: "Local digest unavailable"))
            if notify { flash(AppText.imageLocalDigestUnavailable(Format.shortImage(reference))) }
            return
        }
        await checkImageUpdate(reference, runtimeKinds: runtimeKinds, notify: notify)
    }

    /// Compare one runtime-owned local tag against the registry.
    func checkImageUpdate(_ reference: String,
                          runtimeKind: Core.Runtime.Kind,
                          notify: Bool = true) async {
        await checkImageUpdate(reference, runtimeKinds: [runtimeKind], notify: notify)
    }

    private func checkImageUpdate(_ reference: String,
                                  runtimeKinds: [Core.Runtime.Kind],
                                  notify: Bool) async {
        let runtimeKinds = Array(Set(runtimeKinds)).sorted { $0.rawValue < $1.rawValue }
        for runtimeKind in runtimeKinds {
            let key = imageUpdateKey(reference, runtimeKind: runtimeKind)
            imageUpdates[key] = .checking(localDigest: localDigest(for: reference, runtimeKind: runtimeKind))
        }
        do {
            let remoteDigest = try await manifestClient.remoteDigest(for: reference)
            var statuses: [Core.Image.UpdateStatus] = []
            for runtimeKind in runtimeKinds {
                let key = imageUpdateKey(reference, runtimeKind: runtimeKind)
                guard let localDigest = localDigest(for: reference, runtimeKind: runtimeKind),
                      !localDigest.isEmpty else {
                    let status = Core.Image.UpdateStatus.failed(
                        localDigest: nil,
                        message: AppText.string("updates.localDigestUnavailable.short", defaultValue: "Local digest unavailable")
                    )
                    imageUpdates[key] = status
                    statuses.append(status)
                    continue
                }
                let status = Core.Image.UpdateStatus.resolved(localDigest: localDigest, remoteDigest: remoteDigest)
                imageUpdates[key] = status
                statuses.append(status)
            }
            if notify {
                switch aggregateUpdateStatus(statuses).state {
                case .updateAvailable:
                    flash(AppText.imageUpdateAvailable(Format.shortImage(reference)))
                    logger.record("Image update available",
                                  category: .image,
                                  severity: .warning)
                case .current:
                    flash(AppText.imageUpToDate(Format.shortImage(reference)))
                default:
                    break
                }
            }
        } catch {
            let message = error.appDisplayMessage
            for runtimeKind in runtimeKinds {
                let key = imageUpdateKey(reference, runtimeKind: runtimeKind)
                imageUpdates[key] = .failed(localDigest: localDigest(for: reference, runtimeKind: runtimeKind), message: message)
            }
            if notify { flash(message) }
            logger.recordFailure("Failed checking image update",
                                 error: error,
                                 category: .image,
                                 severity: .error)
        }
    }

    /// Pull one image and re-check its status. Returns true on a successful pull.
    @discardableResult
    func pullImageUpdate(_ reference: String,
                         runtimeKind: Core.Runtime.Kind) async -> Bool {
        let ok = await pullImage(reference, runtimeKind: runtimeKind)
        if ok {
            await checkImageUpdate(reference, runtimeKind: runtimeKind, notify: false)
            flash(AppText.updatedImage(Format.shortImage(reference)))
            logger.record("Updated image", category: .image)
        }
        return ok
    }

    /// Recreate one container from the image currently behind its tag. If the registry check still
    /// reports a newer remote image, pull it first. Local presentation, health, linked-volume paths,
    /// rollback configuration, and the container's prior running/stopped state are preserved.
    @discardableResult
    func rebuildContainer(_ requestedSnapshot: Core.Container.Snapshot) async -> Bool {
        guard let snapshot = containers.snapshots.first(where: {
            $0.scopedID == requestedSnapshot.scopedID
        }) else {
            flash(AppText.recreateOriginalUnavailable)
            return false
        }

        let updateState = containerImageUpdateState(for: snapshot)
        if updateState.needsPull,
           !(await pullImageUpdate(snapshot.image, runtimeKind: snapshot.runtimeKind)) {
            return false
        }

        var spec = ContainerFormState(from: snapshot.configuration)
        spec.personalization = containerStyle(for: snapshot)
        spec.healthCheck = healthChecks.check(for: snapshot.scopedID) ?? Core.Container.HealthCheck()
        spec.applyLinkedVolumePaths(database.linkedVolumePaths(for: snapshot.scopedID))

        let shouldRemainStopped = snapshot.state != .running
        guard let replacementID = await recreateContainer(originalID: snapshot.scopedID, spec: spec) else {
            if shouldRemainStopped,
               containers.recreateFailure?.recovery == .originalRestored {
                await containers.stop(snapshot.scopedID)
            }
            return false
        }

        if shouldRemainStopped {
            await containers.stop(snapshot.runtimeKind.scopedID(for: replacementID))
        }
        if updateState.requiresUpdate {
            flash(AppText.updatedContainer(Format.shortImage(snapshot.image)))
        } else {
            flash(AppText.rebuiltContainer(containerStyle(for: snapshot).displayName(fallback: snapshot.id)))
        }
        return true
    }

    /// Background entry point (from `tick()`): run a silent sweep only when the throttle window has
    /// elapsed, loading the image list first if it hasn't been fetched yet.
    func checkImageUpdatesIfNeeded(now: Date = Date()) async {
        guard settings.imageUpdateChecksEnabled else { return }
        if let lastImageUpdateSweep, now.timeIntervalSince(lastImageUpdateSweep) < imageUpdateInterval { return }
        if images.isEmpty, let client {
            do {
                setImages(try await client.runtimeImages())
                imagesError = nil
            } catch let error as Core.Command.Error {
                imagesError = error.appDisplayMessage
                return
            } catch {
                imagesError = error.appDisplayMessage
                return
            }
        }
        guard !images.isEmpty else { return }
        await checkAllImageUpdates(manual: false)
    }

    // MARK: Bulk helpers

    /// Shared sweep body for `checkAllImageUpdates` / `checkContainerImageUpdates`: check each
    /// reference quietly, then (when `manual`) summarize how many have updates.
    private func runUpdateCheck(over references: [String], emptyMessage: String,
                                summary: ImageUpdateSummaryScope, manual: Bool) async {
        let started = Date()
        defer {
            let elapsed = Date().timeIntervalSince(started)
            if elapsed >= 0.75 || manual {
                let mode = manual ? "manual" : "background"
                diagnosticLogger.log(level: elapsed >= 1.5 ? .default : .info,
                                     "Image update sweep \(mode, privacy: .public) finished in \(elapsed.formatted(.number.precision(.fractionLength(2))), privacy: .public)s across \(references.count, privacy: .public) \(summary.noun, privacy: .public)(s)")
            }
        }
        guard !references.isEmpty else {
            if manual { flash(emptyMessage) }
            return
        }
        for reference in references { await checkImageUpdate(reference, notify: false) }
        guard manual else { return }
        let available = references.filter { imageUpdateStatus(for: $0).state == .updateAvailable }.count
        flash(AppText.updateSweepResult(available: available,
                                        singular: summary.noun,
                                        pluralTitle: summary.pluralTitle))
    }

    /// Shared pull body for `pullAvailableImageUpdates` / `pullAvailableContainerImageUpdates`: pull
    /// every reference with an update available and report the count.
    private func pullUpdates(over references: [String], emptyMessage: String,
                             summary: ImageUpdateSummaryScope, manual: Bool) async -> Int {
        let pending: [(reference: String, runtimeKind: Core.Runtime.Kind)] = references.flatMap { reference in
            localRuntimeKinds(for: reference, summary: summary).compactMap { runtimeKind in
                imageUpdateStatus(for: reference, runtimeKind: runtimeKind).state == .updateAvailable
                    ? (reference, runtimeKind)
                    : nil
            }
        }
        guard !pending.isEmpty else {
            if manual { flash(emptyMessage) }
            return 0
        }
        var updated = 0
        for item in pending {
            if await pullImageUpdate(item.reference, runtimeKind: item.runtimeKind) {
                updated += 1
            }
        }
        if manual { flash(AppText.updatedItems(updated, singular: summary.noun)) }
        return updated
    }

    private func localRuntimeKinds(for reference: String,
                                   summary: ImageUpdateSummaryScope) -> [Core.Runtime.Kind] {
        let key = imageUpdateKey(reference)
        let runtimes: Set<Core.Runtime.Kind>
        switch summary {
        case .localImages:
            runtimes = Set(images.filter { imageUpdateKey($0.reference) == key }.map(\.runtimeKind))
        case .containerImages:
            runtimes = Set(containers.snapshots.filter { imageUpdateKey($0.image) == key }.map(\.runtimeKind))
        }
        let ordered = runtimes.sorted { $0.rawValue < $1.rawValue }
        return ordered
    }

    private func uniqueImageReferences() -> [String] {
        sortedUnique(images.map(\.reference))
    }

    private func uniqueContainerImageReferences() -> [String] {
        sortedUnique(containers.snapshots.map(\.image))
    }

    private func sortedUnique(_ references: [String]) -> [String] {
        Array(Set(references)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func localRuntimeTargets(for reference: String) -> [Core.Runtime.Kind] {
        Array(Set(localRuntimeKinds(for: reference, summary: .localImages) +
            localRuntimeKinds(for: reference, summary: .containerImages)))
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func localDigest(for reference: String,
                             runtimeKind: Core.Runtime.Kind) -> String? {
        let key = imageUpdateKey(reference)
        return images.first { $0.runtimeKind == runtimeKind && imageUpdateKey($0.reference) == key }?.digest
    }

    private func aggregateUpdateStatus(_ statuses: [Core.Image.UpdateStatus]) -> Core.Image.UpdateStatus {
        for state in [Core.Image.UpdateState.updateAvailable, .checking, .error, .current] {
            if let status = statuses.first(where: { $0.state == state }) { return status }
        }
        return Core.Image.UpdateStatus()
    }

}
