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
    enum CreationEntry: Hashable { case chooser, search, configure, network, volume, build }
    var creationEntry: CreationEntry = .chooser
    var creationPrefillSpec: RunSpec?
    /// The unified creation wizard (the front door for "new container"). Distinct from `showRunSheet`,
    /// which presents the configure form directly — that's the wizard's handoff target as well as the
    /// direct-prefill paths (Run-image, Use-template, compose queue).
    var showCreateWizard = false

    /// Which toolbar button is currently morphed open into a centered panel (nil = none). The toolbar
    /// reads this to grow the matching panel from that button's slot.
    enum ToolbarMorph: Hashable { case add, palette, updates, activity, templates, system, settings }
    var activeMorph: ToolbarMorph?
    private(set) var morphCloseRequestToken = 0

    /// Toggle a toolbar morph panel (open it, or close it if already open).
    func toggleMorph(_ morph: ToolbarMorph) {
        if activeMorph == morph {
            requestMorphClose(morph)
        } else {
            activeMorph = morph
        }
    }

    func requestMorphClose(_ morph: ToolbarMorph? = nil) {
        guard let activeMorph, morph == nil || activeMorph == morph else { return }
        morphCloseRequestToken &+= 1
    }

    /// The number of results the current page is showing for `searchText` (nil = page doesn't report
    /// a count, so no auto-escalation). The toolbar uses this to morph the page search into the full
    /// command palette when an in-page search comes up empty.
    var pageResultCount: Int?
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

    /// Run an action — navigating to its owning section where one applies, and arming section-targeted
    /// actions for the destination view to pick up. Image load/prune are global (no Images page).
    func dispatch(_ action: PendingAction) {
        switch action {
        case .runContainer:
            creationEntry = .chooser
            showCreateWizard = true   // front door is the wizard, not the bare form
        case .pullImage:
            creationEntry = .search
            showCreateWizard = true
        case .createVolume:
            creationEntry = .volume   // volumes live in the System panel; creation is the `+` flow
            showCreateWizard = true
        case .createNetwork:
            creationEntry = .network  // networks fold into Containers
            showCreateWizard = true
        case .build:
            creationEntry = .build    // build is a page in the creation flow now
            showCreateWizard = true
        case .activityHistory:
            activeMorph = .activity   // Activity is its own toolbar panel
        case .loadImage, .pruneImages, .registryLogin, .systemLogs:
            pendingAction = action    // handled globally in RootView (no standalone pages)
        }
    }

    /// Open the creation wizard from scratch (the paged chooser). The flow handles its own steps and
    /// hands off to compose/tar imports internally, so there's no post-dismiss outcome to resolve.
    func openCreateWizard() {
        creationEntry = .chooser
        creationPrefillSpec = nil
        showCreateWizard = true
    }

    func openCreateWizard(prefill spec: RunSpec) {
        creationEntry = .configure
        creationPrefillSpec = spec
        showCreateWizard = true
    }

    /// Bumped by ⌘S to focus the toolbar page-search field (without opening the command palette).
    private(set) var searchFocusToken = 0
    func focusSearch() {
        if activeMorph != nil {
            requestMorphClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
                self?.searchFocusToken &+= 1
            }
        } else {
            searchFocusToken &+= 1
        }
    }

    func runImage(_ reference: String) {
        var spec = RunSpec()
        spec.image = reference
        prefillQueue = []
        openCreateWizard(prefill: spec)
    }

    func useTemplate(_ spec: RunSpec) {
        prefillQueue = []
        openCreateWizard(prefill: spec)
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
}
