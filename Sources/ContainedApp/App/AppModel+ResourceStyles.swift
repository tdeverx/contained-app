import Foundation
import ContainedCore

extension AppModel {
    func localImageGroups() -> [Core.Image.LocalTagGroup] {
        if let imageGroupsCache {
            return imageGroupsCache
        }
        let groups = Core.Image.LocalTagGroup.groups(for: images)
        imageGroupsCache = groups
        return groups
    }

    var defaultImageStyle: Personalization {
        settings.imageDefaultStyleEnabled ? personalization.defaultImageStyle : Personalization()
    }

    func imageStyle(for reference: String) -> Personalization {
        personalization.imageDefault(for: reference, group: localImageGroup(containing: reference)) ?? defaultImageStyle
    }

    func imageGroupStyle(for group: Core.Image.LocalTagGroup) -> Personalization {
        personalization.imageGroupDefault(for: group) ?? defaultImageStyle
    }

    /// The group's style by id, used where only the id is known, such as a tag resolving its parent.
    func imageGroupStyle(forID id: String) -> Personalization {
        if let group = localImageGroup(id: id) {
            return personalization.imageGroupDefault(for: group) ?? defaultImageStyle
        }
        return personalization.imageGroupDefault(forLegacyID: id) ?? defaultImageStyle
    }

    func volumeStyle(for name: String) -> Personalization {
        var style = personalization.volumeStyle(for: name) ?? Personalization()
        style.normalizeVolumeWidgets()
        return style
    }

    func containerStyle(for snapshot: Core.Container.Snapshot) -> Personalization {
        return personalization.resolved(id: snapshot.scopedID,
                                        image: snapshot.image,
                                        group: localImageGroup(containing: snapshot.image),
                                        fallback: defaultImageStyle)
    }

    /// Containers that mount the named volume. Used by volume cards to aggregate I/O activity.
    func containersMounting(volume name: String) -> [Core.Container.Snapshot] {
        containers.snapshots.filter { snapshot in
            snapshot.configuration.mounts.contains { $0.source == name }
        }
    }

    /// Current block read/write rate for a volume, summed across every container mounting it.
    func volumeIORate(for name: String, metric: Core.Metrics.GraphMetric) -> Double {
        containersMounting(volume: name).reduce(0) { total, snapshot in
            total + (containers.metricsState(for: snapshot.scopedID).stats.map {
                metric.value(from: $0, snapshot: snapshot, normalization: statsNormalizationContext)
            } ?? 0)
        }
    }

    /// Read/write sparkline series for a volume. Series are right-aligned so recent samples line up.
    func volumeIOHistory(for name: String, metric: Core.Metrics.GraphMetric) -> [Double] {
        let series = containersMounting(volume: name).compactMap { snapshot in
            containers.metricsState(for: snapshot.scopedID).historyByMetric[metric]?.values
        }
        return Self.sumRightAligned(series)
    }

    private static func sumRightAligned(_ series: [[Double]]) -> [Double] {
        let maxLen = series.map(\.count).max() ?? 0
        guard maxLen > 0 else { return [] }
        var result = [Double](repeating: 0, count: maxLen)
        for samples in series {
            let offset = maxLen - samples.count
            for (index, value) in samples.enumerated() {
                result[offset + index] += value
            }
        }
        return result
    }

    func localImageGroup(id: String) -> Core.Image.LocalTagGroup? {
        localImageGroups().first { $0.id == id }
    }

    func localImageGroup(containing reference: String) -> Core.Image.LocalTagGroup? {
        let referenceKey = Core.Registry.ImageReference.normalizedKey(reference)
        if let cached = imageGroupIDByReferenceCache[referenceKey] {
            return localImageGroup(id: cached)
        }

        for group in localImageGroups() {
            for groupReference in group.references {
                imageGroupIDByReferenceCache[Core.Registry.ImageReference.normalizedKey(groupReference)] = group.id
            }
        }
        return imageGroupIDByReferenceCache[referenceKey].flatMap(localImageGroup(id:))
    }
}
