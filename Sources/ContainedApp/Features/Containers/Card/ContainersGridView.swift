import SwiftUI
import ContainedUX
import ContainedUI
import ContainedCore

/// The Containers screen: a responsive grid of personalized glass cards. Density and the running
/// filter live in the background context menu and menu commands; tapping a card grows it in place
/// into a centered detail panel.
struct ContainersGridView: View {
    private struct DetailSource: Equatable {
        let snapshot: Core.Container.Snapshot
        let placement: ContainerGridCardPlacement
    }

    private struct RebuildRequest: Identifiable {
        let snapshot: Core.Container.Snapshot
        let updateState: Core.Image.ContainerUpdateState

        var id: String { snapshot.scopedID }
        var isUpdate: Bool { updateState.requiresUpdate }
    }

    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.morphSafeAreaManager) private var safeAreaManager

    @State private var detail: DetailSource?
    @State private var deleting: Core.Container.Snapshot?
    @State private var rebuilding: RebuildRequest?
    @State private var selecting = false
    @State private var selection: Set<String> = []
    /// Drives the in-place grow: false = card sits in its grid slot, true = promoted to the centered
    /// panel. A single spring on this flag owns the whole motion (no matchedGeometry to fight).
    @State private var expanded = false
    @State private var lifecycleFeedback = 0
    @State private var pendingDetail: DetailSource?
    @State private var detailSourceFrame: CGRect?
    @State private var projectionState = ContainerGridProjectionState()
    @State private var selectedWidgetIndices: [String: Int] = [:]

    // Each network is a collapsible section of the containers attached to it.
    @State private var collapsedNetworks: Set<String> = []
    @State private var deletingNetwork: Core.Network.Resource?

    private let detailSpring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    private var store: ContainersStore { app.containers }

    private var projectionInput: ContainerGridProjection.Input {
        ContainerGridProjection.Input(snapshots: store.snapshots,
                                      networks: app.networks,
                                      grouping: ui.grouping,
                                      sort: ui.sort,
                                      runningOnly: ui.runningOnly,
                                      search: ui.search.text)
    }

    private var projectionKey: ContainerGridProjectionKey {
        ContainerGridProjectionKey(inventoryRevision: store.inventoryRevision,
                                   networksRevision: app.networksRevision,
                                   grouping: ui.grouping,
                                   sort: ui.sort,
                                   runningOnly: ui.runningOnly,
                                   search: ui.search.text)
    }

    var body: some View {
        @Bindable var ui = ui
        return GeometryReader { viewport in
            let scrollBounds = safeAreaManager.bounds(in: viewport.size, policy: .content)
            let gridColumns = UI.Card.Grid.stableColumns(
                availableWidth: viewport.size.width - (UI.Layout.Spacing.l * 2),
                spacing: UI.Layout.Spacing.m
            )
            ZStack {
                ScrollView {
                    ZStack(alignment: .top) {
                        // Background sibling (behind the cards): double-click empty space to zoom the
                        // window. As a sibling — not an ancestor — of the cards, it never delays or
                        // intercepts their taps; only clicks that fall through the gaps reach it.
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: scrollBounds.height)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { zoomFrontWindow() }
                        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
                            ForEach(projectionState.projection.groups) { group in
                                groupSection(group, columns: gridColumns)
                            }
                            Color.clear
                                .frame(height: UI.Toolbar.Size.band)
                        }
                        .padding(.horizontal, UI.Layout.Spacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentMargins(.top, ui.toolbarUIEnabled ? 0 : UI.Toolbar.Size.band, for: .scrollContent)

                if detail != nil {
                    Color.clear
                        .globalBackdrop(style: .blur, progress: expanded ? 1 : 0)
                        .contentShape(Rectangle())
                        .onTapGesture { closeDetail() }
                        .zIndex(5)
                }

                if let detail {
                    let target = cardDetailTarget.rect(origin: .zero,
                                                       in: viewport.size,
                                                       safeAreaManager: cardDetailSafeAreaManager)
                    let source = detailSourceFrame.flatMap { $0.isUsableForMorph ? $0 : nil } ?? target
                    UX.Morph.SingleSurface(source: source,
                                           target: target,
                                           progress: expanded ? 1 : 0) {
                        expandedCard(detail.snapshot)
                    }
                        .zIndex(10)
                }
            }
            .coordinateSpace(.named("grid"))
        }
        .overlay(alignment: .bottom) {
            if selecting && !selection.isEmpty { batchBar } else if let message = store.errorMessage { UI.State.ErrorBanner(message: message) }
        }
        .overlay {
            if store.snapshots.isEmpty && app.networks.isEmpty { emptyState }
        }
        .confirmationDialog(
            "Delete \(customizeName(deleting))?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = deleting?.scopedID { Task { await store.remove(id, force: true) } }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("This removes the container. This can't be undone.")
        }
        .confirmationDialog(
            rebuildConfirmationTitle,
            isPresented: Binding(get: { rebuilding != nil }, set: { if !$0 { rebuilding = nil } }),
            presenting: rebuilding
        ) { request in
            Button(request.isUpdate ? AppText.updateContainer : AppText.rebuildContainer, role: .destructive) {
                applyRebuild(request)
            }
            Button("Cancel", role: .cancel) { rebuilding = nil }
        } message: { request in
            Text(request.isUpdate ? AppText.updateContainerConfirmation : AppText.rebuildContainerConfirmation)
        }
        // Network-level actions.
        .task { await app.refreshNetworks() }
        .confirmationDialog("Delete network \(deletingNetwork?.name ?? "")?",
                            isPresented: deleteNetworkBinding, presenting: deletingNetwork) { network in
            Button("Delete", role: .destructive) { Task { await deleteNetwork(network) } }
        } message: { _ in Text("This removes the network. Containers must be detached first.") }
        .refreshable { await store.refresh() }
        .task(id: projectionKey) { await projectionState.update(projectionInput) }
        .sensoryFeedback(.success, trigger: lifecycleFeedback)
        // Report the in-page search count so the toolbar can escalate an empty search into the palette.
        .onAppear { ui.search.pageResultCount = projectionState.projection.visibleCount }
        .onChange(of: projectionState.projection.visibleCount) { _, count in ui.search.pageResultCount = count }
        .onChange(of: store.snapshots.map(\.scopedID)) { _, ids in
            selectedWidgetIndices = selectedWidgetIndices.filter { ids.contains($0.key) }
            if let focusedID = detail?.snapshot.scopedID ?? pendingDetail?.snapshot.scopedID,
               !ids.contains(focusedID) {
                // The overlay remains usable if a refresh removes its source card, but its close
                // animation must fall back to the centered target instead of a stale grid frame.
                detailSourceFrame = nil
                if pendingDetail != nil { pendingDetail = nil }
            }
        }
    }

    // MARK: - Network sections

    @ViewBuilder
    private func groupSection(_ group: ContainerGridProjection.Group,
                              columns: [GridItem]) -> some View {
        let collapsed = collapsedNetworks.contains(group.name)
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
            sectionHeader(group, collapsed: collapsed)
            if !collapsed {
                if group.containers.isEmpty {
                    UI.State.Empty(ui.grouping == .network ? "No containers on this network." : "No containers.",
                                     systemImage: group.symbol,
                                     tone: .tertiary,
                                     padding: UI.Layout.Spacing.s)
                } else {
                    LazyVGrid(columns: columns, spacing: UI.Layout.Spacing.m) {
                        ForEach(group.containers, id: \.scopedID) { snapshot in
                            gridCard(snapshot, placement: .init(groupID: group.id, snapshot: snapshot))
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ group: ContainerGridProjection.Group, collapsed: Bool) -> some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            Button {
                toggleCollapsed(group.name)
            } label: {
                UI.Symbol.Image(systemName: "chevron.right", size: .caption)
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
            }
            .buttonStyle(.plain)
            UI.Symbol.Image(systemName: group.symbol)
            Text(group.name).designHeadlineLabelStyle()
            UI.Badge.Text(text: "\(group.containers.count)")
            if group.isBuiltin {
                UI.Badge.Text(text: "builtin", font: .caption2.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, UI.Layout.Spacing.xs)
        .padding(.vertical, UI.Layout.Spacing.xs)
        .contextMenu { if let resource = group.resource { networkMenu(resource) } }
    }

    @ViewBuilder
    private func networkMenu(_ resource: Core.Network.Resource) -> some View {
        UI.Copy.ValueLabel("Copy Name", value: resource.name)
        if !resource.isBuiltin {
            Divider()
            Button(role: .destructive) { deletingNetwork = resource } label: { Label("Delete Network", systemImage: "trash") }
        }
    }

    private func toggleCollapsed(_ name: String) {
        if collapsedNetworks.contains(name) { collapsedNetworks.remove(name) } else { collapsedNetworks.insert(name) }
    }

    /// Zoom (fill/restore) the window — the title-bar gesture, relocated to the empty background.
    private func zoomFrontWindow() {
        Platform.zoomFrontWindow()
    }

    private var deleteNetworkBinding: Binding<Bool> {
        Binding(get: { deletingNetwork != nil }, set: { if !$0 { deletingNetwork = nil } })
    }

    private func deleteNetwork(_ network: Core.Network.Resource) async {
        guard let client = app.client else { return }
        do {
            _ = try await client.deleteNetworks([network.name], runtimeKind: network.runtimeKind)
            await app.refreshNetworks()
        }
        catch let error as Core.Command.Error { app.flash(error.appDisplayMessage) }
        catch { app.flash(error.appDisplayMessage) }
    }

    @ViewBuilder
    private func gridCard(_ snapshot: Core.Container.Snapshot,
                          placement: ContainerGridCardPlacement) -> some View {
        let selected = detail?.placement == placement
        let measuresSource = selected || pendingDetail?.placement == placement
        compactCard(snapshot, placement: placement)
            // Stays laid out (so the slot is reserved and its frame keeps publishing) but invisible
            // while the promoted overlay grows out of it — no second card to see double.
            .opacity(selected ? 0 : 1)
            .allowsHitTesting(detail == nil && pendingDetail == nil)
            .background {
                if measuresSource {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                updateDetailSource(proxy.frame(in: .named("grid")),
                                                   snapshot: snapshot,
                                                   placement: placement)
                            }
                            .onChange(of: proxy.frame(in: .named("grid"))) { _, frame in
                                updateDetailSource(frame, snapshot: snapshot, placement: placement)
                            }
                    }
                }
            }
    }

    private func updateDetailSource(_ frame: CGRect,
                                    snapshot: Core.Container.Snapshot,
                                    placement: ContainerGridCardPlacement) {
        guard frame.isUsableForMorph else { return }
        guard pendingDetail?.placement == placement || detail?.placement == placement else { return }
        if detailSourceFrame?.isClose(to: frame) != true { detailSourceFrame = frame }
        guard detail == nil, pendingDetail?.placement == placement else { return }
        pendingDetail = nil
        detail = DetailSource(snapshot: snapshot, placement: placement)
        expanded = false
        DispatchQueue.main.async {
            withAnimation(detailSpring) { expanded = true }
        }
    }

    private func compactCard(_ snapshot: Core.Container.Snapshot,
                             placement: ContainerGridCardPlacement) -> some View {
        containerCard(snapshot, isExpanded: false) {
            selecting ? toggle(snapshot.scopedID) : openDetail(snapshot, placement: placement)
        }
    }

    private func expandedCard(_ snapshot: Core.Container.Snapshot) -> some View {
        // `controlsVisible: expanded` so the footer buttons + close fade out as soon as a close
        // starts (expanded → false), finishing before the shrink animation does.
        containerCard(snapshot,
                      isExpanded: true,
                      cornerRadiusOverride: expanded ? UI.Card.Radius.expanded : UI.Card.Radius.container,
                      controlsVisible: expanded) {}
    }

    private func containerCard(_ snapshot: Core.Container.Snapshot, isExpanded: Bool,
                               cornerRadiusOverride: CGFloat? = nil,
                               controlsVisible: Bool = true,
                               onTap: @escaping () -> Void) -> some View {
        let style = app.containerStyle(for: snapshot)
        let key = snapshot.scopedID
        let hasStyleOverride = app.personalization.hasOverride(id: key)
        let imageUpdateState = app.containerImageUpdateState(for: snapshot)
        return ContainerCardMetricsRenderer(
            metrics: store.metricsState(for: key),
            snapshot: snapshot,
            style: style,
            hasStyleOverride: hasStyleOverride,
            density: app.settings.density,
            statsNormalization: app.statsNormalizationContext,
            selectedWidgetIndex: selectedWidgetBinding(for: key),
            isBusy: store.busyIDs.contains(key),
            imageUpdateState: imageUpdateState,
            isExpanded: isExpanded,
            cornerRadiusOverride: cornerRadiusOverride,
            controlsVisible: controlsVisible,
            onTap: onTap,
            onStart: { lifecycleAction { await store.start(key) } },
            onStop: { lifecycleAction { await store.stop(key) } },
            onRestart: { lifecycleAction { await store.restart(key) } },
            onEdit: { ui.openCreationPanel(editing: snapshot) },
            onRebuild: { rebuilding = RebuildRequest(snapshot: snapshot, updateState: imageUpdateState) },
            onDelete: { deleting = snapshot },
            onClose: closeDetail,
            onSelectMultiple: { beginSelecting(key) },
            onToggleSelected: { toggle(key) },
            onEndSelecting: { endSelecting() },
            health: app.health.status(for: key),
            selecting: selecting,
            isSelected: selection.contains(key)
        )
    }

    private func selectedWidgetBinding(for id: String) -> Binding<Int> {
        Binding {
            selectedWidgetIndices[id] ?? 0
        } set: { index in
            selectedWidgetIndices[id] = index
        }
    }

    private var cardDetailTarget: UX.Morph.Target {
        .centered(safeArea: cardDetailSafeAreaPolicy, margin: 0) { bounds in
            panelSize(in: bounds.size)
        }
    }

    private var cardDetailSafeAreaPolicy: UX.SafeArea.Policy {
        let toolbarExclusion: UX.SafeArea.ToolbarExclusion = ui.toolbarUIEnabled ? .bottom : .both
        return UX.SafeArea.Policy(excluding: toolbarExclusion, padding: .none, includesSystemInsets: false)
    }

    private var cardDetailSafeAreaManager: UX.SafeArea.Manager {
        guard ui.toolbarUIEnabled else { return safeAreaManager }
        return UX.SafeArea.Manager(system: safeAreaManager.system,
                                  topToolbarHeight: AppToolbar.bandHeight,
                                  bottomToolbarHeight: AppToolbar.bandHeight)
    }

    private func panelSize(in available: CGSize) -> CGSize {
        let fitted = UX.Morph.Geometry.fittedSize(
            CGSize(width: max(available.width * 0.62, 680), height: 620),
            in: available,
            margin: 0
        )
        let width = max(min(fitted.width, available.width), min(360, fitted.width))
        let height = fitted.height
        return CGSize(width: width, height: height)
    }

    private func openDetail(_ snapshot: Core.Container.Snapshot,
                            placement: ContainerGridCardPlacement) {
        guard detail == nil, pendingDetail == nil else { return }
        // Attach geometry only to the tapped card. Its first measurement promotes the card into the
        // overlay, eliminating continuous frame publication from every visible grid item.
        pendingDetail = DetailSource(snapshot: snapshot, placement: placement)
        detailSourceFrame = nil
        expanded = false
    }

    private func closeDetail() {
        withAnimation(detailSpring) { expanded = false } completion: {
            detail = nil
            detailSourceFrame = nil
        }
    }

    private var batchBar: some View {
        UI.Action.SelectionBar(count: selection.count,
                                 countLabel: AppText.selectedCount,
                                 actions: [
            UI.Action.Item(systemName: "play.fill", title: AppText.start) {
                batch { await store.start($0) }
            },
            UI.Action.Item(systemName: "stop.fill", title: AppText.stop) {
                batch { await store.stop($0) }
            },
            UI.Action.Item(systemName: "trash", title: AppText.delete, role: .destructive) {
                batch { await store.remove($0, force: true) }
            }
        ])
        .padding(.bottom, UI.Layout.Spacing.l)
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func beginSelecting(_ id: String) {
        selecting = true
        selection = [id]
    }

    private func endSelecting() {
        selection.removeAll()
        selecting = false
    }

    /// Run an action over every selected container, then exit selection mode.
    private func batch(_ action: @escaping (String) async -> Void) {
        let ids = selection
        Task {
            for id in ids { await action(id) }
            endSelecting()
            lifecycleFeedback &+= 1
        }
    }

    private func lifecycleAction(_ action: @escaping () async -> Void) {
        Task {
            await action()
            lifecycleFeedback &+= 1
        }
    }

    private var rebuildConfirmationTitle: String {
        guard let rebuilding else { return AppText.rebuildContainer }
        let name = app.containerStyle(for: rebuilding.snapshot)
            .displayName(fallback: rebuilding.snapshot.id)
        return rebuilding.isUpdate
            ? AppText.updateContainerTitle(name)
            : AppText.rebuildContainerTitle(name)
    }

    private func applyRebuild(_ request: RebuildRequest) {
        rebuilding = nil
        if detail?.snapshot.scopedID == request.snapshot.scopedID {
            closeDetail()
        }
        Task {
            if await app.rebuildContainer(request.snapshot) {
                lifecycleFeedback &+= 1
            }
        }
    }

    private func customizeName(_ snapshot: Core.Container.Snapshot?) -> String {
        guard let snapshot else { return "" }
        return app.containerStyle(for: snapshot)
            .displayName(fallback: snapshot.id)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: UI.Layout.Spacing.m) {
            UI.State.Empty(AppText.string("containers.empty", defaultValue: "No containers"),
                             systemImage: "shippingbox",
                             description: ui.runningOnly
                                ? AppText.string("containers.empty.runningOnly", defaultValue: "No running containers.")
                                : AppText.string("containers.empty.description", defaultValue: "Run a container to see it here."),
                             padding: 0)
            UI.Action.TextButton(title: AppText.string("containers.empty.run", defaultValue: "Run a container"),
                                   systemName: "plus",
                                   prominence: .prominent) {
                ui.openCreationPanel(entry: .chooser)
            }
        }
    }
}

private struct ContainerGridProjectionKey: Hashable {
    let inventoryRevision: Int
    let networksRevision: Int
    let grouping: ContainerGrouping
    let sort: ContainerSort
    let runningOnly: Bool
    let search: String
}

private struct ContainerCardMetricsRenderer: View {
    let metrics: ContainerMetricsState
    let snapshot: Core.Container.Snapshot
    let style: Personalization
    let hasStyleOverride: Bool
    let density: UI.Card.Density
    let statsNormalization: Core.Metrics.NormalizationContext
    let selectedWidgetIndex: Binding<Int>
    let isBusy: Bool
    let imageUpdateState: Core.Image.ContainerUpdateState
    let isExpanded: Bool
    let cornerRadiusOverride: CGFloat?
    let controlsVisible: Bool
    let onTap: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onEdit: () -> Void
    let onRebuild: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    let onSelectMultiple: () -> Void
    let onToggleSelected: () -> Void
    let onEndSelecting: () -> Void
    let health: Core.Container.HealthStatus
    let selecting: Bool
    let isSelected: Bool

    var body: some View {
        ContainerCard(
            snapshot: snapshot,
            style: style,
            hasStyleOverride: hasStyleOverride,
            density: density,
            stats: metrics.stats,
            statsNormalization: statsNormalization,
            histories: metrics.historyByMetric,
            isBusy: isBusy,
            imageUpdateState: imageUpdateState,
            isExpanded: isExpanded,
            cornerRadiusOverride: cornerRadiusOverride,
            controlsVisible: controlsVisible,
            onTap: onTap,
            onStart: onStart,
            onStop: onStop,
            onRestart: onRestart,
            onEdit: onEdit,
            onRebuild: onRebuild,
            onDelete: onDelete,
            onClose: onClose,
            onSelectMultiple: onSelectMultiple,
            onToggleSelected: onToggleSelected,
            onEndSelecting: onEndSelecting,
            health: health,
            selecting: selecting,
            isSelected: isSelected,
            selectedWidgetIndex: selectedWidgetIndex
        )
    }
}

private extension CGRect {
    func isClose(to other: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(minX - other.minX) <= tolerance &&
        abs(minY - other.minY) <= tolerance &&
        abs(width - other.width) <= tolerance &&
        abs(height - other.height) <= tolerance
    }
}

#Preview("Containers Grid Fake Dataset") {
    ContainersGridFakeDatasetPreview()
}

@MainActor
private struct ContainersGridFakeDatasetPreview: View {
    @State private var app: AppModel
    @State private var ui: UIState

    init() {
        let preview = ContainersGridPreviewDataset.make()
        _app = State(initialValue: preview.app)
        _ui = State(initialValue: preview.ui)
    }

    var body: some View {
        ContainersGridView()
            .environment(app)
            .environment(ui)
            .environment(\.morphSafeAreaManager,
                          UX.SafeArea.Manager(topToolbarHeight: UI.Toolbar.Size.band,
                                              bottomToolbarHeight: UI.Toolbar.Size.band))
            .frame(width: 900, height: 640)
    }
}

@MainActor
private enum ContainersGridPreviewDataset {
    static func make() -> (app: AppModel, ui: UIState) {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let app = AppModel(database: database)
        let ui = UIState()
        ui.grouping = .flat
        ui.sort = .name
        ui.toolbarUIEnabled = true

        let appleWeb = Core.Container.Snapshot.placeholder(
            id: "preview-web",
            image: "docker.io/library/nginx:latest",
            state: .running,
            runtimeKind: .appleContainer
        )
        let dockerWeb = Core.Container.Snapshot.placeholder(
            id: "preview-web",
            image: "docker.io/library/nginx:latest",
            state: .running,
            runtimeKind: .docker
        )
        let worker = Core.Container.Snapshot.placeholder(
            id: "preview-worker",
            image: "ghcr.io/example/worker:nightly",
            state: .stopped,
            runtimeKind: .docker
        )
        let db = Core.Container.Snapshot.placeholder(
            id: "preview-db",
            image: "postgres:16",
            state: .running,
            runtimeKind: .appleContainer
        )

        let snapshots = [appleWeb, dockerWeb, worker, db]
        app.containers.snapshots = snapshots
        for snapshot in snapshots {
            app.containers.statsByID[snapshot.scopedID] = Core.Metrics.StatsDelta.sample(id: snapshot.scopedID)
            app.containers.historyByID[snapshot.scopedID] = [
                .cpu: buffer([0.14, 0.22, 0.18, 0.42, 0.36, 0.62]),
                .memory: buffer([0.28, 0.30, 0.34, 0.38, 0.42, 0.40]),
                .netRx: buffer([0.12, 0.28, 0.20, 0.50, 0.44, 0.58]),
                .netTx: buffer([0.08, 0.10, 0.16, 0.22, 0.18, 0.26]),
            ]
        }

        setStyle(tint: .azure, icon: "globe", nickname: "Apple web", for: appleWeb, app: app)
        setStyle(tint: .teal, icon: "shippingbox.fill", nickname: "Docker web", for: dockerWeb, app: app)
        setStyle(tint: .indigo, icon: "gearshape.2.fill", nickname: "Worker", for: worker, app: app)
        setStyle(tint: .green, icon: "cylinder.split.1x2.fill", nickname: "Database", for: db, app: app)

        return (app, ui)
    }

    private static func buffer(_ values: [Double]) -> UI.Chart.SampleBuffer {
        var buffer = UI.Chart.SampleBuffer(capacity: 24)
        values.forEach { buffer.append($0) }
        return buffer
    }

    private static func setStyle(tint: UI.Theme.Tint,
                                 icon: String,
                                 nickname: String,
                                 for snapshot: Core.Container.Snapshot,
                                 app: AppModel) {
        var style = Personalization()
        style.tint = tint
        style.icon = icon
        style.nickname = nickname
        style.backgroundOpacity = 0.18
        app.personalization.setOverride(style, for: snapshot.scopedID)
    }
}
