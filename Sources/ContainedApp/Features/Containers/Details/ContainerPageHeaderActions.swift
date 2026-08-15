import ContainedUI
import Observation

enum ContainerPageHeaderActionOwner: Hashable {
    case logs
    case terminal
    case files
}

/// Page-owned commands rendered by the expanded container card's shared header. Ownership keeps a
/// disappearing page from clearing the next page's actions during a tab transition.
@MainActor
@Observable
final class ContainerPageHeaderActions {
    private(set) var items: [UI.Action.Item] = []
    @ObservationIgnored private var owner: ContainerPageHeaderActionOwner?

    func replace(for owner: ContainerPageHeaderActionOwner, with items: [UI.Action.Item]) {
        self.owner = owner
        self.items = items
    }

    func clear(for owner: ContainerPageHeaderActionOwner? = nil) {
        guard owner == nil || self.owner == owner else { return }
        self.owner = nil
        items = []
    }
}
