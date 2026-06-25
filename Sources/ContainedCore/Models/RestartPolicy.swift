import Foundation

/// App-managed restart policy (the CLI has no native `--restart`); persisted as the
/// `contained.restart` label so it round-trips through the runtime.
public enum RestartPolicy: String, CaseIterable, Identifiable, Codable, Sendable {
    case no, onFailure = "on-failure", always
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .no: return "No"
        case .onFailure: return "On failure"
        case .always: return "Always"
        }
    }

    /// Parse a label value into a policy (`nil`/unknown → `.no`).
    public init(label: String?) {
        self = label.flatMap(RestartPolicy.init(rawValue:)) ?? .no
    }
}

/// Pure decision logic for the app-managed `RestartWatchdog`, factored out so it is unit-testable
/// without a live daemon. The watchdog calls this for every container that transitions
/// `running → stopped` on a refresh tick.
public enum RestartDecision {
    /// Should the watchdog restart a container that just stopped?
    ///
    /// - Parameters:
    ///   - policy: the container's resolved restart policy.
    ///   - userInitiated: true when the app itself just stopped/removed the container (so we don't
    ///     fight a deliberate user action).
    ///   - exitCode: the process exit code if known. The `list --format json` snapshot does **not**
    ///     carry an exit code, so this is usually `nil`; an unknown exit is treated as a failure
    ///     (only a *known* clean `0` exit suppresses an `on-failure` restart).
    public static func shouldRestart(policy: RestartPolicy, userInitiated: Bool, exitCode: Int32? = nil) -> Bool {
        guard !userInitiated else { return false }
        switch policy {
        case .no: return false
        case .always: return true
        case .onFailure:
            if let exitCode { return exitCode != 0 }
            return true
        }
    }

    /// Exponential backoff (seconds) for the Nth retry (0-based), capped. Used to space restart
    /// attempts so a crash-looping container doesn't spin.
    public static func backoff(attempt: Int, base: TimeInterval = 2, cap: TimeInterval = 60) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let raw = base * pow(2, Double(attempt - 1))
        return min(raw, cap)
    }
}
