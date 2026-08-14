import Foundation
import ContainedCore
import Observation

struct ContainerGridProjection: Equatable, Sendable {
    struct SortValues: Equatable, Sendable {
        var displayName: String
        var creationDate: Date?
        var startedDate: Date?
        var health: Core.Container.HealthStatus
        var imageUpdate: Core.Image.ContainerUpdateState
        var cpuCoreFraction: Double?
        var memoryFraction: Double?

        init(displayName: String,
             creationDate: Date? = nil,
             startedDate: Date? = nil,
             health: Core.Container.HealthStatus = .unknown,
             imageUpdate: Core.Image.ContainerUpdateState = .unknown,
             cpuCoreFraction: Double? = nil,
             memoryFraction: Double? = nil) {
            self.displayName = displayName
            self.creationDate = creationDate
            self.startedDate = startedDate
            self.health = health
            self.imageUpdate = imageUpdate
            self.cpuCoreFraction = cpuCoreFraction
            self.memoryFraction = memoryFraction
        }
    }

    struct Input: Equatable, Sendable {
        let snapshots: [Core.Container.Snapshot]
        let sort: ContainerSort
        let runningOnly: Bool
        let search: String
        var sortValuesByID: [String: SortValues] = [:]
    }

    let containers: [Core.Container.Snapshot]
    var visibleCount: Int { containers.count }

    static let empty = ContainerGridProjection(containers: [])

    static func build(_ input: Input) -> ContainerGridProjection {
        let query = input.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = input.snapshots.filter { snapshot in
            let displayName = input.sortValuesByID[snapshot.scopedID]?.displayName ?? snapshot.displayName
            return (!input.runningOnly || snapshot.state == .running) &&
                (query.isEmpty || displayName.localizedCaseInsensitiveContains(query) ||
                    snapshot.displayName.localizedCaseInsensitiveContains(query) ||
                    snapshot.image.localizedCaseInsensitiveContains(query))
        }
        return ContainerGridProjection(containers: sorted(filtered, by: input.sort,
                                                          valuesByID: input.sortValuesByID))
    }

    private static func sorted(_ containers: [Core.Container.Snapshot],
                               by sort: ContainerSort,
                               valuesByID: [String: SortValues]) -> [Core.Container.Snapshot] {
        containers.sorted { lhs, rhs in
            let lhsValues = valuesByID[lhs.scopedID] ?? SortValues(displayName: lhs.displayName)
            let rhsValues = valuesByID[rhs.scopedID] ?? SortValues(displayName: rhs.displayName)
            let ordered: Bool?
            switch sort {
            case .name:
                ordered = compareText(lhsValues.displayName, rhsValues.displayName)
            case .status:
                ordered = compareAscending(statusRank(lhs, health: lhsValues.health),
                                           statusRank(rhs, health: rhsValues.health))
            case .created:
                ordered = compareDescending(lhsValues.creationDate, rhsValues.creationDate)
            case .uptime:
                ordered = compareAscending(lhsValues.startedDate, rhsValues.startedDate)
            case .image:
                ordered = compareText(lhs.image, rhs.image)
            case .runtime:
                ordered = compareText(lhs.runtimeKind.rawValue, rhs.runtimeKind.rawValue)
            case .cpu:
                ordered = compareDescending(lhsValues.cpuCoreFraction, rhsValues.cpuCoreFraction)
            case .memory:
                ordered = compareDescending(lhsValues.memoryFraction, rhsValues.memoryFraction)
            case .attention:
                ordered = compareAscending(attentionRank(lhs, values: lhsValues),
                                           attentionRank(rhs, values: rhsValues))
            }
            if let ordered { return ordered }
            if let byName = compareText(lhsValues.displayName, rhsValues.displayName) { return byName }
            return lhs.scopedID < rhs.scopedID
        }
    }

    private static func compareText(_ lhs: String, _ rhs: String) -> Bool? {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        return comparison == .orderedSame ? nil : comparison == .orderedAscending
    }

    private static func compareAscending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
        lhs == rhs ? nil : lhs < rhs
    }

    private static func compareAscending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return compareAscending(lhs, rhs)
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return nil
        }
    }

    private static func compareDescending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return lhs == rhs ? nil : lhs > rhs
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return nil
        }
    }

    private static func statusRank(_ snapshot: Core.Container.Snapshot,
                                   health: Core.Container.HealthStatus) -> Int {
        if health == .unhealthy { return 0 }
        switch snapshot.state {
        case .stopping: return 1
        case .unknown: return 2
        case .stopped: return 3
        case .running: return 4
        }
    }

    private static func attentionRank(_ snapshot: Core.Container.Snapshot,
                                      values: SortValues) -> Int {
        if values.health == .unhealthy { return 0 }
        if snapshot.state == .unknown { return 1 }
        if snapshot.state == .stopping { return 2 }
        if values.imageUpdate == .updateAvailable { return 3 }
        if values.imageUpdate == .updateReady { return 4 }
        if snapshot.state == .stopped { return 5 }
        return 6
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
