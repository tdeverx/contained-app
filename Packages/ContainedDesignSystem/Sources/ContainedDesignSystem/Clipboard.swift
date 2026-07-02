import AppKit

/// Shared pasteboard helper for copy affordances in package-owned chrome.
@MainActor
public func copyToPasteboard(_ string: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(string, forType: .string)
}
