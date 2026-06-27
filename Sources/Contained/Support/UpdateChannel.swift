import Foundation

/// The Sparkle update channel the user opts into. Each channel maps to an **independent appcast feed**
/// hosted at the matching git branch's repo root (raw.githubusercontent.com). The app switches which
/// feed Sparkle reads per selection (see `UpdaterController`), so a branch's manifest never has to be
/// merged into another — promoting beta→stable is a normal branch merge and the feed follows.
///
/// Build numbers (`git rev-list --count HEAD`) are monotonic across branches, so a nightly user always
/// has the highest build and is never stranded behind stable — no `sparkle:channel` tags needed.
enum UpdateChannel: String, CaseIterable, Identifiable, Codable, Sendable {
    case stable, beta, nightly

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// The git branch whose `appcast.xml` (at repo root) backs this channel.
    var branch: String {
        switch self {
        case .stable:  return "stable"
        case .beta:    return "beta"
        case .nightly: return "nightly"
        }
    }

    /// The independent Sparkle feed for this channel — the branch's `appcast.xml` served raw.
    var feedURL: String {
        "https://raw.githubusercontent.com/\(Links.owner)/\(Links.repo)/\(branch)/appcast.xml"
    }

    /// Sparkle's `allowedChannels(for:)` set. With per-branch feeds the feed selection *is* the
    /// channel, so this stays empty (kept for API completeness; items carry no channel tag).
    var allowedChannels: Set<String> { [] }

    var footnote: String {
        switch self {
        case .stable:  return "Only finished releases."
        case .beta:    return "Pre-release builds, ahead of stable. May be rough."
        case .nightly: return "The latest build from every commit. Expect rough edges."
        }
    }
}
