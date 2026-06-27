import SwiftUI

/// Cross-cutting UI state shared between the sidebar header menus, the menu-bar commands, and the
/// content views.
@MainActor
@Observable
final class UIState {
    /// Filter text applied by the section list views. The in-window search affordance is being
    /// reworked; until it returns this stays empty (so every filter is a no-op pass-through).
    var searchText = ""
    var runningOnly = false
    var showRunSheet = false
    var showPalette = false
    /// Highlighted row in the global command palette.
    var paletteIndex = 0
    /// The selected sidebar section (here, not RootView, so the command palette can navigate).
    var section: AppSection = .containers
    /// A spec to prefill the next Create/Run sheet — from "Run" on an image or "Use" on a template.
    var prefillSpec: RunSpec?
    /// Remaining specs to step through as prefilled New-Container windows. Compose import enqueues one
    /// per service; each opens after the previous window closes (Create or Cancel both advance).
    var prefillQueue: [RunSpec] = []

    /// A one-shot action requested from the sidebar header or a menu, addressed to a specific
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
        prefillQueue = []
        presentCreate(spec)
    }

    func useTemplate(_ spec: RunSpec) {
        prefillQueue = []
        presentCreate(spec)
    }

    /// Open the New-Container window prefilled with `spec`.
    func presentCreate(_ spec: RunSpec) {
        prefillSpec = spec
        showRunSheet = true
    }

    /// Open the New-Container window for each queued spec in turn (compose import). Pulls each image
    /// first (with progress), then presents the first window; the rest follow as windows close.
    func beginPrefillQueue(_ specs: [RunSpec], using app: AppModel) {
        guard let first = specs.first else { return }
        prefillQueue = Array(specs.dropFirst())
        Task {
            for spec in specs { _ = await app.ensureImage(spec.image) }
            presentCreate(first)
        }
    }

    /// Advance to the next queued prefill when a New-Container window closes. No-op when drained.
    func advancePrefillQueue() {
        guard !prefillQueue.isEmpty else { return }
        let next = prefillQueue.removeFirst()
        // Re-present on the next runloop so the previous sheet finishes dismissing first.
        DispatchQueue.main.async { self.presentCreate(next) }
    }
}

/// A one-shot, section-targeted action requested from the sidebar header (or a menu). Each knows
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
        case .createNetwork:                      return .containers   // networks fold into Containers
        case .registryLogin:                      return .registries
        case .build:                              return .build
        case .activityHistory, .systemLogs:       return .system
        }
    }
}
