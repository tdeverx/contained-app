import SwiftUI

/// Cross-cutting UI state shared between the toolbar (owned by RootView) and the content views.
@MainActor
@Observable
final class UIState {
    var searchText = ""
    var runningOnly = false
    var showRunSheet = false
    var showPalette = false
    /// The selected sidebar section (here, not RootView, so the command palette can navigate).
    var section: AppSection = .containers
    /// A spec to prefill the next Create/Run sheet — from "Run" on an image or "Use" on a template.
    var prefillSpec: RunSpec?

    // Menu-driven action tickets. Bumping a counter (rather than a Bool) lets a view re-trigger the
    // same action and avoids sticky-flag races; views watch the counter via `.onChange`.
    /// Bumped by File ▸ Pull Image… — consumed by `ImagesListView` to open the pull sheet.
    var requestPull = 0
    /// Bumped by Edit ▸ Find — consumed by `RootView` to focus the search field.
    var focusSearchTick = 0
    /// Set by File ▸ Import Compose… — consumed by the Templates/Stacks views to open the picker.
    var pendingComposeImport = false

    func runImage(_ reference: String) {
        var spec = RunSpec()
        spec.image = reference
        prefillSpec = spec
        showRunSheet = true
    }

    func useTemplate(_ spec: RunSpec) {
        prefillSpec = spec
        showRunSheet = true
    }
}
