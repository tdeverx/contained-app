import Foundation

/// Canonical external URLs (repo, docs, issues), built from one owner/repo pair so the Help menu and
/// any "open on GitHub" affordance stay in sync.
enum Links {
    static let owner = "tdeverx"
    static let repo = "contained-app"

    static var repoURL: URL { URL(string: "https://github.com/\(owner)/\(repo)")! }
    static var issuesURL: URL { repoURL.appendingPathComponent("issues") }
    static var releasesURL: URL { repoURL.appendingPathComponent("releases") }

    /// A page in the GitHub wiki, which is where the human docs live (e.g. `Keyboard-Shortcuts`).
    /// Page names match the wiki page titles exactly so the links resolve.
    static var wikiURL: URL { repoURL.appendingPathComponent("wiki") }
    static func wiki(_ page: String) -> URL { wikiURL.appendingPathComponent(page) }

    static var helpURL: URL { wiki("Home") }                  // wiki Home page
    static var featuresURL: URL { wiki("Features") }
    static var installURL: URL { wiki("Installation") }
    static var shortcutsURL: URL { wiki("Keyboard-Shortcuts") }
    static var troubleshootingURL: URL { wiki("Troubleshooting") }
    static var architectureURL: URL { wiki("Architecture") }
    static var contributingURL: URL { wiki("Contributing") }
    static var releaseDocURL: URL { wiki("Release") }
}
