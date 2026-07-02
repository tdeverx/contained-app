import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import ContainedCore

/// System overview content: service status + controls, volumes, `system df` disk usage, a Prune
/// Center, and a system-logs viewer. Hosted header-less in the toolbar System morph panel. Daemon
/// defaults, kernel, and DNS configuration live in Settings → Runtime.
struct SystemContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    /// Flat cards (no shadow) when hosted in the toolbar morph panel; elevated if shown standalone.
    var showClose: Bool
    var elevated = true
    var usesToolbarSelection = true
    var onClose: () -> Void = {}

    @State private var working = false
    @State private var pruneTarget: PruneTarget?
    @State private var reclaimingAll = false
    @State private var inspectingVolume: VolumeResource?
    @State private var deletingVolume: VolumeResource?
    @State private var page: SystemPage

    enum SystemPage: String, CaseIterable, Identifiable {
        case engine = "Engine"
        case automation = "Automation"
        case volumes = "Volumes"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .engine: return "server.rack"
            case .automation: return "clock.arrow.circlepath"
            case .volumes: return "externaldrive"
            }
        }

        var subtitle: String {
            switch self {
            case .engine: return "Container engine"
            case .automation: return "Background work"
            case .volumes: return "Named, temp, and path mounts"
            }
        }
    }

    private var showsHeader: Bool {
        showClose || !ui.toolbarUIEnabled
    }

    private var activePage: SystemPage {
        ui.toolbarUIEnabled && !showClose && usesToolbarSelection ? ui.systemPage : page
    }

    private func setPage(_ item: SystemPage) {
        if ui.toolbarUIEnabled && !showClose && usesToolbarSelection {
            ui.systemPage = item
        } else {
            page = item
        }
    }

    init(initialPage: SystemPage = .engine,
         showClose: Bool = true,
         elevated: Bool = true,
         usesToolbarSelection: Bool = true,
         onClose: @escaping () -> Void = {}) {
        self.showClose = showClose
        self.elevated = elevated
        self.usesToolbarSelection = usesToolbarSelection
        self.onClose = onClose
        _page = State(initialValue: initialPage)
    }

    private typealias VolumeInventoryEntry = SystemVolumeInventory.Entry

    enum PruneTarget: String, Identifiable {
        case containers, images, volumes, networks
        var id: String { rawValue }
        var title: String {
            switch self {
            case .containers: return "Remove all stopped containers?"
            case .images: return "Remove unused images?"
            case .volumes: return "Remove unused volumes?"
            case .networks: return "Remove unused networks?"
            }
        }
    }

    var body: some View {
        MorphPanelScaffold(width: Tokens.PanelSize.system.width) {
            if showsHeader {
                VStack(spacing: 0) {
                    header
                    Divider()
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                switch activePage {
                case .engine: engineStatusCard
                case .automation: automationCard
                case .volumes: volumesCard
                }
            }
            .padding(Tokens.Space.s)
        }
        .task { await app.refreshSystemResources() }
        .sheet(item: $inspectingVolume) { JSONInspectorSheet(title: $0.name, value: $0) }
        .confirmationDialog("Delete volume \(deletingVolume?.name ?? "")?",
                            isPresented: deletingVolumeBinding, presenting: deletingVolume) { volume in
            Button("Delete", role: .destructive) { Task { await deleteVolume(volume) } }
        } message: { _ in Text("This permanently removes the volume and its data.") }
        .confirmationDialog(pruneTarget?.title ?? "", isPresented: pruneBinding, presenting: pruneTarget) { target in
            Button("Remove", role: .destructive) { Task { await prune(target) } }
        } message: { _ in Text("This permanently removes unused resources to reclaim disk space.") }
        .confirmationDialog("Reclaim all unused space?", isPresented: $reclaimingAll) {
            Button("Reclaim all", role: .destructive) { Task { await reclaimAll() } }
        } message: {
            Text("Removes stopped containers, unused images, unused volumes, and unused networks.")
        }
    }

    /// A consistent flat-glass section card — every System section uses this so the panel reads as one
    /// coherent surface instead of a mix of cards and bare headings.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) { content() }
            .padding(Tokens.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: elevated)
    }

    private var header: some View {
        PanelHeader(symbol: "gearshape.2",
                    title: "System",
                    subtitle: activePage.subtitle) {
            HStack(spacing: Tokens.Toolbar.groupSpacing) {
                engineControls
                GlassButton {
                    pageButtons
                    storageMenu
                    if showClose {
                        GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pageButtons: some View {
        ForEach(SystemPage.allCases) { item in
            GlassButtonItem(tint: activePage == item ? .accentColor : nil,
                            help: item.rawValue,
                            isIcon: true,
                            action: { setPage(item) }) {
                Image(systemName: item.systemImage)
                    .opacity(activePage == item ? 1 : 0.62)
            }
        }
    }

    private var engineControls: some View {
        GlassButton {
            servicePowerButton
            GlassButtonItem(systemName: "arrow.clockwise", help: "Restart service") {
                run { await app.restartService() }
            }
            .disabled(working)
        }
    }

    @ViewBuilder
    private var servicePowerButton: some View {
        if app.serviceHealthy {
            GlassButtonItem(systemName: "stop.fill", role: .destructive, help: "Stop service") {
                run { await app.stopService() }
            }
            .disabled(working)
        } else {
            GlassButtonItem(systemName: "play.fill", help: "Start service") {
                run { await app.startService() }
            }
            .disabled(working)
        }
    }

    private var storageMenu: some View {
        Menu {
            Button { reclaimingAll = true } label: {
                Label("Reclaim all", systemImage: "trash")
            }
            .disabled((app.diskUsage?.totalReclaimableBytes ?? 0) == 0)
            Divider()
            Button { pruneTarget = .containers } label: { Label("Stopped containers", systemImage: "shippingbox") }
            Button { pruneTarget = .images } label: { Label("Unused images", systemImage: "square.stack.3d.up") }
            Button { pruneTarget = .volumes } label: { Label("Unused volumes", systemImage: "externaldrive") }
            Button { pruneTarget = .networks } label: { Label("Unused networks", systemImage: "network") }
        } label: {
            GlassButtonItem(systemName: "trash", role: .destructive,
                            help: "Storage cleanup")
        }
        .buttonStyle(.plain)
    }

    // MARK: Volumes

    private var volumeInventory: [VolumeInventoryEntry] {
        SystemVolumeInventory.build(volumes: app.volumes,
                                    containers: app.containers.snapshots)
    }

    // MARK: Volumes (condensed rows — the rich per-volume I/O card moves to a detail view)

    private var volumesCard: some View {
        card {
            HStack {
                Text("Volumes").font(.headline)
                ResourceBadgeText(text: "\(volumeInventory.count)")
                Spacer()
                GlassButton(singleItem: true) {
                    GlassButtonItem(help: "New volume", action: {
                        onClose()
                        ui.dispatch(.createVolume)
                    }) {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            if volumeInventory.isEmpty {
                Text("No named volumes or container mounts found.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Tokens.Space.xs)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(volumeInventory.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider() }
                        volumeRow(entry)
                    }
                }
            }
        }
    }

    private func volumeRow(_ entry: VolumeInventoryEntry) -> some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(.secondary)
                .frame(width: Tokens.IconSize.rowIconColumn)
            VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                HStack(spacing: Tokens.Space.xs) {
                    Text(entry.title).font(.system(.callout, design: .monospaced)).lineLimit(1)
                    ResourceBadgeText(text: entry.kind.rawValue)
                }
                if let subtitle = SystemVolumeInventory.rowSubtitle(entry) {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: Tokens.Space.s)
            if !entry.containers.isEmpty {
                Text("\(entry.containers.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GlassRowMenu { volumeMenu(entry) }
        }
        .padding(.vertical, Tokens.Space.s)
        .contextMenu { volumeMenu(entry) }
    }

    @ViewBuilder
    private func volumeMenu(_ entry: VolumeInventoryEntry) -> some View {
        if let volume = entry.resource {
            Button { inspectingVolume = volume } label: { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
        } else {
            Button("Inspect", systemImage: "doc.text.magnifyingglass") {}
                .disabled(true)
        }
        Button { copyToPasteboard(entry.source ?? entry.title) } label: { Label("Copy source", systemImage: "doc.on.doc") }
        if let destination = entry.destination {
            Button { copyToPasteboard(destination) } label: { Label("Copy destination", systemImage: "arrow.down.doc") }
        } else {
            Button("Copy destination", systemImage: "arrow.down.doc") {}
                .disabled(true)
        }
        Divider()
        if let volume = entry.resource {
            Button(role: .destructive) { deletingVolume = volume } label: { Label("Delete", systemImage: "trash") }
        } else {
            Button("Delete", systemImage: "trash", role: .destructive) {}
                .disabled(true)
        }
    }

    private var deletingVolumeBinding: Binding<Bool> {
        Binding(get: { deletingVolume != nil }, set: { if !$0 { deletingVolume = nil } })
    }

    private func deleteVolume(_ volume: VolumeResource) async {
        guard let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.deleteVolumes([volume.name]) }) { app.flash(error) }
        await app.refreshVolumes()
    }

    private var automationCard: some View {
        card {
            Text("Automation").font(.headline)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                automationRow(icon: "arrow.triangle.2.circlepath",
                              title: "Image update check",
                              detail: app.settings.imageUpdateChecksEnabled
                                  ? "\(backgroundTaskDetail(now: context.date)) · \(app.imageUpdateIntervalDescription)"
                                  : "Paused",
                              isOn: settingBinding(\.imageUpdateChecksEnabled)) {
                    if app.settings.imageUpdateChecksEnabled {
                        Text(countdown(to: app.imageUpdateNextRunDate, now: context.date))
                            .font(.system(.caption, design: .monospaced).weight(.semibold)).monospacedDigit()
                        GlassButton(singleItem: true) {
                            GlassButtonItem(help: "Run image update check now", action: {
                                Task { await app.runImageUpdateSweepNow() }
                            }) {
                                Label("Run now", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                    }
                }
            }
            Divider()
            automationRow(icon: "arrow.down.app",
                          title: "App update check",
                          detail: app.updater.canCheckForUpdates
                              ? "Sparkle · \(app.settings.updateChannel.rawValue.capitalized) channel"
                              : "Unavailable in this build",
                          isOn: appUpdateBinding) {
                GlassButton(singleItem: true) {
                    GlassButtonItem(help: "Check for app updates now", action: {
                        app.updater.checkForUpdates()
                    }) {
                        Label("Check now", systemImage: "arrow.down.app")
                    }
                }
                    .disabled(!app.updater.canCheckForUpdates || !app.settings.appUpdateChecksEnabled)
            }
            Divider()
            automationRow(icon: "arrow.clockwise.circle",
                          title: "Auto-restart crashed containers",
                          detail: app.settings.autoRestartEnabled
                              ? "Restarts containers that exit unexpectedly"
                              : "Off",
                          isOn: settingBinding(\.autoRestartEnabled)) { EmptyView() }
            Divider()
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                    .frame(width: Tokens.IconSize.rowIconColumn)
                Text("Refresh loop").font(.callout)
                Spacer()
                Text(app.coordinator.isActive ? "Active" : "Paused")
                    .font(.callout)
                    .foregroundStyle(app.coordinator.isActive ? .green : .secondary)
            }
        }
    }

    private func automationRow<Trailing: View>(icon: String, title: String, detail: String,
                                               isOn: Binding<Bool>,
                                               @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: icon).font(.title3)
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
                .frame(width: Tokens.IconSize.rowIconColumn)
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: Tokens.Space.s)
            trailing()
            Toggle("", isOn: isOn).labelsHidden().controlSize(.mini)
        }
    }

    /// A binding to a `SettingsStore` boolean (the store is a class, so its key paths are writable).
    private func settingBinding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Bool>) -> Binding<Bool> {
        Binding(get: { app.settings[keyPath: keyPath] }, set: { app.settings[keyPath: keyPath] = $0 })
    }

    /// The Sparkle toggle writes through to both the persisted setting and the live updater.
    private var appUpdateBinding: Binding<Bool> {
        Binding(get: { app.settings.appUpdateChecksEnabled },
                set: { app.settings.appUpdateChecksEnabled = $0; app.updater.automaticallyChecks = $0 })
    }

    private func backgroundTaskDetail(now: Date) -> String {
        if let last = app.imageUpdateLastRunDate {
            return "Last ran \(last.formatted(date: .omitted, time: .shortened))"
        }
        return app.imageUpdateNextRunDate <= now ? "Ready to run" : "Not run yet"
    }

    private func countdown(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds == 0 { return "due now" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm %02ds", minutes, secs) }
        return "\(secs)s"
    }

    private var pruneBinding: Binding<Bool> {
        Binding(get: { pruneTarget != nil }, set: { if !$0 { pruneTarget = nil } })
    }

    private func prune(_ target: PruneTarget) async {
        guard let client = app.client else { return }
        do {
            switch target {
            case .containers: _ = try await client.pruneContainers()
            case .images: _ = try await client.pruneImages(all: false)
            case .volumes: _ = try await client.pruneVolumes()
            case .networks: _ = try await client.pruneNetworks()
            }
            await app.refreshSystemResources()
            await app.refreshSystem()
        } catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    private func reclaimAll() async {
        guard let client = app.client else { return }
        if let error = await app.captured({
            _ = try await client.pruneContainers()
            _ = try await client.pruneImages(all: false)
            _ = try await client.pruneVolumes()
            _ = try await client.pruneNetworks()
        }) { app.flash(error) }
        await app.refreshSystemResources()
        await app.refreshSystem()
    }

    // MARK: Runtime

    private var engineStatusCard: some View {
        card {
            HStack(spacing: Tokens.Space.s) {
                DesignStatusDot(color: app.serviceHealthy ? .green : .orange,
                                size: Tokens.IconSize.serviceDot)
                Text("Container engine").font(.headline)
                DesignStatusBadge(text: app.serviceLabel,
                                  tint: app.serviceHealthy ? .green : .orange)
                Spacer(minLength: 0)
                if let version = app.systemStatus?.apiServerVersion {
                    Text(version).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            HStack(spacing: Tokens.Space.s) {
                DesignMetricTile(label: "Containers", value: "\(app.containers.running.count)", caption: "running")
                DesignMetricTile(label: "Images", value: "\(app.images.count)")
                DesignMetricTile(label: "Disk used", value: app.diskUsage.map { Format.bytes($0.totalSizeInBytes) } ?? "—")
            }
            if working { ProgressView().controlSize(.small) }
        }
    }

    private func run(_ action: @escaping () async -> Void) {
        working = true
        Task { await action(); working = false }
    }
}
