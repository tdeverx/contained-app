import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import AppKit
import ContainedCore
import ContainedRuntime

/// The Containers screen: a responsive grid of personalized glass cards. Density and the running
/// filter live in the background context menu and menu commands; tapping a card grows it in place
/// into a centered detail panel.
struct ContainersGridView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.morphSafeAreas) private var safeAreas

    @State private var detail: ContainerSnapshot?
    @State private var deleting: ContainerSnapshot?
    @State private var selecting = false
    @State private var selection: Set<String> = []
    /// Drives the in-place grow: false = card sits in its grid slot, true = promoted to the centered
    /// panel. A single spring on this flag owns the whole motion (no matchedGeometry to fight).
    @State private var expanded = false
    /// Live frames of every visible grid card (in the "grid" coordinate space) so the promoted card
    /// can start from the exact slot it was tapped in.
    @State private var cardFrames: [String: CGRect] = [:]
    @State private var selectedWidgetIndices: [String: Int] = [:]

    // Each network is a collapsible section of the containers attached to it.
    @State private var collapsedNetworks: Set<String> = []
    @State private var deletingNetwork: NetworkResource?

    private let detailSpring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    private var store: ContainersStore { app.containers }

    /// A bucket of containers under one heading. `resource` is set only for network grouping (so the
    /// section keeps its network context menu); `symbol` drives the section header glyph.
    private struct ContainerGroup: Identifiable {
        let name: String
        let symbol: String
        let resource: NetworkResource?
        let containers: [ContainerSnapshot]
        let isBuiltin: Bool
        var id: String { name }
    }

    /// The network names a container is attached to (requested config ∪ runtime status).
    private func networkNames(_ snapshot: ContainerSnapshot) -> [String] {
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

        var buckets: [String: [ContainerSnapshot]] = [:]
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
        var buckets: [String: [ContainerSnapshot]] = [:]
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
        var buckets: [String: [ContainerSnapshot]] = [:]
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
    private func sorted(_ containers: [ContainerSnapshot]) -> [ContainerSnapshot] {
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
        return [GridItem(.adaptive(minimum: DesignTokens.CardSize.largeMin, maximum: DesignTokens.CardSize.largeMax),
                  spacing: DesignTokens.Space.m)]
    }

    private var filtered: [ContainerSnapshot] {
        store.snapshots.filter { snapshot in
            (!ui.runningOnly || snapshot.state == .running) &&
            (ui.searchText.isEmpty
                || snapshot.displayName.localizedCaseInsensitiveContains(ui.searchText)
                || snapshot.image.localizedCaseInsensitiveContains(ui.searchText))
        }
    }

    var body: some View {
        @Bindable var ui = ui
        return GeometryReader { viewport in
            let scrollBounds = safeAreas.bounds(in: viewport.size, policy: .content)
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
                        LazyVStack(alignment: .leading, spacing: DesignTokens.Space.l) {
                            ForEach(groups) { group in
                                groupSection(group)
                            }
                            Color.clear
                                .frame(height: DesignTokens.Toolbar.band)
                        }
                        .padding(.horizontal, DesignTokens.Space.l)
                    }
                }
                .contentMargins(.top, ui.toolbarUIEnabled ? 0 : DesignTokens.Toolbar.band, for: .scrollContent)

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
                                                       safeAreas: cardDetailSafeAreas)
                    let source = cardFrames[detail.id].flatMap { $0.isUsableForMorph ? $0 : nil } ?? target
                    let rect = expanded ? target : source
                    expandedCard(detail)
                        .frame(width: rect.width, height: rect.height, alignment: .top)
                        .position(x: rect.midX, y: rect.midY)
                        .zIndex(10)
                }
            }
            .coordinateSpace(.named("grid"))
        }
        .overlay(alignment: .bottom) {
            if selecting && !selection.isEmpty { batchBar } else if let message = store.errorMessage { ErrorToast(message: message) }
        }
        .overlay {
            if store.snapshots.isEmpty && app.networks.isEmpty { emptyState }
        }
        .confirmationDialog(
            "Delete \(customizeName(deleting))?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = deleting?.id { Task { await store.remove(id, force: true) } }
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
        // Report the in-page search count so the toolbar can escalate an empty search into the palette.
        .onAppear { ui.pageResultCount = filtered.count }
        .onChange(of: filtered.count) { _, count in ui.pageResultCount = count }
        .onChange(of: store.snapshots.map(\.id)) { _, ids in
            selectedWidgetIndices = selectedWidgetIndices.filter { ids.contains($0.key) }
        }
    }

    // MARK: - Network sections

    @ViewBuilder
    private func groupSection(_ group: ContainerGroup) -> some View {
        let collapsed = collapsedNetworks.contains(group.name)
        LazyVStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            sectionHeader(group, collapsed: collapsed)
            if !collapsed {
                if group.containers.isEmpty {
                    Text(ui.grouping == .network ? "No containers on this network." : "No containers.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DesignTokens.Space.s)
                } else {
                    LazyVGrid(columns: columns, spacing: DesignTokens.Space.m) {
                        ForEach(group.containers) { snapshot in
                            gridCard(snapshot)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ group: ContainerGroup, collapsed: Bool) -> some View {
        HStack(spacing: DesignTokens.Space.s) {
            Button {
                toggleCollapsed(group.name)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
            }
            .buttonStyle(.plain)
            Image(systemName: group.symbol).font(.callout).foregroundStyle(.secondary)
            Text(group.name).font(.headline)
            DesignBadgeText(text: "\(group.containers.count)")
            if group.isBuiltin {
                DesignBadgeText(text: "builtin", font: .caption2.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Space.xs)
        .padding(.vertical, DesignTokens.Space.xs)
        .contextMenu { if let resource = group.resource { networkMenu(resource) } }
    }

    @ViewBuilder
    private func networkMenu(_ resource: NetworkResource) -> some View {
        Button { copyToPasteboard(resource.name) } label: { Label("Copy Name", systemImage: "doc.on.doc") }
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
        (NSApp.keyWindow ?? NSApp.mainWindow)?.zoom(nil)
    }

    private var deleteNetworkBinding: Binding<Bool> {
        Binding(get: { deletingNetwork != nil }, set: { if !$0 { deletingNetwork = nil } })
    }

    private func deleteNetwork(_ network: NetworkResource) async {
        guard let client = app.client else { return }
        do { _ = try await client.deleteNetworks([network.name]); await app.refreshNetworks() }
        catch let error as CommandError { app.flash(error.appDisplayMessage) }
        catch { app.flash(error.appDisplayMessage) }
    }

    @ViewBuilder
    private func gridCard(_ snapshot: ContainerSnapshot) -> some View {
        let selected = detail?.id == snapshot.id
        compactCard(snapshot)
            // Stays laid out (so the slot is reserved and its frame keeps publishing) but invisible
            // while the promoted overlay grows out of it — no second card to see double.
            .opacity(selected ? 0 : 1)
            .allowsHitTesting(detail == nil)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateCardFrame(proxy.frame(in: .named("grid")), for: snapshot.id)
                        }
                        .onChange(of: proxy.frame(in: .named("grid"))) { _, frame in
                            updateCardFrame(frame, for: snapshot.id)
                        }
                }
            }
    }

    private func updateCardFrame(_ frame: CGRect, for id: String) {
        guard frame.isUsableForMorph else { return }
        guard cardFrames[id]?.isClose(to: frame) != true else { return }
        cardFrames[id] = frame
    }

    private func compactCard(_ snapshot: ContainerSnapshot) -> some View {
        containerCard(snapshot, isExpanded: false) {
            selecting ? toggle(snapshot.id) : openDetail(snapshot)
        }
    }

    private func expandedCard(_ snapshot: ContainerSnapshot) -> some View {
        // `controlsVisible: expanded` so the footer buttons + close fade out as soon as a close
        // starts (expanded → false), finishing before the shrink animation does.
        containerCard(snapshot,
                      isExpanded: true,
                      cornerRadiusOverride: expanded ? DesignTokens.Radius.sheet : DesignTokens.Radius.card,
                      controlsVisible: expanded) {}
    }

    private func containerCard(_ snapshot: ContainerSnapshot, isExpanded: Bool,
                               cornerRadiusOverride: CGFloat? = nil,
                               controlsVisible: Bool = true,
                               onTap: @escaping () -> Void) -> some View {
        let style = app.containerStyle(for: snapshot)
        let hasStyleOverride = app.personalization.hasOverride(id: snapshot.id)
        return ContainerCardMetricsRenderer(
            metrics: store.metricsState(for: snapshot.id),
            snapshot: snapshot,
            style: style,
            hasStyleOverride: hasStyleOverride,
            density: app.settings.density,
            statsNormalization: app.statsNormalizationContext,
            selectedWidgetIndex: selectedWidgetBinding(for: snapshot.id),
            isBusy: store.busyIDs.contains(snapshot.id),
            hasImageUpdate: app.imageUpdateStatus(for: snapshot.image).state == .updateAvailable,
            isExpanded: isExpanded,
            cornerRadiusOverride: cornerRadiusOverride,
            controlsVisible: controlsVisible,
            onTap: onTap,
            onStart: { Task { await store.start(snapshot.id) } },
            onStop: { Task { await store.stop(snapshot.id) } },
            onRestart: { Task { await store.restart(snapshot.id) } },
            onEdit: { ui.openCreationPanel(editing: snapshot) },
            onUpdate: { updateContainer(snapshot) },
            onDelete: { deleting = snapshot },
            onClose: closeDetail,
            onSelectMultiple: { beginSelecting(snapshot.id) },
            onToggleSelected: { toggle(snapshot.id) },
            onEndSelecting: { endSelecting() },
            health: app.health.status(for: snapshot.id),
            selecting: selecting,
            isSelected: selection.contains(snapshot.id)
        )
    }

    private func selectedWidgetBinding(for id: String) -> Binding<Int> {
        Binding {
            selectedWidgetIndices[id] ?? 0
        } set: { index in
            selectedWidgetIndices[id] = index
        }
    }

    private var cardDetailTarget: MorphTarget {
        .centered(safeArea: cardDetailSafeAreaPolicy, margin: 0) { bounds in
            panelSize(in: bounds.size)
        }
    }

    private var cardDetailSafeAreaPolicy: MorphSafeAreaPolicy {
        let toolbarExclusion: MorphToolbarSafeAreaExclusion = ui.toolbarUIEnabled ? .bottom : .both
        return MorphSafeAreaPolicy(excluding: toolbarExclusion, padding: .none, includesSystemInsets: false)
    }

    private var cardDetailSafeAreas: MorphSafeAreaManager {
        guard ui.toolbarUIEnabled else { return safeAreas }
        return MorphSafeAreaManager(system: safeAreas.system,
                                  topToolbarHeight: AppToolbar.bandHeight,
                                  bottomToolbarHeight: AppToolbar.bandHeight)
    }

    private func panelSize(in available: CGSize) -> CGSize {
        let fitted = MorphGeometry.fittedSize(
            CGSize(width: max(available.width * 0.62, 680), height: 620),
            in: available,
            margin: 0
        )
        let width = max(min(fitted.width, available.width), min(360, fitted.width))
        let height = fitted.height
        return CGSize(width: width, height: height)
    }

    private func openDetail(_ snapshot: ContainerSnapshot) {
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
        DesignSelectionActionBar(count: selection.count,
                                 countLabel: AppText.selectedCount,
                                 actions: [
            DesignAction(systemName: "play.fill", title: AppText.start) {
                batch { await store.start($0) }
            },
            DesignAction(systemName: "stop.fill", title: AppText.stop) {
                batch { await store.stop($0) }
            },
            DesignAction(systemName: "trash", title: AppText.delete, role: .destructive) {
                batch { await store.remove($0, force: true) }
            }
        ])
        .padding(.bottom, DesignTokens.Space.l)
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
        }
    }

    private func updateContainer(_ snapshot: ContainerSnapshot) {
        Task {
            if await app.pullImageUpdate(snapshot.image) {
                ui.openCreationPanel(editing: snapshot)
            }
        }
    }

    private func customizeName(_ snapshot: ContainerSnapshot?) -> String {
        guard let snapshot else { return "" }
        return app.containerStyle(for: snapshot)
            .displayName(fallback: snapshot.id)
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No containers", systemImage: "shippingbox")
        } description: {
            Text(ui.runningOnly ? "No running containers." : "Run a container to see it here.")
        } actions: {
            Button("Run a container") { ui.openCreationPanel(entry: .chooser) }
        }
    }
}

private struct ContainerCardMetricsRenderer: View {
    let metrics: ContainerMetricsState
    let snapshot: ContainerSnapshot
    let style: Personalization
    let hasStyleOverride: Bool
    let density: CardDensity
    let statsNormalization: StatsNormalizationContext
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
    let health: HealthStatus
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
