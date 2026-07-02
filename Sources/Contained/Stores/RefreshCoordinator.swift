import SwiftUI
import ContainedCore

/// Drives periodic refresh of the whole app. There is no push API from `container`, so a single
/// adaptive polling loop fetches system status, the container list, and active resource caches, then
/// runs the `RestartWatchdog`. Stats sampling is throttled separately by `ContainersStore` so the CLI
/// does not run `container stats --no-stream` on every tick. Cadence speeds up while containers are
/// transitioning, slows when idle, and pauses when the window is in the background.
@MainActor
@Observable
final class RefreshCoordinator {
    /// False when the window is backgrounded/inactive — pauses polling to save power.
    var isActive = true {
        didSet { if isActive && !oldValue { wake() } }
    }

    private weak var app: AppModel?
    private var loop: Task<Void, Never>?
    private var sleeper: Task<Void, Never>?

    func start(app: AppModel) {
        self.app = app
        guard loop == nil else { return }
        loop = Task { [weak self] in await self?.run() }
    }

    func stop() {
        loop?.cancel(); loop = nil
        sleeper?.cancel(); sleeper = nil
    }

    /// Force an immediate tick (e.g. when returning to the foreground or switching sections).
    func wake() { sleeper?.cancel() }

    private func run() async {
        while !Task.isCancelled {
            if isActive, let app {
                await app.tick()
            }
            let interval = nextInterval()
            // Interruptible sleep so wake() can cut it short.
            sleeper = Task { try? await Task.sleep(for: .seconds(interval)) }
            await sleeper?.value
        }
    }

    /// Adaptive cadence around the user's configured base interval.
    private func nextInterval() -> Double {
        guard let app else { return 2 }
        let base = app.settings.refreshInterval
        let snaps = app.containers.snapshots
        if snaps.contains(where: { $0.state == .stopping }) { return max(1, base * 0.5) } // transitioning → fast
        if app.containers.running.isEmpty { return min(8, base * 2.5) }                    // idle → slow
        return base
    }
}
