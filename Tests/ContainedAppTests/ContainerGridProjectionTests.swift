import Testing
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

    private static func snapshot(id: String,
                                 image: String,
                                 runtimeKind: Core.Runtime.Kind = .appleContainer) -> Core.Container.Snapshot {
        .placeholder(id: id, image: image, runtimeKind: runtimeKind)
    }
}
