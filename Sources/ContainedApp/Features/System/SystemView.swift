import SwiftUI
import ContainedUX
import ContainedUI
import ContainedCore

/// System overview content: service status + controls, volumes, networks, `system df` disk usage, a Prune
/// Center, and a system-logs viewer. Hosted in the toolbar System morph panel. Daemon
/// defaults, kernel, and DNS configuration live in Settings → Runtime.
struct SystemContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    /// Flat cards (no shadow) when hosted in the toolbar morph panel.
    var elevated = true
    var onClose: () -> Void = {}

    @State private var working = false
    @State private var pruneTarget: PruneTarget?
    @State private var reclaimingAll = false
    @State private var deletingVolume: Core.Volume.Resource?
    @State private var page: SystemPage

    enum SystemPage: String, CaseIterable, Identifiable {
        case runtime = "Runtime"
        case automation = "Automation"
        case volumes = "Volumes"
        case networks = "Networks"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .runtime: return "server.rack"
            case .automation: return "clock.arrow.circlepath"
            case .volumes: return "externaldrive"
            case .networks: return "network"
            }
        }

        var subtitle: String {
            switch self {
            case .runtime: return AppText.string("system.page.runtime.subtitle", defaultValue: "Container runtime")
            case .automation: return AppText.string("system.page.automation.subtitle", defaultValue: "Background work")
            case .volumes: return AppText.string("system.page.volumes.subtitle", defaultValue: "Named, temp, and path mounts")
            case .networks: return AppText.string("system.page.networks.subtitle", defaultValue: "Runtime network inventory")
            }
        }

        var title: String {
            switch self {
            case .runtime: return AppText.string("system.page.runtime", defaultValue: "Runtime")
            case .automation: return AppText.string("system.page.automation", defaultValue: "Automation")
            case .volumes: return AppText.sectionVolumes
            case .networks: return AppText.sectionNetworks
            }
        }
    }

    private var activePage: SystemPage {
        page
    }

    private func setPage(_ item: SystemPage) {
        page = item
    }

    init(elevated: Bool = true,
         onClose: @escaping () -> Void = {}) {
        self.elevated = elevated
        self.onClose = onClose
        _page = State(initialValue: .runtime)
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
        UI.Panel.Scaffold(width: UI.Panel.Size.system.width) {
            VStack(spacing: 0) {
                header
                Divider()
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
                switch activePage {
                case .runtime: runtimeStatusCard
                case .automation: automationCard
                case .volumes: volumesCard
                case .networks:
                    SystemNetworksContent(elevated: elevated) {
                        onClose()
                        ui.dispatch(.createNetwork)
                    }
                }
            }
            .padding(UI.Layout.Spacing.s)
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
        UI.Surface.Content(elevated: elevated, alignment: .leading) {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.m) { content() }
        }
    }

    private var header: some View {
        UI.Panel.Header(symbol: "gearshape.2",
                    title: AppText.sectionSystem,
                    subtitle: activePage.subtitle) {
            HStack(spacing: UI.Toolbar.Spacing.groupSpacing) {
                runtimeControls
                UI.Action.Cluster {
                    UI.Action.Items(pageActions)
                    storageMenu
                    UI.Action.Items([UI.Action.Item(systemName: "xmark",
                                                    help: AppText.close,
                                                    isCancel: true,
                                                    action: onClose)])
                }
            }
        }
    }

    private var pageActions: [UI.Action.Item] {
        SystemPage.allCases.map { item in
            UI.Action.Item(systemName: item.systemImage,
                         help: item.title,
                         tint: activePage == item ? .accentColor : nil) {
                setPage(item)
            }
        }
    }

    @ViewBuilder
    private var runtimeControls: some View {
        if app.serviceControlRuntimeAvailable {
            UI.Action.Group([
                servicePowerAction,
                UI.Action.Item(systemName: "arrow.clockwise",
                             help: AppText.restartService,
                             isEnabled: !working) {
                    run { await app.restartService() }
                }
            ])
        } else {
            UI.Action.Group(UI.Action.Item(systemName: "arrow.clockwise",
                                           help: AppText.string("common.retry", defaultValue: "Retry"),
                                           isEnabled: !working) {
                run { await app.retryBootstrap() }
            })
        }
    }

    private var servicePowerAction: UI.Action.Item {
        if app.serviceHealthy {
            return UI.Action.Item(systemName: "stop.fill",
                                help: AppText.stopService,
                                role: .destructive,
                                isEnabled: !working) {
                run { await app.stopService() }
            }
        } else {
            return UI.Action.Item(systemName: "play.fill",
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
            UI.Action.MenuLabel(systemName: "trash",
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

    private var volumesCard: some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
            HStack {
                Text(AppText.sectionVolumes).designHeadlineLabelStyle()
                UI.Badge.Text(text: "\(volumeInventory.count)")
                Spacer()
                UI.Action.Group(UI.Action.Item(systemName: "plus",
                                               title: AppText.string("common.new", defaultValue: "New"),
                                               help: AppText.newVolume) {
                        onClose()
                        ui.dispatch(.createVolume)
                })
            }
            if let message = app.resourceInventoryErrors["volumes"] {
                UI.State.InlineStatus(message, isWorking: false)
            }
            if volumeInventory.isEmpty {
                card {
                    UI.State.Empty(AppText.string("volume.inventory.empty", defaultValue: "No named volumes or container mounts found."),
                                   systemImage: "externaldrive",
                                   padding: UI.Layout.Spacing.xs)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
                    volumeSection(title: AppText.string("volume.section.runtimeVolumes", defaultValue: "Runtime volumes"),
                                  subtitle: AppText.string("volume.section.runtimeVolumes.subtitle", defaultValue: "Managed storage owned by the runtime."),
                                  entries: runtimeVolumeEntries,
                                  emptyTitle: AppText.string("volume.runtime.empty", defaultValue: "No runtime volumes"),
                                  emptySymbol: "externaldrive")
                    volumeSection(title: AppText.string("volume.section.pathMounts", defaultValue: "Host path mounts"),
                                  subtitle: AppText.string("volume.section.pathMounts.subtitle", defaultValue: "Bind paths and temporary mounts discovered from containers."),
                                  entries: hostPathVolumeEntries,
                                  emptyTitle: AppText.string("volume.pathMounts.empty", defaultValue: "No host path mounts"),
                                  emptySymbol: "folder")
                }
            }
        }
    }

    private var runtimeVolumeEntries: [VolumeInventoryEntry] {
        volumeInventory.filter { $0.kind == .named }
    }

    private var hostPathVolumeEntries: [VolumeInventoryEntry] {
        volumeInventory.filter { $0.kind != .named }
    }

    private func volumeSection(title: String,
                               subtitle: String,
                               entries: [VolumeInventoryEntry],
                               emptyTitle: String,
                               emptySymbol: String) -> some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
            HStack(spacing: UI.Layout.Spacing.s) {
                Text(title).designSectionLabelStyle()
                UI.Badge.Text(text: "\(entries.count)")
            }
            Text(subtitle)
                .designSecondaryCaption()
                .fixedSize(horizontal: false, vertical: true)
            if entries.isEmpty {
                UI.Surface.Content(elevated: elevated, minHeight: 132, alignment: .center) {
                    UI.State.Empty(emptyTitle,
                                   systemImage: emptySymbol,
                                   padding: UI.Layout.Spacing.xs)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                    ForEach(entries) { entry in
                        volumeEntryCard(entry)
                    }
                }
            }
        }
    }

    private func volumeEntryCard(_ entry: VolumeInventoryEntry) -> some View {
        UI.Card.Scaffold(size: .medium,
                         elevated: elevated,
                         title: entry.title,
                         subtitle: volumeCardSubtitle(entry),
                         titleStyle: entry.kind == .localPath ? .monospaced : .standard,
                         subtitleStyle: .monospaced) {
            UI.Card.IconChip(symbol: entry.kind.symbol,
                             tint: volumeTint(entry),
                             backgroundOpacity: UI.Card.Metric.iconBackgroundOpacity)
        } titleAccessory: {
            UI.Badge.Text(text: entry.kind.rawValue, font: .caption2.weight(.semibold))
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            UI.Control.RowMenu(accessibilityLabel: AppText.string("menu.volumeActions", defaultValue: "Volume actions")) {
                volumeMenu(entry)
            }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            UI.Card.FooterMini {
                UI.Symbol.Image(systemName: "shippingbox", size: .caption2)
            } text: {
                UI.Card.MetricText(text: volumeContainerCount(entry))
                    .designSecondaryValueStyle()
            }
        } footerActions: {
            if entry.resource != nil {
                Button(role: .destructive) { deletingVolume = entry.resource } label: {
                    UI.Card.FooterMini {
                        UI.Symbol.Image(systemName: "trash", tone: .error, size: .body)
                    } text: {
                        EmptyView()
                    }
                }
                .buttonStyle(.plain)
                .help(AppText.delete)
                .accessibilityLabel(AppText.delete)
            }
        } widget: {
            EmptyView()
        }
        .contextMenu { volumeMenu(entry) }
    }

    private func volumeCardSubtitle(_ entry: VolumeInventoryEntry) -> String? {
        var parts: [String] = []
        parts.append(app.runtimeDescriptor(for: entry.runtimeKind)?.displayName ?? entry.runtimeKind.rawValue)
        if let destination = entry.destination { parts.append(destination) }
        if let subtitle = entry.subtitle { parts.append(subtitle) }
        return parts.joined(separator: " · ")
    }

    private func volumeContainerCount(_ entry: VolumeInventoryEntry) -> String {
        switch entry.containers.count {
        case 0: return AppText.string("volume.containers.none", defaultValue: "No containers")
        case 1: return AppText.string("volume.containers.one", defaultValue: "1 container")
        default: return AppText.string("volume.containers.count", defaultValue: "\(entry.containers.count) containers")
        }
    }

    private func volumeTint(_ entry: VolumeInventoryEntry) -> Color {
        switch entry.kind {
        case .named: return .accentColor
        case .localPath: return .orange
        case .anonymous: return .secondary
        }
    }

    @ViewBuilder
    private func volumeMenu(_ entry: VolumeInventoryEntry) -> some View {
        UI.Copy.ValueLabel(AppText.string("volume.copySource", defaultValue: "Copy source"),
                           value: entry.source ?? entry.title)
        if let destination = entry.destination {
            UI.Copy.ValueLabel(AppText.string("volume.copyDestination", defaultValue: "Copy destination"),
                               value: destination,
                               systemName: "arrow.down.doc")
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

    private func deleteVolume(_ volume: Core.Volume.Resource) async {
        guard let client = app.client else { return }
        if let error = await app.captured({
            _ = try await client.deleteVolumes([volume.name], runtimeKind: volume.runtimeKind)
        }) { app.flash(error) }
        await app.refreshVolumes()
    }

    private var automationCard: some View {
        card {
            Text(AppText.string("system.page.automation", defaultValue: "Automation")).designHeadlineLabelStyle()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                automationRow(icon: "arrow.triangle.2.circlepath",
                              title: AppText.string("automation.imageUpdateCheck", defaultValue: "Image update check"),
                              detail: app.settings.imageUpdateChecksEnabled
                                  ? "\(backgroundTaskDetail(now: context.date)) · \(app.imageUpdateIntervalDescription)"
                                  : AppText.string("status.paused", defaultValue: "Paused"),
                              isOn: settingBinding(\.imageUpdateChecksEnabled)) {
                    if app.settings.imageUpdateChecksEnabled {
                        Text(countdown(to: app.imageUpdateNextRunDate, now: context.date))
                            .designSecondaryMonospacedCaption()
                            .monospacedDigit()
                        UI.Action.Group(UI.Action.Item(systemName: "arrow.triangle.2.circlepath",
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
                UI.Action.Group(UI.Action.Item(systemName: "arrow.down.app",
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
            UI.List.MetadataRow(systemImage: "dot.radiowaves.left.and.right",
                              title: AppText.string("automation.refreshLoop", defaultValue: "Refresh loop")) {
                UI.State.StatusText(app.coordinator.isActive ? "Active" : "Paused",
                                 tone: app.coordinator.isActive ? .success : .neutral)
            }
        }
    }

    private func automationRow<Trailing: View>(icon: String, title: String, detail: String,
                                               isOn: Binding<Bool>,
                                               @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        UI.List.MetadataRow(systemImage: icon,
                          title: title,
                          subtitle: detail,
                          tint: isOn.wrappedValue ? .accentColor : .secondary) {
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
            case .containers:
                for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.containers) {
                    _ = try await client.pruneContainers(runtimeKind: descriptor.kind)
                }
            case .images:
                for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.images) {
                    _ = try await client.pruneImages(all: false, runtimeKind: descriptor.kind)
                }
            case .volumes:
                for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.volumes) {
                    _ = try await client.pruneVolumes(runtimeKind: descriptor.kind)
                }
            case .networks:
                for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.networks) {
                    _ = try await client.pruneNetworks(runtimeKind: descriptor.kind)
                }
            }
            await app.refreshSystemResources()
            await app.refreshSystem()
        } catch let error as Core.Command.Error { app.flash(error.appDisplayMessage) }
        catch { app.flash(error.appDisplayMessage) }
    }

    private func reclaimAll() async {
        guard let client = app.client else { return }
        if let error = await app.captured({
            for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.containers) {
                _ = try await client.pruneContainers(runtimeKind: descriptor.kind)
            }
            for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.images) {
                _ = try await client.pruneImages(all: false, runtimeKind: descriptor.kind)
            }
            for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.volumes) {
                _ = try await client.pruneVolumes(runtimeKind: descriptor.kind)
            }
            for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.networks) {
                _ = try await client.pruneNetworks(runtimeKind: descriptor.kind)
            }
        }) { app.flash(error) }
        await app.refreshSystemResources()
        await app.refreshSystem()
    }

    // MARK: Runtime

    private var runtimeStatusCard: some View {
        card {
            HStack(spacing: UI.Layout.Spacing.s) {
                UI.Badge.Dot(color: app.serviceHealthy ? .green : .orange,
                                size: UI.Control.Size.serviceDot)
                Text(AppText.string("system.containerRuntime", defaultValue: "Container runtime")).designHeadlineLabelStyle()
                UI.Badge.Status(text: app.serviceLabel,
                                  tint: app.serviceHealthy ? .green : .orange)
                Spacer(minLength: 0)
                if let version = app.systemStatus?.apiServerVersion {
                    Text(version).designSecondaryMonospacedCaption()
                        .textSelection(.enabled)
                }
            }
            HStack(spacing: UI.Layout.Spacing.s) {
                UI.Control.MetricTile(label: AppText.sectionContainers,
                                 value: "\(app.containers.running.count)",
                                 caption: AppText.string("status.running.lowercase", defaultValue: "running"))
                UI.Control.MetricTile(label: AppText.sectionImages, value: "\(app.images.count)")
                UI.Control.MetricTile(label: AppText.string("system.diskUsed", defaultValue: "Disk used"),
                                 value: app.diskUsage.map { Format.bytes($0.totalSizeInBytes) } ?? "—")
            }
            if working { UI.State.ProgressIndicator() }
        }
    }

    private func run(_ action: @escaping () async -> Void) {
        working = true
        Task { await action(); working = false }
    }
}
