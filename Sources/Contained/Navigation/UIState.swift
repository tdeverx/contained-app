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
    /// Bumped by Edit ▸ Find — consumed by `RootView` to focus the search field.
    var focusSearchTick = 0
    /// Set by File ▸ Import Compose… — consumed by the Templates/Stacks views to open the picker.
    var pendingComposeImport = false

    /// A one-shot action requested from the unified toolbar or a menu, addressed to a specific
    /// section's view. The view consumes it (clearing it) on appear *and* on change, which is
    /// race-free across the section switch that mounts the view.
    var pendingAction: PendingAction?

    /// Navigate to the action's section and arm it for the destination view to pick up.
    func dispatch(_ action: PendingAction) {
        section = action.section
        switch action {
        case .runContainer: showRunSheet = true       // RootView is always mounted — no handoff needed
        case .build: break                            // navigate only; Build has its own UI
        default: pendingAction = action
        }
    }

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

/// A one-shot, section-targeted action requested from the unified toolbar (or a menu). Each knows
/// which sidebar section owns it, so `UIState.dispatch` can navigate there first.
enum PendingAction: Equatable {
    case runContainer
    case pullImage, loadImage, pruneImages
    case createVolume
    case createNetwork
    case registryLogin
    case build
    case activityHistory, systemLogs

    var section: AppSection {
        switch self {
        case .runContainer:                       return .containers
        case .pullImage, .loadImage, .pruneImages: return .images
        case .createVolume:                       return .volumes
        case .createNetwork:                      return .networks
        case .registryLogin:                      return .registries
        case .build:                              return .build
        case .activityHistory, .systemLogs:       return .system
        }
    }
}
