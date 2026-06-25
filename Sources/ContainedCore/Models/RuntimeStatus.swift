import Foundation

/// The real runtime state reported by `container` (verified against `list --format json`,
/// where it appears as `status.state`). The runtime has exactly these states — there is no
/// `paused` or `crashed`. "Errored" is a *derived* UI concept, not a runtime state.
public enum RuntimeStatus: String, Codable, Sendable, CaseIterable {
    case unknown
    case stopped
    case running
    case stopping

    /// Unknown/forward-compatible values decode to `.unknown` rather than throwing.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RuntimeStatus(rawValue: raw) ?? .unknown
    }
}
