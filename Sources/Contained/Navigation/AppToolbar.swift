import SwiftUI
import SwiftData
import AppKit
import ContainedCore

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Search stays in the top-right titlebar band; the add/images/templates/activity cluster and
/// system status control float in a bottom toolbar area.
///
/// Mounted as a top overlay in `RootView`: the band sits in the title-bar region, and the rest of the
/// area is hit-transparent until a control opens.
/// The add `+`, search field, and bottom toolbar controls all grow through the same
/// `MorphingExpander` shell from their measured toolbar slots. Control sizing and source radius come
/// from `Tokens.Toolbar` / `ToolbarControls`.
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.appSafeAreas) private var safeAreas

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?
    @State private var toolbarImageDetail: LocalImageTagGroup?
    @State private var toolbarImageSourceFrame: CGRect?
    @State private var toolbarImageDetailPresented = false
    @State private var toolbarImageCloseRequestToken = 0
    @State private var morphBackdropExpanded = false

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding. Sourced from `Tokens.Toolbar` so the band, the safe-area
    /// manager, and the controls all agree.
    static let bandHeight: CGFloat = Tokens.Toolbar.band

    var body: some View {
        ZStack(alignment: .top) {
            morphBackdropLayer
                .zIndex(40)
            VStack(spacing: 0) {
                topToolbarRow
                    .frame(height: Tokens.Toolbar.controlHeight)
                    .padding(.top, rowTopInset)   // centered on the traffic-light line
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                bottomToolbarRow
                    .frame(height: Tokens.Toolbar.controlHeight)
                    .padding(.bottom, bottomRowInset)
            }
            // Toolbar controls sit above the morph dim/blur backdrop so they stay crisp while a panel
            // is open. The active panel itself is layered above the controls, so expanded content never
            // tucks under the toolbar bands.
            .zIndex(100)
            addMorphLayer
                .zIndex(ui.activeMorph == .add ? 150 : 0)
            paletteMorphLayer
                .zIndex(ui.activeMorph == .palette ? 150 : 0)
            updatesMorphLayer
                .zIndex(ui.activeMorph == .updates ? 150 : 0)
            activityMorphLayer
                .zIndex(ui.activeMorph == .activity ? 150 : 0)
            templatesMorphLayer
                .zIndex(ui.activeMorph == .templates ? 150 : 0)
            systemMorphLayer
                .zIndex(ui.activeMorph == .system ? 150 : 0)
            settingsMorphLayer
                .zIndex(ui.activeMorph == .settings ? 150 : 0)
            toolbarImageDetailLayer
                .zIndex(toolbarImageDetail == nil ? 0 : 170)
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(ToolbarSlotKey.self) { slots = $0 }
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
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            settingsZone
            Spacer(minLength: Tokens.Space.m)
            searchZone
        }
        // No leading inset here — the Settings button sits at the window edge, behind the traffic lights.
        .padding(.leading, Tokens.Toolbar.outerPadding)
        .padding(.trailing, Tokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    /// Top-left empty glass container mirroring the traffic-light cluster width. It has no controls —
    /// it's vanity chrome that owns the `.settings` morph slot so the Settings panel (opened via ⌘, or
    /// the menu) has a frame to grow from.
    private var settingsZone: some View {
        // The same GlassButton container as the other toolbar controls (for consistency), but empty and
        // non-interactive — vanity chrome and a stable morph origin, sized by a min width.
        GlassButton(minWidth: Tokens.Toolbar.trafficLightsWidth, singleItem: true, interactive: false) {
            Color.clear
        }
        .fixedSize(horizontal: true, vertical: false)
        .opacity(ui.activeMorph == .settings ? 0 : 1)
        .background(singleSlotReader(.settings))
    }

    private var searchZone: some View {
        ToolbarSearchSource()
            .frame(width: Tokens.Toolbar.searchMaxWidth, height: Tokens.Toolbar.controlHeight)
            .opacity(ui.activeMorph == .palette ? 0 : 1)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ToolbarSlotKey.self,
                                           value: [.palette: proxy.frame(in: .named(Self.space))])
                }
            )
    }

    @ViewBuilder
    private var paletteMorphLayer: some View {
        if ui.activeMorph == .palette {
            MorphingExpander(isPresented: paletteMorphBinding,
                             originFrame: slots[.palette] ?? .zero,
                             target: toolbarMorphTarget(for: .palette, size: Tokens.PanelSize.palette),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarCommandPalette { ui.requestMorphClose(.palette) }
            }
        }
    }

    // MARK: Bottom Row

    private var bottomToolbarRow: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            systemStatusButton
            Spacer(minLength: Tokens.Space.m)
            bottomActionGroup
        }
        .padding(.horizontal, Tokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    private var systemStatusButton: some View {
        GlassButton(singleItem: true) {
            GlassButtonItem(help: "System \(app.serviceLabel)", action: {
                ui.toggleMorph(.system)
            }) {
                HStack(spacing: Tokens.Toolbar.searchIconGap) {
                    Image(systemName: systemStatusIcon)
                        .foregroundStyle(systemStatusColor)
                        .frame(width: Tokens.Toolbar.buttonItemHeight - Tokens.Toolbar.iconInnerPadding * 2)
                    Text(app.serviceLabel)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, Tokens.Toolbar.iconInnerPadding * 2)
                }
            }
        }
        .opacity(ui.activeMorph == .system ? 0 : 1)
        .background(singleSlotReader(.system))
    }

    private var bottomActionGroup: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            GlassButton {
                GlassButtonItem(systemName: "plus", help: "Add") { ui.openCreationPanel() }
                GlassButtonItem(systemName: "shippingbox", help: "Images") { ui.toggleMorph(.updates) }
                GlassButtonItem(systemName: "bookmark", help: "Templates") { ui.toggleMorph(.templates) }
                GlassButtonItem(systemName: "bell", help: "Activity") { ui.toggleMorph(.activity) }
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
                             target: toolbarMorphTarget(for: .add, size: Tokens.PanelSize.add),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onBackdropTap: addSoftDismiss,
                             onExpansionChange: setMorphBackdropExpanded) {
                CreationFlow(start: CreationFlow.Start(ui.creationEntry),
                             onClose: {
                                 addSoftDismiss = nil
                                 ui.creationPrefillSpec = nil
                                 ui.creationEditSnapshot = nil
                                 ui.requestMorphClose(.add)
                             },
                             prefill: ui.creationPrefillSpec,
                             editSnapshot: ui.creationEditSnapshot,
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
                             target: toolbarMorphTarget(for: .updates, size: Tokens.PanelSize.updatesOrigin),
                             showsBackdrop: false,
                             closeRequestToken: ui.morphCloseRequestToken,
                             onExpansionChange: setMorphBackdropExpanded) {
                ToolbarUpdatesPanel(onOpenImage: openToolbarImageDetail) {
                    ui.requestMorphClose(.updates)
                }
            }
        }
    }

    @ViewBuilder
    private var toolbarImageDetailLayer: some View {
        if let detail = toolbarImageDetail, toolbarImageDetailPresented {
            MorphingExpander(isPresented: toolbarImageDetailBinding,
                             originFrame: usableToolbarImageSource ?? .zero,
                             target: .anchored(size: toolbarImageDetailSize,
                                               safeArea: toolbarMorphSafeArea(for: .updates),
                                               margin: 0),
                             showsBackdrop: false,
                             closeRequestToken: toolbarImageCloseRequestToken) {
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
                             target: toolbarMorphTarget(for: .activity, size: Tokens.PanelSize.activityOrigin),
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
                             target: toolbarMorphTarget(for: .templates, size: Tokens.PanelSize.templatesOrigin),
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
                             target: toolbarMorphTarget(for: .system, size: Tokens.PanelSize.system),
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
                             target: toolbarMorphTarget(for: .settings, size: Tokens.PanelSize.settings),
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
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(Self.space))
            Color.clear.preference(key: ToolbarSlotKey.self,
                                   value: Dictionary(uniqueKeysWithValues: morphs.map { ($0, frame) }))
        }
    }

    private func singleSlotReader(_ morph: UIState.ToolbarMorph) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ToolbarSlotKey.self,
                                   value: [morph: proxy.frame(in: .named(Self.space))])
        }
    }

    /// Safe area for a morph panel. Bottom-row panels clear the top toolbar; top-row panels (palette)
    /// clear the bottom. Settings is special: it grows from the top-left slot (behind traffic lights)
    /// and must clear *both* bands so the panel starts fully below the native titlebar chrome.
    private func toolbarMorphSafeArea(for morph: UIState.ToolbarMorph) -> AppSafeAreaPolicy {
        switch morph {
        case .settings: AppSafeAreaPolicy(excluding: .both, padding: .small)
        case .palette:  AppSafeAreaPolicy(excluding: .bottom, padding: .small)
        default:        AppSafeAreaPolicy(excluding: .top, padding: .small)
        }
    }

    private func toolbarMorphTarget(for morph: UIState.ToolbarMorph,
                                    size: CGSize,
                                    placement: MorphPanelPlacement = .anchored) -> AppMorphTarget {
        let safeArea = toolbarMorphSafeArea(for: morph)
        switch placement {
        case .anchored:
            return .anchored(size: size, safeArea: safeArea, margin: 0)
        case .centered:
            return .centered(size: size, safeArea: safeArea, margin: 0)
        }
    }

    private var rowTopInset: CGFloat { Tokens.Toolbar.topPadding }

    private var bottomRowInset: CGFloat {
        max(Tokens.Toolbar.outerPadding, safeAreas.system.bottom + Tokens.Toolbar.outerPadding)
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
        Tokens.PanelSize.imageDetail
    }

    private func currentToolbarImageGroup(_ group: LocalImageTagGroup) -> LocalImageTagGroup {
        LocalImageTagGroup.groups(for: app.images).first { $0.id == group.id } ?? group
    }

    private func openToolbarImageDetail(_ group: LocalImageTagGroup, sourceFrame: CGRect) {
        toolbarImageDetail = group
        toolbarImageSourceFrame = sourceFrame
        toolbarImageDetailPresented = true
    }

    private func closeToolbarImageDetail() {
        toolbarImageCloseRequestToken &+= 1
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
private struct ToolbarSlotKey: PreferenceKey {
    static let defaultValue: [UIState.ToolbarMorph: CGRect] = [:]
    static func reduce(value: inout [UIState.ToolbarMorph: CGRect],
                       nextValue: () -> [UIState.ToolbarMorph: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
