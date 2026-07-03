import SwiftUI
import ContainedUX
import ContainedUI
import ContainedCore

/// The Containers screen: a responsive grid of personalized glass cards. Density and the running
/// filter live in the background context menu and menu commands; tapping a card grows it in place
/// into a centered detail panel.
struct ContainersGridView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.morphSafeAreaManager) private var safeAreaManager

    @State private var detail: Core.Container.Snapshot?
    @State private var deleting: Core.Container.Snapshot?
    @State private var selecting = false
    @State private var selection: Set<String> = []
    /// Drives the in-place grow: false = card sits in its grid slot, true = promoted to the centered
    /// panel. A single spring on this flag owns the whole motion (no matchedGeometry to fight).
    @State private var expanded = false
    @State private var lifecycleFeedback = 0
    /// Live frames of every visible grid card (in the "grid" coordinate space) so the promoted card
    /// can start from the exact slot it was tapped in.
    @State private var cardFrames: [String: CGRect] = [:]
    @State private var selectedWidgetIndices: [String: Int] = [:]

    // Each network is a collapsible section of the containers attached to it.
    @State private var collapsedNetworks: Set<String> = []
    @State private var deletingNetwork: Core.Network.Resource?

    private let detailSpring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    private var store: ContainersStore { app.containers }

    /// A bucket of containers under one heading. `resource` is set only for network grouping (so the
    /// section keeps its network context menu); `symbol` drives the section header glyph.
    private struct ContainerGroup: Identifiable {
        let name: String
        let symbol: String
        let resource: Core.Network.Resource?
        let containers: [Core.Container.Snapshot]
        let isBuiltin: Bool
        var id: String { name }
    }

    /// The network names a container is attached to (requested config ∪ runtime status).
    private func networkNames(_ snapshot: Core.Container.Snapshot) -> [String] {
        let names = snapshot.configuration.networks.map(\.network) + snapshot.status.networks.map(\.network)
        return Array(Set(names)).sorted()
    }

    /// Containers bucketed according to the toolbar grouping choice, each bucket sorted by the chosen
    /// sort. Network grouping keeps every known network as a section (empty ones included).
    private var groups: [ContainerGroup] {
        switch ui.grouping {
        case .network: return networkGroups
        case .volume:  return volumeGroups
        case .image:   return imageGroups
        case .flat:    return [ContainerGroup(name: "All containers", symbol: "square.grid.2x2",
                                              resource: nil, containers: sorted(filtered), isBuiltin: false)]
        }
    }

    private var networkGroups: [ContainerGroup] {
        let byNetworkName = Dictionary(app.networks.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let defaultName = app.networks.first { $0.isBuiltin }?.name ?? "default"

        var buckets: [String: [Core.Container.Snapshot]] = [:]
        for network in app.networks { buckets[network.name] = [] }
        buckets[defaultName, default: []] = buckets[defaultName] ?? []

        for snapshot in filtered {
            let names = networkNames(snapshot)
            if names.isEmpty {
                buckets[defaultName, default: []].append(snapshot)
            } else {
                for name in names { buckets[name, default: []].append(snapshot) }
            }
        }

        return buckets.keys.sorted { lhs, rhs in
            if lhs == defaultName { return true }
            if rhs == defaultName { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { name in
            ContainerGroup(name: name, symbol: "network", resource: byNetworkName[name],
                           containers: sorted(buckets[name] ?? []),
                           isBuiltin: byNetworkName[name]?.isBuiltin ?? true)
        }
    }

    private var volumeGroups: [ContainerGroup] {
        let noVolume = "No volume"
        var buckets: [String: [Core.Container.Snapshot]] = [:]
        for snapshot in filtered {
            let volumes = Set(snapshot.configuration.mounts.compactMap { mount -> String? in
                guard let source = mount.source, !source.isEmpty else { return nil }
                return source
            })
            if volumes.isEmpty {
                buckets[noVolume, default: []].append(snapshot)
            } else {
                for volume in volumes { buckets[volume, default: []].append(snapshot) }
            }
        }
        return buckets.keys.sorted { lhs, rhs in
            if lhs == noVolume { return false }
            if rhs == noVolume { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { name in
            ContainerGroup(name: name, symbol: "externaldrive", resource: nil,
                           containers: sorted(buckets[name] ?? []), isBuiltin: false)
        }
    }

    private var imageGroups: [ContainerGroup] {
        var buckets: [String: [Core.Container.Snapshot]] = [:]
        for snapshot in filtered {
            buckets[Format.shortImage(snapshot.image), default: []].append(snapshot)
        }
        return buckets.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { name in
                ContainerGroup(name: name, symbol: "shippingbox", resource: nil,
                               containers: sorted(buckets[name] ?? []), isBuiltin: false)
            }
    }

    /// Order a bucket of containers by the chosen sort.
    private func sorted(_ containers: [Core.Container.Snapshot]) -> [Core.Container.Snapshot] {
        switch ui.sort {
        case .name:
            return containers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .status:
            return containers.sorted { lhs, rhs in
                let lhsRunning = lhs.state == .running, rhsRunning = rhs.state == .running
                if lhsRunning != rhsRunning { return lhsRunning }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        case .image:
            return containers.sorted { lhs, rhs in
                let cmp = lhs.image.localizedCaseInsensitiveCompare(rhs.image)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    private var columns: [GridItem] {
        return [GridItem(.adaptive(minimum: UI.Card.Grid.largeMin, maximum: UI.Card.Grid.largeMax),
                  spacing: UI.Layout.Spacing.m)]
    }

    private var filtered: [Core.Container.Snapshot] {
        store.snapshots.filter { snapshot in
            (!ui.runningOnly || snapshot.state == .running) &&
            (ui.search.text.isEmpty
                || snapshot.displayName.localizedCaseInsensitiveContains(ui.search.text)
                || snapshot.image.localizedCaseInsensitiveContains(ui.search.text))
        }
    }

    var body: some View {
        @Bindable var ui = ui
        return GeometryReader { viewport in
            let scrollBounds = safeAreaManager.bounds(in: viewport.size, policy: .content)
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
                            ForEach(groups) { group in
                                groupSection(group)
                            }
                            Color.clear
                                .frame(height: UI.Toolbar.Size.band)
                        }
                        .padding(.horizontal, UI.Layout.Spacing.l)
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
                    let source = cardFrames[detail.scopedID].flatMap { $0.isUsableForMorph ? $0 : nil } ?? target
                    UX.Morph.SingleSurface(source: source,
                                           target: target,
                                           progress: expanded ? 1 : 0) {
                        expandedCard(detail)
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
        // Network-level actions.
        .task { await app.refreshNetworks() }
        .confirmationDialog("Delete network \(deletingNetwork?.name ?? "")?",
                            isPresented: deleteNetworkBinding, presenting: deletingNetwork) { network in
            Button("Delete", role: .destructive) { Task { await deleteNetwork(network) } }
        } message: { _ in Text("This removes the network. Containers must be detached first.") }
        .refreshable { await store.refresh() }
        .sensoryFeedback(.success, trigger: lifecycleFeedback)
        // Report the in-page search count so the toolbar can escalate an empty search into the palette.
        .onAppear { ui.search.pageResultCount = filtered.count }
        .onChange(of: filtered.count) { _, count in ui.search.pageResultCount = count }
        .onChange(of: store.snapshots.map(\.scopedID)) { _, ids in
            selectedWidgetIndices = selectedWidgetIndices.filter { ids.contains($0.key) }
        }
    }

    // MARK: - Network sections

    @ViewBuilder
    private func groupSection(_ group: ContainerGroup) -> some View {
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
                        ForEach(group.containers) { snapshot in
                            gridCard(snapshot)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ group: ContainerGroup, collapsed: Bool) -> some View {
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
    private func gridCard(_ snapshot: Core.Container.Snapshot) -> some View {
        let selected = detail?.scopedID == snapshot.scopedID
        compactCard(snapshot)
            // Stays laid out (so the slot is reserved and its frame keeps publishing) but invisible
            // while the promoted overlay grows out of it — no second card to see double.
            .opacity(selected ? 0 : 1)
            .allowsHitTesting(detail == nil)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateCardFrame(proxy.frame(in: .named("grid")), for: snapshot.scopedID)
                        }
                        .onChange(of: proxy.frame(in: .named("grid"))) { _, frame in
                            updateCardFrame(frame, for: snapshot.scopedID)
                        }
                }
            }
    }

    private func updateCardFrame(_ frame: CGRect, for id: String) {
        guard frame.isUsableForMorph else { return }
        guard cardFrames[id]?.isClose(to: frame) != true else { return }
        cardFrames[id] = frame
    }

    private func compactCard(_ snapshot: Core.Container.Snapshot) -> some View {
        containerCard(snapshot, isExpanded: false) {
            selecting ? toggle(snapshot.scopedID) : openDetail(snapshot)
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
        return ContainerCardMetricsRenderer(
            metrics: store.metricsState(for: key),
            snapshot: snapshot,
            style: style,
            hasStyleOverride: hasStyleOverride,
            density: app.settings.density,
            statsNormalization: app.statsNormalizationContext,
            selectedWidgetIndex: selectedWidgetBinding(for: key),
            isBusy: store.busyIDs.contains(key),
            hasImageUpdate: app.imageUpdateStatus(for: snapshot.image).state == .updateAvailable,
            isExpanded: isExpanded,
            cornerRadiusOverride: cornerRadiusOverride,
            controlsVisible: controlsVisible,
            onTap: onTap,
            onStart: { lifecycleAction { await store.start(key) } },
            onStop: { lifecycleAction { await store.stop(key) } },
            onRestart: { lifecycleAction { await store.restart(key) } },
            onEdit: { ui.openCreationPanel(editing: snapshot) },
            onUpdate: { updateContainer(snapshot) },
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

    private func openDetail(_ snapshot: Core.Container.Snapshot) {
        // Render the card at its slot first (expanded == false), then spring it open on the next
        // runloop so the grow has a real starting frame to animate from.
        detail = snapshot
        expanded = false
        DispatchQueue.main.async {
            withAnimation(detailSpring) { expanded = true }
        }
    }

    private func closeDetail() {
        withAnimation(detailSpring) { expanded = false } completion: {
            detail = nil
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

    private func updateContainer(_ snapshot: Core.Container.Snapshot) {
        Task {
            if await app.pullImageUpdate(snapshot.image, runtimeKind: snapshot.runtimeKind) {
                ui.openCreationPanel(editing: snapshot)
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

private struct ContainerCardMetricsRenderer: View {
    let metrics: ContainerMetricsState
    let snapshot: Core.Container.Snapshot
    let style: Personalization
    let hasStyleOverride: Bool
    let density: UI.Card.Density
    let statsNormalization: Core.Metrics.NormalizationContext
    let selectedWidgetIndex: Binding<Int>
    let isBusy: Bool
    let hasImageUpdate: Bool
    let isExpanded: Bool
    let cornerRadiusOverride: CGFloat?
    let controlsVisible: Bool
    let onTap: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onEdit: () -> Void
    let onUpdate: () -> Void
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
            hasImageUpdate: hasImageUpdate,
            isExpanded: isExpanded,
            cornerRadiusOverride: cornerRadiusOverride,
            controlsVisible: controlsVisible,
            onTap: onTap,
            onStart: onStart,
            onStop: onStop,
            onRestart: onRestart,
            onEdit: onEdit,
            onUpdate: onUpdate,
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
            state: .running
        )
        let dockerWeb = Core.Container.Snapshot.placeholder(
            id: "preview-web",
            image: "docker.io/library/nginx:latest",
            state: .running
        )
        .scoped(to: .docker)
        let worker = Core.Container.Snapshot.placeholder(
            id: "preview-worker",
            image: "ghcr.io/example/worker:nightly",
            state: .stopped
        )
        .scoped(to: .docker)
        let db = Core.Container.Snapshot.placeholder(
            id: "preview-db",
            image: "postgres:16",
            state: .running
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
