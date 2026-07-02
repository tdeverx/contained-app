import SwiftUI
import ContainedCore
import ContainedRuntime

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
    func imageUpdateStatus(for reference: String) -> ImageUpdateStatus {
        imageUpdates[imageUpdateKey(reference)] ?? ImageUpdateStatus()
    }

    /// The normalized dictionary key for a reference, so `nginx` and `docker.io/library/nginx:latest`
    /// map to the same tracked status.
    func imageUpdateKey(_ reference: String) -> String {
        RegistryImageReference.normalizedKey(reference)
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
        let key = imageUpdateKey(reference)
        let localDigest = localDigest(for: key)
        imageUpdates[key] = .checking(localDigest: localDigest)
        do {
            let remoteDigest = try await manifestClient.remoteDigest(for: reference)
            guard let localDigest, !localDigest.isEmpty else {
                imageUpdates[key] = .failed(localDigest: nil,
                                            message: AppText.string("updates.localDigestUnavailable.short", defaultValue: "Local digest unavailable"))
                if notify { flash(AppText.imageLocalDigestUnavailable(Format.shortImage(reference))) }
                return
            }
            let status = ImageUpdateStatus.resolved(localDigest: localDigest, remoteDigest: remoteDigest)
            imageUpdates[key] = status
            if notify {
                switch status.state {
                case .updateAvailable:
                    flash(AppText.imageUpdateAvailable(Format.shortImage(reference)))
                    logger.record("Update available for \(Format.shortImage(reference))",
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
            imageUpdates[key] = .failed(localDigest: localDigest, message: message)
            if notify { flash(message) }
            logger.recordFailure("Failed checking image update for \(Format.shortImage(reference))",
                                 error: error,
                                 category: .image,
                                 severity: .error)
        }
    }

    /// Pull one image and re-check its status. Returns true on a successful pull.
    @discardableResult
    func pullImageUpdate(_ reference: String) async -> Bool {
        let ok = await pullImage(reference)
        if ok {
            await checkImageUpdate(reference, notify: false)
            flash(AppText.updatedImage(Format.shortImage(reference)))
            logger.record("Updated \(Format.shortImage(reference))", category: .image)
        }
        return ok
    }

    /// Background entry point (from `tick()`): run a silent sweep only when the throttle window has
    /// elapsed, loading the image list first if it hasn't been fetched yet.
    func checkImageUpdatesIfNeeded(now: Date = Date()) async {
        guard settings.imageUpdateChecksEnabled else { return }
        if let lastImageUpdateSweep, now.timeIntervalSince(lastImageUpdateSweep) < imageUpdateInterval { return }
        if images.isEmpty, let client {
            do {
                images = try await client.images()
                imagesError = nil
            } catch let error as CommandError {
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
        let pending = references.filter { imageUpdateStatus(for: $0).state == .updateAvailable }
        guard !pending.isEmpty else {
            if manual { flash(emptyMessage) }
            return 0
        }
        var updated = 0
        for reference in pending where await pullImageUpdate(reference) { updated += 1 }
        if manual { flash(AppText.updatedItems(updated, singular: summary.noun)) }
        return updated
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

    private func localDigest(for key: String) -> String? {
        images.first { imageUpdateKey($0.reference) == key }?.digest
    }

    // MARK: Persistence

    static func loadImageUpdates(defaults: UserDefaults = .standard) -> [String: ImageUpdateStatus] {
        guard let data = defaults.data(forKey: imageUpdatesKey),
              let decoded = try? JSONDecoder().decode([String: ImageUpdateStatus].self, from: data) else {
            return [:]
        }
        // Never persist a transient "checking" state; restore it as unknown.
        return decoded.mapValues { $0.state == .checking ? ImageUpdateStatus() : $0 }
    }

    static func saveImageUpdates(_ updates: [String: ImageUpdateStatus], defaults: UserDefaults = .standard) {
        let stable = updates.mapValues { $0.state == .checking ? ImageUpdateStatus() : $0 }
        if let data = try? JSONEncoder().encode(stable) {
            defaults.set(data, forKey: imageUpdatesKey)
        }
    }

    static func loadLastImageUpdateSweep(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: imageUpdateLastSweepKey) as? Date
    }

    static func saveLastImageUpdateSweep(_ date: Date?, defaults: UserDefaults = .standard) {
        if let date {
            defaults.set(date, forKey: imageUpdateLastSweepKey)
        } else {
            defaults.removeObject(forKey: imageUpdateLastSweepKey)
        }
    }
}
