import Testing
import Foundation
import ContainedCore
import ContainedUI
@testable import ContainedApp

@Suite("Container grid projection")
struct ContainerGridProjectionTests {
    @Test func stableColumnsDependOnlyOnViewportWidth() {
        #expect(UI.Card.Grid.stableColumns(availableWidth: 1_600, spacing: 16).count == 5)
        #expect(UI.Card.Grid.stableColumns(availableWidth: 1_200, spacing: 16).count == 3)
        #expect(UI.Card.Grid.stableColumns(availableWidth: 1_000, spacing: 16).count == 3)
        #expect(UI.Card.Grid.stableColumns(availableWidth: 600, spacing: 16).count == 1)
    }

    @Test func projectionFiltersAndSortsWithStableIdentity() {
        let snapshots = [
            Self.snapshot(id: "worker", image: "example/worker:latest"),
            Self.snapshot(id: "api", image: "example/api:latest"),
        ]
        let input = ContainerGridProjection.Input(snapshots: snapshots,
                                                  sort: .name,
                                                  runningOnly: false, search: "")

        let first = ContainerGridProjection.build(input)
        let second = ContainerGridProjection.build(input)

        #expect(first == second)
        #expect(first.containers.map { $0.id } == ["api", "worker"])
        #expect(first.visibleCount == 2)

        let filtered = ContainerGridProjection.build(.init(snapshots: snapshots,
                                                           sort: .name,
                                                           runningOnly: false, search: "worker"))
        #expect(filtered.containers.map { $0.id } == ["worker"])
        #expect(filtered.visibleCount == 1)
    }

    @Test @MainActor func unchangedLargeInputDoesNotRebuildProjection() async {
        let snapshots = (0..<500).map { Self.snapshot(id: "container-\($0)", image: "example/app:latest") }
        let input = ContainerGridProjection.Input(snapshots: snapshots,
                                                  sort: .name,
                                                  runningOnly: false, search: "")
        let state = ContainerGridProjectionState()

        await state.update(input)
        await state.update(input)

        #expect(state.buildCount == 1)
        #expect(state.projection.visibleCount == 500)
    }

    @Test @MainActor func onlyNewestProjectionGenerationPublishes() async {
        let state = ContainerGridProjectionState()
        let first = ContainerGridProjection.Input(
            snapshots: (0..<500).map { Self.snapshot(id: "old-\($0)", image: "example/old:latest") },
            sort: .name, runningOnly: false, search: ""
        )
        let newest = ContainerGridProjection.Input(
            snapshots: [Self.snapshot(id: "newest", image: "example/new:latest")],
            sort: .name, runningOnly: false, search: ""
        )

        let obsolete = Task { await state.update(first) }
        await Task.yield()
        await state.update(newest)
        await obsolete.value

        #expect(state.projection.containers.map(\.id) == ["newest"])
    }

    @Test func richSortOptionsUseStableInventoryAndDerivedValues() {
        let apple = Self.snapshot(id: "apple", image: "example/z:latest", state: .running)
        let docker = Self.snapshot(id: "docker", image: "example/a:latest", state: .stopped,
                                   runtimeKind: .docker)
        let worker = Self.snapshot(id: "worker", image: "example/m:latest", state: .stopping)
        let snapshots = [apple, docker, worker]
        let values: [String: ContainerGridProjection.SortValues] = [
            apple.scopedID: .init(displayName: "Zebra", creationDate: Date(timeIntervalSince1970: 10),
                                  startedDate: Date(timeIntervalSince1970: 20),
                                  cpuCoreFraction: 0.25, memoryFraction: 0.9),
            docker.scopedID: .init(displayName: "Alpha", creationDate: Date(timeIntervalSince1970: 30),
                                   imageUpdate: .updateAvailable,
                                   cpuCoreFraction: 0.8, memoryFraction: 0.2),
            worker.scopedID: .init(displayName: "Middle", creationDate: Date(timeIntervalSince1970: 20),
                                   startedDate: Date(timeIntervalSince1970: 40), health: .unhealthy,
                                   cpuCoreFraction: 0.5, memoryFraction: 0.5),
        ]

        func ids(sortedBy sort: ContainerSort) -> [String] {
            ContainerGridProjection.build(.init(snapshots: snapshots, sort: sort,
                                                runningOnly: false, search: "",
                                                sortValuesByID: values)).containers.map(\.id)
        }

        #expect(ids(sortedBy: .name) == ["docker", "worker", "apple"])
        #expect(ids(sortedBy: .status) == ["worker", "docker", "apple"])
        #expect(ids(sortedBy: .created) == ["docker", "worker", "apple"])
        #expect(ids(sortedBy: .uptime) == ["apple", "worker", "docker"])
        #expect(ids(sortedBy: .image) == ["docker", "worker", "apple"])
        #expect(ids(sortedBy: .runtime) == ["worker", "apple", "docker"])
        #expect(ids(sortedBy: .cpu) == ["docker", "worker", "apple"])
        #expect(ids(sortedBy: .memory) == ["apple", "worker", "docker"])
        #expect(ids(sortedBy: .attention) == ["worker", "docker", "apple"])
    }

    @Test func nicknameParticipatesInSearchWithoutHidingTheRuntimeID() {
        let snapshot = Self.snapshot(id: "api", image: "example/api:latest")
        let values = [snapshot.scopedID: ContainerGridProjection.SortValues(displayName: "Gateway")]

        let nicknameMatch = ContainerGridProjection.build(.init(snapshots: [snapshot], sort: .name,
                                                                 runningOnly: false, search: "gate",
                                                                 sortValuesByID: values))
        let idMatch = ContainerGridProjection.build(.init(snapshots: [snapshot], sort: .name,
                                                           runningOnly: false, search: "api",
                                                           sortValuesByID: values))

        #expect(nicknameMatch.containers.map(\.id) == ["api"])
        #expect(idMatch.containers.map(\.id) == ["api"])
    }

    private static func snapshot(id: String,
                                 image: String,
                                 state: Core.Runtime.Status = .running,
                                 runtimeKind: Core.Runtime.Kind = .appleContainer) -> Core.Container.Snapshot {
        .placeholder(id: id, image: image, state: state, runtimeKind: runtimeKind)
    }
}
