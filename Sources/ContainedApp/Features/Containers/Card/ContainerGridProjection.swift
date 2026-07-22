import Foundation
import ContainedCore
import Observation

struct ContainerGridProjection: Equatable, Sendable {
    struct Input: Equatable, Sendable {
        let snapshots: [Core.Container.Snapshot]
        let networks: [Core.Network.Resource]
        let grouping: ContainerGrouping
        let sort: ContainerSort
        let runningOnly: Bool
        let search: String
    }

    struct Group: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let symbol: String
        let resource: Core.Network.Resource?
        let containers: [Core.Container.Snapshot]
        let isBuiltin: Bool
    }

    let groups: [Group]
    let visibleCount: Int

    static let empty = ContainerGridProjection(groups: [], visibleCount: 0)

    static func build(_ input: Input) -> ContainerGridProjection {
        let query = input.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = input.snapshots.filter { snapshot in
            (!input.runningOnly || snapshot.state == .running) &&
                (query.isEmpty || snapshot.displayName.localizedCaseInsensitiveContains(query) ||
                    snapshot.image.localizedCaseInsensitiveContains(query))
        }

        let groups: [Group]
        switch input.grouping {
        case .network:
            groups = networkGroups(filtered: filtered, input: input)
        case .volume:
            groups = volumeGroups(filtered: filtered, sort: input.sort)
        case .image:
            groups = imageGroups(filtered: filtered, sort: input.sort)
        case .flat:
            groups = [Group(id: "flat:all",
                            name: "All containers",
                            symbol: "square.grid.2x2",
                            resource: nil,
                            containers: sorted(filtered, by: input.sort),
                            isBuiltin: false)]
        }
        return ContainerGridProjection(groups: groups, visibleCount: filtered.count)
    }

    private static func networkGroups(filtered: [Core.Container.Snapshot],
                                      input: Input) -> [Group] {
        let byNetworkName = Dictionary(input.networks.map { ($0.name, $0) },
                                       uniquingKeysWith: { first, _ in first })
        let defaultName = input.networks.first { $0.isBuiltin }?.name ?? "default"
        var buckets: [String: [Core.Container.Snapshot]] = [:]
        for network in input.networks { buckets[network.name] = [] }
        buckets[defaultName, default: []] = buckets[defaultName] ?? []

        for snapshot in filtered {
            let requested = snapshot.configuration.networks.map(\.network)
            let observed = snapshot.status.networks.map(\.network)
            let names = Array(Set(requested + observed)).sorted()
            if names.isEmpty {
                buckets[defaultName, default: []].append(snapshot)
            } else {
                for name in names { buckets[name, default: []].append(snapshot) }
            }
        }

        return buckets.keys.sorted { lhs, rhs in
            if lhs == defaultName { return true }
            if rhs == defaultName { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { name in
            Group(id: "network:\(name)",
                  name: name,
                  symbol: "network",
                  resource: byNetworkName[name],
                  containers: sorted(buckets[name] ?? [], by: input.sort),
                  isBuiltin: byNetworkName[name]?.isBuiltin ?? true)
        }
    }

    private static func volumeGroups(filtered: [Core.Container.Snapshot],
                                     sort: ContainerSort) -> [Group] {
        let noVolume = "No volume"
        var buckets: [String: [Core.Container.Snapshot]] = [:]
        for snapshot in filtered {
            let volumes = Set(snapshot.configuration.mounts.compactMap { mount -> String? in
                guard let source = mount.source, !source.isEmpty else { return nil }
                return source
            })
            if volumes.isEmpty {
                buckets[noVolume, default: []].append(snapshot)
            } else {
                for volume in volumes { buckets[volume, default: []].append(snapshot) }
            }
        }
        return buckets.keys.sorted { lhs, rhs in
            if lhs == noVolume { return false }
            if rhs == noVolume { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { name in
            Group(id: "volume:\(name)", name: name, symbol: "externaldrive", resource: nil,
                  containers: sorted(buckets[name] ?? [], by: sort), isBuiltin: false)
        }
    }

    private static func imageGroups(filtered: [Core.Container.Snapshot],
                                    sort: ContainerSort) -> [Group] {
        var buckets: [String: [Core.Container.Snapshot]] = [:]
        for snapshot in filtered {
            buckets[Format.shortImage(snapshot.image), default: []].append(snapshot)
        }
        return buckets.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { name in
                Group(id: "image:\(name)", name: name, symbol: "shippingbox", resource: nil,
                      containers: sorted(buckets[name] ?? [], by: sort), isBuiltin: false)
            }
    }

    private static func sorted(_ containers: [Core.Container.Snapshot],
                               by sort: ContainerSort) -> [Core.Container.Snapshot] {
        switch sort {
        case .name:
            return containers.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        case .status:
            return containers.sorted { lhs, rhs in
                let lhsRunning = lhs.state == .running
                let rhsRunning = rhs.state == .running
                if lhsRunning != rhsRunning { return lhsRunning }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        case .image:
            return containers.sorted { lhs, rhs in
                let comparison = lhs.image.localizedCaseInsensitiveCompare(rhs.image)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
    }
}

@MainActor
@Observable
final class ContainerGridProjectionState {
    private(set) var projection = ContainerGridProjection.empty
    private(set) var buildCount = 0
    @ObservationIgnored private var publishedInput: ContainerGridProjection.Input?
    @ObservationIgnored private var generation = 0

    func update(_ input: ContainerGridProjection.Input) async {
        guard input != publishedInput else { return }
        generation &+= 1
        let requestedGeneration = generation
        buildCount &+= 1
        let interval = PerformanceSignposts.grid.beginInterval("GridProjection")
        defer { PerformanceSignposts.grid.endInterval("GridProjection", interval) }
        let next = await Task.detached(priority: .utility) {
            ContainerGridProjection.build(input)
        }.value
        guard !Task.isCancelled, requestedGeneration == generation else { return }
        publishedInput = input
        if next != projection { projection = next }
    }
}
