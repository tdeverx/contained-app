import SwiftUI
import ContainedCore

/// Cross-cutting UI state shared between toolbar panels, menu commands, and content views.
@MainActor
@Observable
final class UIState {
    enum CreationEntry: Hashable { case menu, chooser, search, configure, network, volume, build }
    enum ToolbarMorph: Hashable { case add, palette, updates, activity, templates, system, settings }

    struct CreationPresentation {
        var entry: CreationEntry = .menu
        var prefillSpec: RunSpec?
        var editSnapshot: ContainerSnapshot?
        var searchQuery = ""
        var requestToken = 0
    }

    struct ToolbarPresentation {
        var activeMorph: ToolbarMorph?
        var closeRequestToken = 0
    }

    struct SearchPresentation {
        /// Filter text applied by the section list views. The in-window search affordance is being
        /// reworked; until it returns this stays empty (so every filter is a no-op pass-through).
        var text = ""
        var pageResultCount: Int?
        var paletteIndex = 0
        var focusToken = 0
        /// The active palette scope. `nil` searches commands; a scope pins a chip to the search field
        /// and searches in-place (Docker Hub or local images) without leaving the palette.
        var scope: PaletteScope?
    }

    struct PrefillPresentation {
        var showRunSheet = false
        var currentSpec: RunSpec?
        var queue: [RunSpec] = []
    }

    var creation = CreationPresentation()
    var toolbar = ToolbarPresentation()
    var search = SearchPresentation()
    var prefill = PrefillPresentation()
    var runningOnly = false
    /// How the Containers page groups its cards (Network / Volume / Image / Flat) and orders them —
    /// driven by the top-left toolbar view-options control.
    var grouping: ContainerGrouping = .network
    var sort: ContainerSort = .name

    /// When set, `SettingsContent` will switch to this page as soon as it appears / becomes active.
    /// Cleared by `SettingsContent` after it consumes the value.
    var settingsPage: SettingsContent.SettingsPage? = nil

    /// A one-shot action requested by menus or the command palette. `RootView` consumes global
    /// actions, while toolbar panels and the Containers page handle their local operations directly.
    var pendingAction: PendingAction?

    // MARK: Compatibility accessors

    var searchText: String {
        get { search.text }
        set { search.text = newValue }
    }

    var showRunSheet: Bool {
        get { prefill.showRunSheet }
        set { prefill.showRunSheet = newValue }
    }

    var creationEntry: CreationEntry {
        get { creation.entry }
        set { creation.entry = newValue }
    }

    var creationPrefillSpec: RunSpec? {
        get { creation.prefillSpec }
        set { creation.prefillSpec = newValue }
    }

    var creationEditSnapshot: ContainerSnapshot? {
        get { creation.editSnapshot }
        set { creation.editSnapshot = newValue }
    }

    var creationSearchQuery: String {
        get { creation.searchQuery }
        set { creation.searchQuery = newValue }
    }

    private(set) var creationRequestToken: Int {
        get { creation.requestToken }
        set { creation.requestToken = newValue }
    }

    var activeMorph: ToolbarMorph? {
        get { toolbar.activeMorph }
        set { toolbar.activeMorph = newValue }
    }

    private(set) var morphCloseRequestToken: Int {
        get { toolbar.closeRequestToken }
        set { toolbar.closeRequestToken = newValue }
    }

    var pageResultCount: Int? {
        get { search.pageResultCount }
        set { search.pageResultCount = newValue }
    }

    var paletteIndex: Int {
        get { search.paletteIndex }
        set { search.paletteIndex = newValue }
    }

    var paletteScope: PaletteScope? {
        get { search.scope }
        set { search.scope = newValue }
    }

    var prefillSpec: RunSpec? {
        get { prefill.currentSpec }
        set { prefill.currentSpec = newValue }
    }

    var prefillQueue: [RunSpec] {
        get { prefill.queue }
        set { prefill.queue = newValue }
    }

    private(set) var searchFocusToken: Int {
        get { search.focusToken }
        set { search.focusToken = newValue }
    }

    // MARK: Actions

    /// Open the Settings panel and navigate to a specific page in one call.
    func openSettings(to page: SettingsContent.SettingsPage) {
        settingsPage = page
        if activeMorph != .settings { activeMorph = .settings }
    }

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

    /// Run an action by opening the right creation page, morph panel, or global sheet.
    func dispatch(_ action: PendingAction) {
        switch action {
        case .runContainer:
            openCreationPanel(entry: .chooser)
        case .pullImage:
            openCreationPanel(entry: .search)
        case .createVolume:
            openCreationPanel(entry: .volume)
        case .createNetwork:
            openCreationPanel(entry: .network)
        case .build:
            openCreationPanel(entry: .build)
        case .activityHistory:
            activeMorph = .activity
        case .loadImage, .pruneImages, .registryLogin, .systemLogs:
            pendingAction = action
        }
    }

    /// Open the creation flow in the toolbar add morph at a specific page.
    func openCreationPanel(entry: CreationEntry = .menu, prefill spec: RunSpec? = nil, searchQuery: String = "") {
        creationEntry = entry
        creationPrefillSpec = spec
        creationEditSnapshot = nil
        creationSearchQuery = searchQuery
        creationRequestToken &+= 1
        activeMorph = .add
    }

    func openCreationPanel(prefill spec: RunSpec) {
        openCreationPanel(entry: .configure, prefill: spec)
    }

    func openCreationPanel(editing snapshot: ContainerSnapshot) {
        creationEntry = .configure
        creationPrefillSpec = nil
        creationEditSnapshot = snapshot
        creationRequestToken &+= 1
        activeMorph = .add
    }

    /// Bumped by Cmd-S to focus the toolbar page-search field (without opening the command palette).
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
        openCreationPanel(prefill: spec)
    }

    func useTemplate(_ spec: RunSpec) {
        prefillQueue = []
        openCreationPanel(prefill: spec)
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

/// One-shot commands that may come from menus, the command palette, or toolbar panels.
enum PendingAction: Equatable {
    case runContainer
    case pullImage, loadImage, pruneImages
    case createVolume
    case createNetwork
    case registryLogin
    case build
    case activityHistory, systemLogs
}
