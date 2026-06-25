import Foundation

/// Canonical external URLs (repo, docs, issues), built from one owner/repo pair so the Help menu and
/// any "open on GitHub" affordance stay in sync. `owner` is filled in when the repo is published.
enum Links {
    static let owner = "tdeverx"            // replaced with the GitHub login at publish time
    static let repo = "contained-app"

    static var repoURL: URL { URL(string: "https://github.com/\(owner)/\(repo)")! }
    static var issuesURL: URL { repoURL.appendingPathComponent("issues") }
    static var releasesURL: URL { repoURL.appendingPathComponent("releases") }

    /// A page in the GitHub wiki, which is where the human docs live (e.g. `Keyboard-Shortcuts`).
    static var wikiURL: URL { repoURL.appendingPathComponent("wiki") }
    static func wiki(_ page: String) -> URL { wikiURL.appendingPathComponent(page) }

    static var helpURL: URL { wikiURL }                       // wiki Home
    static var shortcutsURL: URL { wiki("Keyboard-Shortcuts") }
}
