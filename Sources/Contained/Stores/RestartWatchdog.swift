import Foundation
import ContainedCore
import ContainedRuntime

/// App-managed restart policy. The `container` CLI has no native `--restart`, so on each refresh
/// tick we diff container states and re-issue `start` for containers that crashed (transitioned
/// `running → stopped`) and carry a `contained.restart` label of `always`/`on-failure`.
///
/// Opt-in by definition: a container only participates if it was created with a restart policy.
/// User-initiated stops are suppressed (the store flags them), restarts use exponential backoff,
/// and attempts are capped so a crash-looping container can't spin. Runs only while the app is
/// open — it is not a daemon.
@MainActor
final class RestartWatchdog {
    /// Called when the watchdog issues a restart (snapshot, attempt number).
    var onRestart: ((ContainerSnapshot, Int) -> Void)?
    /// Called when a container exits unexpectedly with no restart policy (for an informational note).
    var onUnexpectedExit: ((ContainerSnapshot) -> Void)?

    private let maxRetries = 5
    private var lastState: [String: RuntimeStatus] = [:]
    private var attempts: [String: Int] = [:]
    private var nextEligible: [String: Date] = [:]

    /// Evaluate the latest snapshots against the previous tick and act on crashes.
    func evaluate(snapshots: [ContainerSnapshot],
                  store: ContainersStore,
                  client: any ContainerRuntimeClient,
                  now: Date = Date()) async {
        var restarts: [(ContainerSnapshot, Int)] = []

        for snapshot in snapshots {
            let id = snapshot.id
            let current = snapshot.state
            defer { lastState[id] = current }

            // Reset retry budget once a container is healthy again.
            if current == .running { attempts[id] = 0; nextEligible[id] = nil }

            let was = lastState[id]
            let crashedNow = (was == .running || was == .stopping) && current == .stopped
            guard crashedNow else { continue }

            let userInitiated = store.consumeIntentionalStop(id)
            let policy = RestartPolicy(label: snapshot.configuration.labels["contained.restart"])

            guard RestartDecision.shouldRestart(policy: policy, userInitiated: userInitiated) else {
                // An unexpected exit we won't act on — surface it once (informational).
                if !userInitiated && policy == .no { onUnexpectedExit?(snapshot) }
                continue
            }

            let attempt = attempts[id] ?? 0
            guard attempt < maxRetries else { continue }              // gave up — stay stopped
            if let eligible = nextEligible[id], eligible > now { continue }   // backing off

            attempts[id] = attempt + 1
            nextEligible[id] = now.addingTimeInterval(RestartDecision.backoff(attempt: attempt + 1))
            restarts.append((snapshot, attempt + 1))
        }

        for (snapshot, attempt) in restarts {
            onRestart?(snapshot, attempt)
            _ = try? await client.start([snapshot.id])
        }
    }

    /// Forget all tracked state (e.g. when the service restarts).
    func reset() {
        lastState.removeAll(); attempts.removeAll(); nextEligible.removeAll()
    }
}
