import Foundation

/// Canonical external URLs (repo, docs, issues), built from one owner/repo pair so the Help menu and
/// any "open on GitHub" affordance stay in sync. `owner` is filled in when the repo is published.
enum Links {
    static let owner = "tdeverx"            // replaced with the GitHub login at publish time
    static let repo = "contained-app"

    static var repoURL: URL { URL(string: "https://github.com/\(owner)/\(repo)")! }
    static var issuesURL: URL { repoURL.appendingPathComponent("issues") }
    static var releasesURL: URL { repoURL.appendingPathComponent("releases") }

    /// A rendered Markdown doc on GitHub (e.g. `docs/Features.md`).
    static func doc(_ file: String) -> URL {
        repoURL.appendingPathComponent("blob/main/docs/\(file)")
    }

    static var helpURL: URL { doc("Features.md") }
    static var shortcutsURL: URL { doc("Keyboard-Shortcuts.md") }
}
