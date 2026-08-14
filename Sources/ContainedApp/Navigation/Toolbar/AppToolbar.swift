import SwiftUI
import ContainedUX
import ContainedUI
import ContainedCore

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Search stays in the top-right titlebar band; the add/images/templates/activity cluster and
/// system status control float in a bottom toolbar area.
///
/// Mounted inside the split-view detail column by `ClassicShell`: the top band sits in the title-bar
/// region, the bottom band floats above the detail body, and the sidebar stays outside the custom
/// toolbar safe-area contract.
/// The add `+`, search field, and bottom toolbar controls all grow through the same
/// `UX.Morph.Expander` shell from their measured toolbar slots. Control sizing and source radius come
/// from `UI.Toolbar` / `UI.Toolbar controls`.
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.morphSafeAreaManager) private var safeAreaManager

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?
    @State private var toolbarImageDetail: Core.Image.LocalTagGroup?
    @State private var toolbarImageSourceFrame: CGRect?
    @State private var toolbarImageDetailPresented = false
    @State private var toolbarImageCloseRequestToken = 0
    @State private var morphBackdropExpanded = false

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding. Sourced from `UI.Toolbar` so the band, the safe-area
    /// manager, and the controls all agree.
    static let bandHeight: CGFloat = UI.Toolbar.Size.band

    var body: some View {
        ZStack(alignment: .top) {
            morphBackdropLayer
                .zIndex(40)
            VStack(spacing: 0) {
                topToolbarRow
                    .frame(height: UI.Toolbar.Size.controlHeight)
                    .padding(.top, rowTopInset)   // centered on the traffic-light line
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                bottomToolbarRow
                    .frame(height: UI.Toolbar.Size.controlHeight)
                    .padding(.bottom, bottomRowInset)
            }
            .zIndex(100)
            addMorphLayer
                .zIndex(ui.toolbar.activeMorph == .add ? 300 : 0)
            paletteMorphLayer
                .zIndex(ui.toolbar.activeMorph == .palette ? 300 : 0)
            updatesMorphLayer
                .zIndex(ui.toolbar.activeMorph == .updates ? 300 : 0)
            activityMorphLayer
                .zIndex(ui.toolbar.activeMorph == .activity ? 300 : 0)
            templatesMorphLayer
                .zIndex(ui.toolbar.activeMorph == .templates ? 300 : 0)
            systemMorphLayer
                .zIndex(ui.toolbar.activeMorph == .system ? 300 : 0)
            settingsMorphLayer
                .zIndex(ui.toolbar.activeMorph == .settings ? 300 : 0)
            toolbarImageDetailLayer
                .zIndex(toolbarImageDetail == nil ? 0 : 350)
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(UX.Measurement.SourceFramesKey<UIState.ToolbarMorph>.self) { updateSlots($0) }
        .onChange(of: ui.toolbar.activeMorph) { _, morph in
            if morph == nil { setMorphBackdropExpanded(false) }
        }
    }

    private var morphBackdropLayer: some View {
        return Color.clear
            .globalBackdrop(style: .dim, progress: morphBackdropExpanded ? 1 : 0, dimOpacity: 0.28)
            .contentShape(Rectangle())
            .allowsHitTesting(ui.toolbar.activeMorph != nil)
            .onTapGesture { backdropTapped() }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: morphBackdropExpanded)
    }

    // MARK: Top Row

    private var topToolbarRow: some View {
        HStack(spacing: UI.Toolbar.Spacing.groupSpacing) {
            if !isSidebarOpen {
                settingsZone
                ToolbarPageSwitcher()
            }
            ToolbarPageContextOptions()
            Spacer(minLength: UI.Layout.Spacing.m)
            searchZone
        }
        .padding(.leading, UI.Toolbar.Spacing.outerPadding)
        .padding(.trailing, UI.Toolbar.Spacing.outerPadding)
        .frame(maxWidth: .infinity)
    }

    /// Top-left empty glass container mirroring the traffic-light cluster width. It has no controls —
    /// it's vanity chrome that owns the `.settings` morph slot so the Settings panel (opened via ⌘, or
    /// the menu) has a frame to grow from.
    private var settingsZone: some View {
        UI.Toolbar.VanitySlot()
        .opacity(ui.toolbar.activeMorph == .settings ? 0 : 1)
        .background(singleSlotReader(.settings))
    }

    private var isSidebarOpen: Bool {
        app.settings.sidebarNavigationEnabled && ui.sidebarVisible
    }

    private var searchZone: some View {
        ToolbarSearchSource()
            .frame(width: UI.Toolbar.Size.searchMaxWidth, height: UI.Toolbar.Size.controlHeight)
            .opacity(ui.toolbar.activeMorph == .palette ? 0 : 1)
            .background(singleSlotReader(.palette))
    }

    @ViewBuilder
    private var paletteMorphLayer: some View {
        // Render-level backstop: with the experimental palette disabled, never present it even if some
        // activation path slips through. Keeps the gate airtight from a single place.
        if ui.toolbar.activeMorph == .palette, app.settings.commandPaletteEnabled {
            UX.Morph.Expander(isPresented: paletteMorphBinding,
                             originFrame: slots[.palette] ?? .zero,
                             target: toolbarMorphTarget(for: .palette, size: UI.Panel.Size.palette),
                             showsBackdrop: false,
                             closeRequestToken: ui.toolbar.closeRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarCommandPalette { ui.requestMorphClose(.palette) }
            }
        }
    }

    // MARK: Bottom Row

    private var bottomToolbarRow: some View {
        HStack(spacing: UI.Toolbar.Spacing.groupSpacing) {
            systemStatusButton
            ToolbarPageFilterOptions()
            Spacer(minLength: UI.Layout.Spacing.m)
            bottomActionGroup
        }
        .padding(.horizontal, UI.Toolbar.Spacing.outerPadding)
        .frame(maxWidth: .infinity)
    }

    private var systemStatusButton: some View {
        UI.Toolbar.StatusButton(help: app.activity?.title ?? "System \(app.serviceLabel)",
                                  action: { openGlobalSectionOrPanel(.system, morph: .system) }) {
            if let activity = app.activity {
                UI.State.ActivityStatusIndicator(activity: UI.State.ActivityStatus(title: activity.title,
                                                                        detail: activity.detail,
                                                                        fraction: activity.fraction),
                                   style: .inline)
            } else {
                HStack(spacing: UI.Toolbar.Spacing.searchIconGap) {
                    UI.Symbol.Image(systemName: systemStatusIcon,
                                 tone: systemStatusTone,
                                 frameWidth: UI.Toolbar.Size.iconContentWidth)
                    UI.State.StatusText(app.serviceLabel)
                        .padding(.trailing, UI.Toolbar.Placement.statusLabelTrailingPadding)
                }
            }
        }
        .opacity(ui.toolbar.activeMorph == .system ? 0 : 1)
        .background(singleSlotReader(.system))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: app.activity != nil)
    }

    private var bottomActionGroup: some View {
        HStack(spacing: UI.Toolbar.Spacing.groupSpacing) {
            UI.Toolbar.ActionCluster {
                UI.Action.Items([
                    UI.Action.Item(systemName: "plus", help: AppText.add) { ui.openCreationPanel() },
                    UI.Action.Item(systemName: "shippingbox", help: AppText.string("section.images", defaultValue: "Images")) {
                        openGlobalSectionOrPanel(.images, morph: .updates)
                    },
                    UI.Action.Item(systemName: "bookmark", help: AppText.string("section.templates", defaultValue: "Templates")) {
                        openGlobalSectionOrPanel(.templates, morph: .templates)
                    }
                ])
                ActivityToolbarButton()
            }
            .opacity(isBottomGroupMorphActive ? 0 : 1)
            .background(clusterSlotReader([.add, .updates, .templates, .activity]))
        }
    }

    // MARK: Add morph layer

    @ViewBuilder
    private var addMorphLayer: some View {
        if ui.toolbar.activeMorph == .add {
            UX.Morph.Expander(isPresented: addMorphBinding, originFrame: slots[.add] ?? .zero,
                             target: toolbarMorphTarget(for: .add, size: UI.Panel.Size.add),
                             showsBackdrop: false,
                             closeRequestToken: ui.toolbar.closeRequestToken,
                             onBackdropTap: addSoftDismiss,
                             onExpansionChange: setMorphBackdropExpanded) {
                CreationFlow(start: CreationFlow.Start(ui.creation.entry),
                             onClose: {
                                 addSoftDismiss = nil
                                 ui.creation.prefillSpec = nil
                                 ui.creation.editSnapshot = nil
                                 ui.creation.returnEntry = nil
                                 ui.requestMorphClose(.add)
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                                     ui.advancePrefillQueue()
                                 }
                             },
                             prefill: ui.creation.prefillSpec,
                             editSnapshot: ui.creation.editSnapshot,
                             searchQuery: ui.creation.searchQuery,
                             returnEntry: ui.creation.returnEntry,
                             onSoftDismissChange: { addSoftDismiss = $0 })
                    .id(ui.creation.requestToken)
            }
        }
    }

    @ViewBuilder
    private var updatesMorphLayer: some View {
        if ui.toolbar.activeMorph == .updates {
            UX.Morph.Expander(isPresented: morphBinding(.updates),
                             originFrame: slots[.updates] ?? .zero,
                             target: toolbarMorphTarget(for: .updates, size: UI.Panel.Size.images),
                             showsBackdrop: false,
                             closeRequestToken: ui.toolbar.closeRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarUpdatesPanel(hiddenImageGroupID: toolbarImageDetailPresented ? toolbarImageDetail?.id : nil,
                                    onOpenImage: openToolbarImageDetail) {
                    ui.requestMorphClose(.updates)
                }
            }
        }
    }

    @ViewBuilder
    private var toolbarImageDetailLayer: some View {
        if let detail = toolbarImageDetail, toolbarImageDetailPresented {
            UX.Morph.SingleSurfaceExpander(isPresented: toolbarImageDetailBinding,
                                          originFrame: usableToolbarImageSource ?? .zero,
                                          target: .anchored(size: toolbarImageDetailSize,
                                                            safeArea: toolbarMorphSafeArea(for: .updates),
                                                            margin: 16),
                                          backdropStyle: .dim,
                                          showsBackdrop: true,
                                          closeRequestToken: toolbarImageCloseRequestToken,
                                          onBackdropTap: closeToolbarImageDetail) {
                ToolbarImageGroupCard(group: currentToolbarImageGroup(detail),
                                      isExpanded: true,
                                      onTap: {},
                                      onClose: closeToolbarImageDetail)
            }
        }
    }

    @ViewBuilder
    private var activityMorphLayer: some View {
        if ui.toolbar.activeMorph == .activity {
            UX.Morph.Expander(isPresented: morphBinding(.activity),
                             originFrame: slots[.activity] ?? .zero,
                             target: toolbarMorphTarget(for: .activity, size: UI.Panel.Size.activity),
                             showsBackdrop: false,
                             closeRequestToken: ui.toolbar.closeRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarActivityPanel {
                    ui.requestMorphClose(.activity)
                }
            }
        }
    }

    @ViewBuilder
    private var templatesMorphLayer: some View {
        if ui.toolbar.activeMorph == .templates {
            UX.Morph.Expander(isPresented: morphBinding(.templates),
                             originFrame: slots[.templates] ?? .zero,
                             target: toolbarMorphTarget(for: .templates, size: UI.Panel.Size.templates),
                             showsBackdrop: false,
                             closeRequestToken: ui.toolbar.closeRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarTemplatesPanel {
                    ui.requestMorphClose(.templates)
                }
            }
        }
    }

    @ViewBuilder
    private var systemMorphLayer: some View {
        if ui.toolbar.activeMorph == .system {
            UX.Morph.Expander(isPresented: morphBinding(.system),
                             originFrame: slots[.system] ?? .zero,
                             target: toolbarMorphTarget(for: .system, size: UI.Panel.Size.system),
                             showsBackdrop: false,
                             closeRequestToken: ui.toolbar.closeRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarSystemPanel { ui.requestMorphClose(.system) }
            }
        }
    }

    @ViewBuilder
    private var settingsMorphLayer: some View {
        if ui.toolbar.activeMorph == .settings {
            UX.Morph.Expander(isPresented: morphBinding(.settings),
                             originFrame: slots[.settings] ?? .zero,
                             target: toolbarMorphTarget(for: .settings, size: UI.Panel.Size.settings),
                             showsBackdrop: false,
                             closeRequestToken: ui.toolbar.closeRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarSettingsPanel { ui.requestMorphClose(.settings) }
            }
        }
    }

    private var addMorphBinding: Binding<Bool> {
        Binding(get: { ui.toolbar.activeMorph == .add }, set: {
            if !$0 { addSoftDismiss = nil; ui.toolbar.activeMorph = nil }
        })
    }

    private func morphBinding(_ morph: UIState.ToolbarMorph) -> Binding<Bool> {
        Binding(get: { ui.toolbar.activeMorph == morph }, set: {
            if !$0 { ui.toolbar.activeMorph = nil }
        })
    }

    private var paletteMorphBinding: Binding<Bool> {
        Binding(get: { ui.toolbar.activeMorph == .palette }, set: {
            if !$0 {
                ui.search.text = ""
                ui.search.scope = nil
                ui.toolbar.activeMorph = nil
            }
        })
    }

    private func backdropTapped() {
        if ui.toolbar.activeMorph == .add, let addSoftDismiss {
            addSoftDismiss()
        } else {
            ui.requestMorphClose()
        }
    }

    private func setMorphBackdropExpanded(_ isExpanded: Bool) {
        morphBackdropExpanded = isExpanded
    }

    private func updateSlots(_ next: [UIState.ToolbarMorph: CGRect]) {
        guard !slots.isClose(to: next) else { return }
        slots = next
    }

    private var toolbarImageDetailBinding: Binding<Bool> {
        Binding(get: { toolbarImageDetailPresented }, set: {
            guard !$0 else {
                toolbarImageDetailPresented = true
                return
            }
            toolbarImageDetailPresented = false
            toolbarImageDetail = nil
            toolbarImageSourceFrame = nil
        })
    }

    /// Report one shared frame (the cluster capsule) as the morph origin for several morphs at once.
    private func clusterSlotReader(_ morphs: [UIState.ToolbarMorph]) -> some View {
        UX.Measurement.SourceFrameReader<UIState.ToolbarMorph>(morphs, coordinateSpaceName: Self.space)
    }

    private func singleSlotReader(_ morph: UIState.ToolbarMorph) -> some View {
        UX.Measurement.SourceFrameReader(morph, coordinateSpaceName: Self.space)
    }

    /// Safe area for a morph panel. Bottom-row panels clear the top toolbar; top-row panels clear the
    /// bottom. Settings is special: it grows from the vanity slot behind the traffic lights and must
    /// clear *both* bands so the panel starts fully below the native titlebar chrome.
    private func toolbarMorphSafeArea(for morph: UIState.ToolbarMorph) -> UX.SafeArea.Policy {
        switch morph {
        case .settings: UX.SafeArea.Policy(excluding: .both, padding: .small)
        case .palette:  UX.SafeArea.Policy(excluding: .bottom, padding: .small)
        default:        UX.SafeArea.Policy(excluding: .top, padding: .small)
        }
    }

    private func toolbarMorphTarget(for morph: UIState.ToolbarMorph,
                                    size: CGSize,
                                    placement: UX.Panel.Placement = .anchored) -> UX.Morph.Target {
        let safeArea = toolbarMorphSafeArea(for: morph)
        switch placement {
        case .anchored:
            return .anchored(size: size, safeArea: safeArea, margin: 0)
        case .centered:
            return .centered(size: size, safeArea: safeArea, margin: 0)
        }
    }

    private var rowTopInset: CGFloat { UI.Toolbar.Spacing.topPadding }

    private var bottomRowInset: CGFloat {
        max(UI.Toolbar.Spacing.outerPadding, safeAreaManager.system.bottom + UI.Toolbar.Spacing.outerPadding)
    }

    private var systemStatusTone: UI.State.Tone {
        switch app.serviceLabel {
        case "Running":
            .success
        case "Checking…":
            .info
        case "Stopped":
            .warning
        default:
            .error
        }
    }

    private var systemStatusIcon: String {
        switch app.serviceLabel {
        case "Running":
            "circle.fill"
        case "Checking…":
            "arrow.triangle.2.circlepath"
        case "Stopped":
            "pause.circle.fill"
        default:
            "exclamationmark.triangle.fill"
        }
    }

    private var isBottomGroupMorphActive: Bool {
        switch ui.toolbar.activeMorph {
        case .add, .updates, .templates, .activity:
            true
        case .palette, .system, .settings, nil:
            false
        }
    }

    private var usableToolbarImageSource: CGRect? {
        guard let frame = toolbarImageSourceFrame,
              frame.width.isFinite, frame.height.isFinite,
              frame.minX.isFinite, frame.minY.isFinite,
              frame.width > 1, frame.height > 1
        else { return nil }
        return frame
    }

    private var toolbarImageDetailSize: CGSize {
        UI.Panel.Size.imageDetail
    }

    private func currentToolbarImageGroup(_ group: Core.Image.LocalTagGroup) -> Core.Image.LocalTagGroup {
        app.localImageGroups().first { $0.id == group.id } ?? group
    }

    private func openToolbarImageDetail(_ group: Core.Image.LocalTagGroup, sourceFrame: CGRect) {
        toolbarImageDetail = group
        toolbarImageSourceFrame = sourceFrame
        toolbarImageDetailPresented = true
    }

    private func closeToolbarImageDetail() {
        toolbarImageCloseRequestToken &+= 1
    }

    private func openGlobalSectionOrPanel(_ section: AppSection, morph: UIState.ToolbarMorph) {
        if ui.panelNavigationEnabled {
            ui.toggleMorph(morph)
        } else {
            ui.navigate(to: section)
        }
    }
}

/// The Activity bell in the bottom toolbar cluster. Filled + accent-tinted when there are unread
/// events; plain otherwise. Reads the cached aggregate so idle toolbar rendering never fetches rows.
private struct ActivityToolbarButton: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    var body: some View {
        let count = app.historyStore.activitySummary.unreadEvents
        let hasUnread = count > 0
        return UI.Action.Items([
            UI.Action.Item(systemName: hasUnread ? "bell.fill" : "bell",
                         help: hasUnread ? "Activity — \(count) unread" : "Activity",
                         tint: hasUnread ? app.settings.accentTint.resolvedAppAccentColor : .white) {
                                   if ui.panelNavigationEnabled {
                                       ui.toggleMorph(.activity)
                                   } else {
                                       ui.navigate(to: .activity)
                                   }
            }
        ])
    }
}
