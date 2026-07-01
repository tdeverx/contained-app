import Foundation
import ContainedCore

extension AppModel {
    var defaultImageStyle: Personalization {
        settings.imageDefaultStyleEnabled ? personalization.defaultImageStyle : Personalization()
    }

    func imageStyle(for reference: String) -> Personalization {
        let groupID = LocalImageTagGroup.groups(for: images).first { group in
            group.references.contains(reference)
        }?.id
        return personalization.imageDefault(for: reference, groupID: groupID) ?? defaultImageStyle
    }

    func imageGroupStyle(for group: LocalImageTagGroup) -> Personalization {
        personalization.imageGroupDefault(for: group.id) ?? defaultImageStyle
    }

    /// The group's style by id, used where only the id is known, such as a tag resolving its parent.
    func imageGroupStyle(forID id: String) -> Personalization {
        personalization.imageGroupDefault(for: id) ?? defaultImageStyle
    }

    func volumeStyle(for name: String) -> Personalization {
        var style = personalization.volumeStyle(for: name) ?? Personalization()
        style.normalizeVolumeWidgets()
        return style
    }

    func containerStyle(for snapshot: ContainerSnapshot) -> Personalization {
        let groupID = LocalImageTagGroup.groups(for: images).first { group in
            group.references.contains(snapshot.image)
        }?.id
        return personalization.resolved(id: snapshot.id,
                                        image: snapshot.image,
                                        groupID: groupID,
                                        fallback: defaultImageStyle)
    }

    /// Containers that mount the named volume. Used by volume cards to aggregate I/O activity.
    func containersMounting(volume name: String) -> [ContainerSnapshot] {
        containers.snapshots.filter { snapshot in
            snapshot.configuration.mounts.contains { $0.source == name }
        }
    }

    /// Current block read/write rate for a volume, summed across every container mounting it.
    func volumeIORate(for name: String, metric: GraphMetric) -> Double {
        containersMounting(volume: name).reduce(0) { total, snapshot in
            total + (containers.statsByID[snapshot.id].map { metric.value(from: $0) } ?? 0)
        }
    }

    /// Read/write sparkline series for a volume. Series are right-aligned so recent samples line up.
    func volumeIOHistory(for name: String, metric: GraphMetric) -> [Double] {
        let series = containersMounting(volume: name).compactMap {
            containers.historyByID[$0.id]?[metric]?.values
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
}
