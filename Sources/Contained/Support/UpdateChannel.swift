import Foundation

/// The Sparkle update channel the user opts into. Channels are **cumulative** — picking a more
/// bleeding-edge channel still receives the calmer ones, so a user never sits behind a lagging
/// channel. Stable items carry no channel tag in the appcast; beta/nightly items are tagged.
enum UpdateChannel: String, CaseIterable, Identifiable, Codable, Sendable {
    case stable, beta, nightly

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// The set Sparkle's `allowedChannels(for:)` should return for this selection. Stable maps to the
    /// empty set (only un-channeled items are offered).
    var allowedChannels: Set<String> {
        switch self {
        case .stable:  return []
        case .beta:    return ["beta"]
        case .nightly: return ["beta", "nightly"]
        }
    }

    var footnote: String {
        switch self {
        case .stable:  return "Only finished releases."
        case .beta:    return "Pre-release builds, ahead of stable. May be rough."
        case .nightly: return "The latest build from every commit. Expect rough edges."
        }
    }
}
