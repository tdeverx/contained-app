import AppKit

/// Minor AppKit host glue (flagged per the SwiftUI-first rule): clipboard + haptics.
@MainActor
func copyToPasteboard(_ string: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(string, forType: .string)
}

@MainActor
func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
    NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
}
