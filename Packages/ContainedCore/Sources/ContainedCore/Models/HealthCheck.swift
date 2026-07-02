import Foundation

/// An app-managed container healthcheck. The `container` CLI has no native healthcheck, so Contained
/// runs `exec` probes on an interval (same philosophy as the restart watchdog). Stored locally,
/// keyed by container id — never injected as labels.
public struct HealthCheck: Codable, Sendable, Hashable {
    /// The probe command run inside the container (argv). A zero exit = healthy.
    public var command: [String]
    public var intervalSeconds: Int
    public var retries: Int
    public var enabled: Bool

    public init(command: [String] = [], intervalSeconds: Int = 30, retries: Int = 3, enabled: Bool = false) {
        self.command = command
        self.intervalSeconds = intervalSeconds
        self.retries = retries
        self.enabled = enabled
    }

    /// True when there's a runnable probe configured.
    public var isActive: Bool { enabled && !command.isEmpty }
}

/// The observed health of a container under an app-managed check.
public enum HealthStatus: String, Sendable, Hashable {
    case unknown    // no check, or not yet probed
    case healthy
    case unhealthy
}

/// Pure decision logic for the health monitor — factored out (like `RestartDecision`) so the
/// failure-counting policy is unit-testable without spawning processes.
public enum HealthDecision {
    /// A container is unhealthy once consecutive probe failures reach the retry budget.
    public static func status(consecutiveFailures: Int, retries: Int) -> HealthStatus {
        consecutiveFailures >= max(1, retries) ? .unhealthy : .healthy
    }
}
