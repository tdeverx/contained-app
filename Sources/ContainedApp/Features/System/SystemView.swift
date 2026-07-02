import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import ContainedCore
import ContainedRuntime

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
            case .engine: return AppText.string("system.page.engine.subtitle", defaultValue: "Container engine")
            case .automation: return AppText.string("system.page.automation.subtitle", defaultValue: "Background work")
            case .volumes: return AppText.string("system.page.volumes.subtitle", defaultValue: "Named, temp, and path mounts")
            }
        }

        var title: String {
            switch self {
            case .engine: return AppText.string("system.page.engine", defaultValue: "Engine")
            case .automation: return AppText.string("system.page.automation", defaultValue: "Automation")
            case .volumes: return AppText.sectionVolumes
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
            case .containers: return AppText.string("cleanup.removeStoppedContainers.title", defaultValue: "Remove all stopped containers?")
            case .images: return AppText.string("cleanup.removeUnusedImages.title", defaultValue: "Remove unused images?")
            case .volumes: return AppText.string("cleanup.removeUnusedVolumes.title", defaultValue: "Remove unused volumes?")
            case .networks: return AppText.string("cleanup.removeUnusedNetworks.title", defaultValue: "Remove unused networks?")
            }
        }
    }

    var body: some View {
        DesignPanelScaffold(width: DesignTokens.PanelSize.system.width) {
            if showsHeader {
                VStack(spacing: 0) {
                    header
                    Divider()
                }
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Space.l) {
                switch activePage {
                case .engine: engineStatusCard
                case .automation: automationCard
                case .volumes: volumesCard
                }
            }
            .padding(DesignTokens.Space.s)
        }
        .task { await app.refreshSystemResources() }
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

    /// A consistent design-system section card.
    private func card<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        DesignContentSurface(elevated: elevated, alignment: .leading) {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Space.m) { content() }
        }
    }

    private var header: some View {
        PanelHeader(symbol: "gearshape.2",
                    title: AppText.sectionSystem,
                    subtitle: activePage.subtitle) {
            HStack(spacing: DesignTokens.Toolbar.groupSpacing) {
                engineControls
                DesignActionCluster {
                    DesignActionItems(pageActions)
                    storageMenu
                    if showClose {
                        DesignActionItems([DesignAction(systemName: "xmark",
                                                        help: AppText.close,
                                                        isCancel: true,
                                                        action: onClose)])
                    }
                }
            }
        }
    }

    private var pageActions: [DesignAction] {
        SystemPage.allCases.map { item in
            DesignAction(systemName: item.systemImage,
                         help: item.title,
                         tint: activePage == item ? .accentColor : nil) {
                setPage(item)
            }
        }
    }

    private var engineControls: some View {
        DesignActionGroup([
            servicePowerAction,
            DesignAction(systemName: "arrow.clockwise",
                         help: AppText.restartService,
                         isEnabled: !working) {
                run { await app.restartService() }
            }
        ])
    }

    private var servicePowerAction: DesignAction {
        if app.serviceHealthy {
            return DesignAction(systemName: "stop.fill",
                                help: AppText.stopService,
                                role: .destructive,
                                isEnabled: !working) {
                run { await app.stopService() }
            }
        } else {
            return DesignAction(systemName: "play.fill",
                                help: AppText.startService,
                                isEnabled: !working) {
                run { await app.startService() }
            }
        }
    }

    private var storageMenu: some View {
        Menu {
            Button { reclaimingAll = true } label: {
                Label(AppText.string("cleanup.reclaimAll", defaultValue: "Reclaim all"), systemImage: "trash")
            }
            .disabled((app.diskUsage?.totalReclaimableBytes ?? 0) == 0)
            Divider()
            Button { pruneTarget = .containers } label: { Label(AppText.string("cleanup.stoppedContainers", defaultValue: "Stopped containers"), systemImage: "shippingbox") }
            Button { pruneTarget = .images } label: { Label(AppText.string("cleanup.unusedImages", defaultValue: "Unused images"), systemImage: "square.stack.3d.up") }
            Button { pruneTarget = .volumes } label: { Label(AppText.string("cleanup.unusedVolumes", defaultValue: "Unused volumes"), systemImage: "externaldrive") }
            Button { pruneTarget = .networks } label: { Label(AppText.string("cleanup.unusedNetworks", defaultValue: "Unused networks"), systemImage: "network") }
        } label: {
            DesignMenuActionLabel(systemName: "trash",
                                  help: AppText.storageCleanup,
                                  role: .destructive)
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
                Text(AppText.sectionVolumes).font(.headline)
                DesignBadgeText(text: "\(volumeInventory.count)")
                Spacer()
                DesignActionGroup(DesignAction(systemName: "plus",
                                               title: AppText.string("common.new", defaultValue: "New"),
                                               help: AppText.newVolume) {
                        onClose()
                        ui.dispatch(.createVolume)
                })
            }
            if volumeInventory.isEmpty {
                Text(AppText.string("volume.inventory.empty", defaultValue: "No named volumes or container mounts found."))
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DesignTokens.Space.xs)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(volumeInventory.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider() }
                        volumeRow(entry)
                    }
                }
            }
        }
    }

    private func volumeRow(_ entry: VolumeInventoryEntry) -> some View {
        HStack(spacing: DesignTokens.Space.m) {
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(.secondary)
                .frame(width: DesignTokens.IconSize.rowIconColumn)
            VStack(alignment: .leading, spacing: DesignTokens.DesignCard.compactTextSpacing) {
                HStack(spacing: DesignTokens.Space.xs) {
                    Text(entry.title).font(.system(.callout, design: .monospaced)).lineLimit(1)
                    DesignBadgeText(text: entry.kind.rawValue)
                }
                if let subtitle = SystemVolumeInventory.rowSubtitle(entry) {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: DesignTokens.Space.s)
            if !entry.containers.isEmpty {
                Text("\(entry.containers.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            DesignRowMenu(accessibilityLabel: AppText.string("menu.volumeActions", defaultValue: "Volume actions")) {
                volumeMenu(entry)
            }
        }
        .padding(.vertical, DesignTokens.Space.s)
        .contextMenu { volumeMenu(entry) }
    }

    @ViewBuilder
    private func volumeMenu(_ entry: VolumeInventoryEntry) -> some View {
        Button { copyToPasteboard(entry.source ?? entry.title) } label: { Label(AppText.string("volume.copySource", defaultValue: "Copy source"), systemImage: "doc.on.doc") }
        if let destination = entry.destination {
            Button { copyToPasteboard(destination) } label: { Label(AppText.string("volume.copyDestination", defaultValue: "Copy destination"), systemImage: "arrow.down.doc") }
        } else {
            Button(AppText.string("volume.copyDestination", defaultValue: "Copy destination"), systemImage: "arrow.down.doc") {}
                .disabled(true)
        }
        Divider()
        if let volume = entry.resource {
            Button(role: .destructive) { deletingVolume = volume } label: { Label(AppText.delete, systemImage: "trash") }
        } else {
            Button(AppText.delete, systemImage: "trash", role: .destructive) {}
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
            Text(AppText.string("system.page.automation", defaultValue: "Automation")).font(.headline)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                automationRow(icon: "arrow.triangle.2.circlepath",
                              title: AppText.string("automation.imageUpdateCheck", defaultValue: "Image update check"),
                              detail: app.settings.imageUpdateChecksEnabled
                                  ? "\(backgroundTaskDetail(now: context.date)) · \(app.imageUpdateIntervalDescription)"
                                  : AppText.string("status.paused", defaultValue: "Paused"),
                              isOn: settingBinding(\.imageUpdateChecksEnabled)) {
                    if app.settings.imageUpdateChecksEnabled {
                        Text(countdown(to: app.imageUpdateNextRunDate, now: context.date))
                            .font(.system(.caption, design: .monospaced).weight(.semibold)).monospacedDigit()
                        DesignActionGroup(DesignAction(systemName: "arrow.triangle.2.circlepath",
                                                       title: AppText.string("common.runNow", defaultValue: "Run now"),
                                                       help: AppText.runImageUpdateCheckNow) {
                                Task { await app.runImageUpdateSweepNow() }
                        })
                    }
                }
            }
            Divider()
            automationRow(icon: "arrow.down.app",
                          title: AppText.string("automation.appUpdateCheck", defaultValue: "App update check"),
                          detail: app.updater.canCheckForUpdates
                              ? AppText.string("automation.appUpdateCheck.detail", defaultValue: "Sparkle · \(app.settings.updateChannel.rawValue.capitalized) channel")
                              : AppText.string("status.unavailableInBuild", defaultValue: "Unavailable in this build"),
                          isOn: appUpdateBinding) {
                DesignActionGroup(DesignAction(systemName: "arrow.down.app",
                                               title: AppText.string("common.checkNow", defaultValue: "Check now"),
                                               help: AppText.checkForUpdatesNow,
                                               isEnabled: app.updater.canCheckForUpdates
                                                   && app.settings.appUpdateChecksEnabled) {
                        app.updater.checkForUpdates()
                })
            }
            Divider()
            automationRow(icon: "arrow.clockwise.circle",
                          title: AppText.string("automation.autoRestart", defaultValue: "Auto-restart crashed containers"),
                          detail: app.settings.autoRestartEnabled
                              ? AppText.string("automation.autoRestart.detail", defaultValue: "Restarts containers that exit unexpectedly")
                              : AppText.string("status.off", defaultValue: "Off"),
                          isOn: settingBinding(\.autoRestartEnabled)) { EmptyView() }
            Divider()
            HStack(spacing: DesignTokens.Space.s) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                    .frame(width: DesignTokens.IconSize.rowIconColumn)
                Text(AppText.string("automation.refreshLoop", defaultValue: "Refresh loop")).font(.callout)
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
        HStack(spacing: DesignTokens.Space.m) {
            Image(systemName: icon).font(.title3)
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
                .frame(width: DesignTokens.IconSize.rowIconColumn)
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignTokens.Space.s)
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
        } catch let error as CommandError { app.flash(error.appDisplayMessage) }
        catch { app.flash(error.appDisplayMessage) }
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
            HStack(spacing: DesignTokens.Space.s) {
                DesignStatusDot(color: app.serviceHealthy ? .green : .orange,
                                size: DesignTokens.IconSize.serviceDot)
                Text(AppText.string("system.containerEngine", defaultValue: "Container engine")).font(.headline)
                DesignStatusBadge(text: app.serviceLabel,
                                  tint: app.serviceHealthy ? .green : .orange)
                Spacer(minLength: 0)
                if let version = app.systemStatus?.apiServerVersion {
                    Text(version).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            HStack(spacing: DesignTokens.Space.s) {
                DesignMetricTile(label: AppText.sectionContainers,
                                 value: "\(app.containers.running.count)",
                                 caption: AppText.string("status.running.lowercase", defaultValue: "running"))
                DesignMetricTile(label: AppText.sectionImages, value: "\(app.images.count)")
                DesignMetricTile(label: AppText.string("system.diskUsed", defaultValue: "Disk used"),
                                 value: app.diskUsage.map { Format.bytes($0.totalSizeInBytes) } ?? "—")
            }
            if working { ProgressView().controlSize(.small) }
        }
    }

    private func run(_ action: @escaping () async -> Void) {
        working = true
        Task { await action(); working = false }
    }
}
