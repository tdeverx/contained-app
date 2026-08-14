import AppKit
import SwiftUI

/// Narrow AppKit boundary for macOS host behaviors SwiftUI does not expose directly.
@MainActor
enum Platform {
    static var systemAccentColor: Color {
        Color(nsColor: .controlAccentColor)
    }

    static func disableAutomaticWindowTabbing() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    static func activateMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    static func quit() {
        NSApplication.shared.terminate(nil)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func zoomFrontWindow() {
        (NSApp.keyWindow ?? NSApp.mainWindow)?.zoom(nil)
    }
}
