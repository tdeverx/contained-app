import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import SwiftData
import ContainedCore

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Search stays in the top-right titlebar band; the add/images/templates/activity cluster and
/// system status control float in a bottom toolbar area.
///
/// Mounted inside the split-view detail column by `ClassicShell`: the top band sits in the title-bar
/// region, the bottom band floats above the detail body, and the sidebar stays outside the custom
/// toolbar safe-area contract.
/// The add `+`, search field, and bottom toolbar controls all grow through the same
/// `MorphingExpander` shell from their measured toolbar slots. Control sizing and source radius come
/// from `DesignTokens.Toolbar` / `ToolbarControls`.
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.morphSafeAreas) private var safeAreas

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?
    @State private var toolbarImageDetail: LocalImageTagGroup?
    @State private var toolbarImageSourceFrame: CGRect?
    @State private var toolbarImageDetailPresented = false
    @State private var toolbarImageCloseRequestToken = 0
    @State private var morphBackdropExpanded = false

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding. Sourced from `DesignTokens.Toolbar` so the band, the safe-area
    /// manager, and the controls all agree.
    static let bandHeight: CGFloat = DesignTokens.Toolbar.band

    var body: some View {
        ZStack(alignment: .top) {
            morphBackdropLayer
                .zIndex(40)
            VStack(spacing: 0) {
                topToolbarRow
                    .frame(height: DesignTokens.Toolbar.controlHeight)
                    .padding(.top, rowTopInset)   // centered on the traffic-light line
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                bottomToolbarRow
                    .frame(height: DesignTokens.Toolbar.controlHeight)
                    .padding(.bottom, bottomRowInset)
            }
            .zIndex(100)
            addMorphLayer
                .zIndex(ui.activeMorph == .add ? 300 : 0)
            paletteMorphLayer
                .zIndex(ui.activeMorph == .palette ? 300 : 0)
            updatesMorphLayer
                .zIndex(ui.activeMorph == .updates ? 300 : 0)
            activityMorphLayer
                .zIndex(ui.activeMorph == .activity ? 300 : 0)
            templatesMorphLayer
                .zIndex(ui.activeMorph == .templates ? 300 : 0)
            systemMorphLayer
                .zIndex(ui.activeMorph == .system ? 300 : 0)
            settingsMorphLayer
                .zIndex(ui.activeMorph == .settings ? 300 : 0)
            toolbarImageDetailLayer
                .zIndex(toolbarImageDetail == nil ? 0 : 350)
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(MorphSourceFramesKey<UIState.ToolbarMorph>.self) { updateSlots($0) }
        .onChange(of: ui.activeMorph) { _, morph in
            if morph == nil { setMorphBackdropExpanded(false) }
        }
    }

    private var morphBackdropLayer: some View {
        return Color.clear
            .globalBackdrop(style: .dim, progress: morphBackdropExpanded ? 1 : 0, dimOpacity: 0.28)
            .contentShape(Rectangle())
            .allowsHitTesting(ui.activeMorph != nil)
            .onTapGesture { backdropTapped() }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: morphBackdropExpanded)
    }

    // MARK: Top Row

    private var topToolbarRow: some View {
        HStack(spacing: DesignTokens.Toolbar.groupSpacing) {
            if !isSidebarOpen {
                settingsZone
                ToolbarPageSwitcher()
            }
            ToolbarPageContextOptions()
            Spacer(minLength: DesignTokens.Space.m)
            searchZone
        }
        .padding(.leading, DesignTokens.Toolbar.outerPadding)
        .padding(.trailing, DesignTokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    /// Top-left empty glass container mirroring the traffic-light cluster width. It has no controls —
    /// it's vanity chrome that owns the `.settings` morph slot so the Settings panel (opened via ⌘, or
    /// the menu) has a frame to grow from.
    private var settingsZone: some View {
        DesignToolbarVanitySlot()
        .opacity(ui.activeMorph == .settings ? 0 : 1)
        .background(singleSlotReader(.settings))
    }

    private var isSidebarOpen: Bool {
        app.settings.sidebarNavigationEnabled && ui.sidebarVisible
    }

    private var searchZone: some View {
        ToolbarSearchSource()
            .frame(width: DesignTokens.Toolbar.searchMaxWidth, height: DesignTokens.Toolbar.controlHeight)
            .opacity(ui.activeMorph == .palette ? 0 : 1)
            .background(singleSlotReader(.palette))
    }

    @ViewBuilder
    private var paletteMorphLayer: some View {
        // Render-level backstop: with the experimental palette disabled, never present it even if some
        // activation path slips through. Keeps the gate airtight from a single place.
        if ui.activeMorph == .palette, app.settings.commandPaletteEnabled {
            MorphingExpander(isPresented: paletteMorphBinding,
                             originFrame: slots[.palette] ?? .zero,
                             target: toolbarMorphTarget(for: .palette, size: DesignTokens.PanelSize.palette),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarCommandPalette { ui.requestMorphClose(.palette) }
            }
        }
    }

    // MARK: Bottom Row

    private var bottomToolbarRow: some View {
        HStack(spacing: DesignTokens.Toolbar.groupSpacing) {
            systemStatusButton
            ToolbarPageFilterOptions()
            Spacer(minLength: DesignTokens.Space.m)
            bottomActionGroup
        }
        .padding(.horizontal, DesignTokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    private var systemStatusButton: some View {
        DesignToolbarStatusButton(help: app.activity?.title ?? "System \(app.serviceLabel)",
                                  action: { openGlobalSectionOrPanel(.system, morph: .system) }) {
            if let activity = app.activity {
                ActivityStatusView(activity: ActivityStatusPresentation(title: activity.title,
                                                                        detail: activity.detail,
                                                                        fraction: activity.fraction),
                                   style: .inline)
            } else {
                HStack(spacing: DesignTokens.Toolbar.searchIconGap) {
                    Image(systemName: systemStatusIcon)
                        .foregroundStyle(systemStatusColor)
                        .frame(width: DesignTokens.Toolbar.iconContentWidth)
                    Text(app.serviceLabel)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, DesignTokens.Toolbar.statusLabelTrailingPadding)
                }
            }
        }
        .opacity(ui.activeMorph == .system ? 0 : 1)
        .background(singleSlotReader(.system))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: app.activity != nil)
    }

    private var bottomActionGroup: some View {
        HStack(spacing: DesignTokens.Toolbar.groupSpacing) {
            DesignToolbarActionCluster {
                DesignActionItems([
                    DesignAction(systemName: "plus", help: AppText.add) { ui.openCreationPanel() },
                    DesignAction(systemName: "shippingbox", help: AppText.string("section.images", defaultValue: "Images")) {
                        openGlobalSectionOrPanel(.images, morph: .updates)
                    },
                    DesignAction(systemName: "bookmark", help: AppText.string("section.templates", defaultValue: "Templates")) {
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
        if ui.activeMorph == .add {
            MorphingExpander(isPresented: addMorphBinding, originFrame: slots[.add] ?? .zero,
                             target: toolbarMorphTarget(for: .add, size: DesignTokens.PanelSize.add),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onBackdropTap: addSoftDismiss,
                             onExpansionChange: setMorphBackdropExpanded) {
                CreationFlow(start: CreationFlow.Start(ui.creationEntry),
                             onClose: {
                                 addSoftDismiss = nil
                                 ui.creationPrefillSpec = nil
                                 ui.creationEditSnapshot = nil
                                 ui.creationReturnEntry = nil
                                 ui.requestMorphClose(.add)
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                                     ui.advancePrefillQueue()
                                 }
                             },
                             prefill: ui.creationPrefillSpec,
                             editSnapshot: ui.creationEditSnapshot,
                             searchQuery: ui.creationSearchQuery,
                             returnEntry: ui.creationReturnEntry,
                             onSoftDismissChange: { addSoftDismiss = $0 })
                    .id(ui.creationRequestToken)
            }
        }
    }

    @ViewBuilder
    private var updatesMorphLayer: some View {
        if ui.activeMorph == .updates {
            MorphingExpander(isPresented: morphBinding(.updates),
                             originFrame: slots[.updates] ?? .zero,
                             target: toolbarMorphTarget(for: .updates, size: DesignTokens.PanelSize.images),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
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
            MorphingSingleSurfaceExpander(isPresented: toolbarImageDetailBinding,
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
        if ui.activeMorph == .activity {
            MorphingExpander(isPresented: morphBinding(.activity),
                             originFrame: slots[.activity] ?? .zero,
                             target: toolbarMorphTarget(for: .activity, size: DesignTokens.PanelSize.activity),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarActivityPanel {
                    ui.requestMorphClose(.activity)
                }
            }
        }
    }

    @ViewBuilder
    private var templatesMorphLayer: some View {
        if ui.activeMorph == .templates {
            MorphingExpander(isPresented: morphBinding(.templates),
                             originFrame: slots[.templates] ?? .zero,
                             target: toolbarMorphTarget(for: .templates, size: DesignTokens.PanelSize.templates),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarTemplatesPanel {
                    ui.requestMorphClose(.templates)
                }
            }
        }
    }

    @ViewBuilder
    private var systemMorphLayer: some View {
        if ui.activeMorph == .system {
            MorphingExpander(isPresented: morphBinding(.system),
                             originFrame: slots[.system] ?? .zero,
                             target: toolbarMorphTarget(for: .system, size: DesignTokens.PanelSize.system),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarSystemPanel { ui.requestMorphClose(.system) }
            }
        }
    }

    @ViewBuilder
    private var settingsMorphLayer: some View {
        if ui.activeMorph == .settings {
            MorphingExpander(isPresented: morphBinding(.settings),
                             originFrame: slots[.settings] ?? .zero,
                             target: toolbarMorphTarget(for: .settings, size: DesignTokens.PanelSize.settings),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarSettingsPanel { ui.requestMorphClose(.settings) }
            }
        }
    }

    private var addMorphBinding: Binding<Bool> {
        Binding(get: { ui.activeMorph == .add }, set: {
            if !$0 { addSoftDismiss = nil; ui.activeMorph = nil }
        })
    }

    private func morphBinding(_ morph: UIState.ToolbarMorph) -> Binding<Bool> {
        Binding(get: { ui.activeMorph == morph }, set: {
            if !$0 { ui.activeMorph = nil }
        })
    }

    private var paletteMorphBinding: Binding<Bool> {
        Binding(get: { ui.activeMorph == .palette }, set: {
            if !$0 {
                ui.searchText = ""
                ui.paletteScope = nil
                ui.activeMorph = nil
            }
        })
    }

    private func backdropTapped() {
        if ui.activeMorph == .add, let addSoftDismiss {
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
        MorphSourceFrameReader<UIState.ToolbarMorph>(morphs, coordinateSpaceName: Self.space)
    }

    private func singleSlotReader(_ morph: UIState.ToolbarMorph) -> some View {
        MorphSourceFrameReader(morph, coordinateSpaceName: Self.space)
    }

    /// Safe area for a morph panel. Bottom-row panels clear the top toolbar; top-row panels clear the
    /// bottom. Settings is special: it grows from the vanity slot behind the traffic lights and must
    /// clear *both* bands so the panel starts fully below the native titlebar chrome.
    private func toolbarMorphSafeArea(for morph: UIState.ToolbarMorph) -> MorphSafeAreaPolicy {
        switch morph {
        case .settings: MorphSafeAreaPolicy(excluding: .both, padding: .small)
        case .palette:  MorphSafeAreaPolicy(excluding: .bottom, padding: .small)
        default:        MorphSafeAreaPolicy(excluding: .top, padding: .small)
        }
    }

    private func toolbarMorphTarget(for morph: UIState.ToolbarMorph,
                                    size: CGSize,
                                    placement: MorphPanelPlacement = .anchored) -> MorphTarget {
        let safeArea = toolbarMorphSafeArea(for: morph)
        switch placement {
        case .anchored:
            return .anchored(size: size, safeArea: safeArea, margin: 0)
        case .centered:
            return .centered(size: size, safeArea: safeArea, margin: 0)
        }
    }

    private var rowTopInset: CGFloat { DesignTokens.Toolbar.topPadding }

    private var bottomRowInset: CGFloat {
        max(DesignTokens.Toolbar.outerPadding, safeAreas.system.bottom + DesignTokens.Toolbar.outerPadding)
    }

    private var systemStatusColor: Color {
        switch app.serviceLabel {
        case "Running":
            .green
        case "Checking…":
            .blue
        case "Stopped":
            .orange
        default:
            .red
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
        switch ui.activeMorph {
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
        DesignTokens.PanelSize.imageDetail
    }

    private func currentToolbarImageGroup(_ group: LocalImageTagGroup) -> LocalImageTagGroup {
        app.localImageGroups().first { $0.id == group.id } ?? group
    }

    private func openToolbarImageDetail(_ group: LocalImageTagGroup, sourceFrame: CGRect) {
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
/// events; plain otherwise. Owns its own `@Query` so the badge updates live as events land.
private struct ActivityToolbarButton: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Query(filter: #Predicate<EventRecord> { !$0.isRead }) private var unread: [EventRecord]

    var body: some View {
        let count = unread.count
        let hasUnread = count > 0
        return DesignActionItems([
            DesignAction(systemName: hasUnread ? "bell.fill" : "bell",
                         help: hasUnread ? "Activity — \(count) unread" : "Activity",
                         tint: hasUnread ? app.settings.accentTint.color : .white) {
                                   if ui.panelNavigationEnabled {
                                       ui.toggleMorph(.activity)
                                   } else {
                                       ui.navigate(to: .activity)
                                   }
            }
        ])
    }
}
