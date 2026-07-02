import AppKit

/// Minor AppKit host glue (flagged per the SwiftUI-first rule): haptics.
@MainActor
func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
    NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
}
