import Foundation
import ContainedCore
import Observation

struct ContainerGridProjection: Equatable, Sendable {
    struct Input: Equatable, Sendable {
        let snapshots: [Core.Container.Snapshot]
        let sort: ContainerSort
        let runningOnly: Bool
        let search: String
    }

    let containers: [Core.Container.Snapshot]
    var visibleCount: Int { containers.count }

    static let empty = ContainerGridProjection(containers: [])

    static func build(_ input: Input) -> ContainerGridProjection {
        let query = input.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = input.snapshots.filter { snapshot in
            (!input.runningOnly || snapshot.state == .running) &&
                (query.isEmpty || snapshot.displayName.localizedCaseInsensitiveContains(query) ||
                    snapshot.image.localizedCaseInsensitiveContains(query))
        }
        return ContainerGridProjection(containers: sorted(filtered, by: input.sort))
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
