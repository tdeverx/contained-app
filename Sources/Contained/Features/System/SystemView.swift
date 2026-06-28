import SwiftUI
import ContainedCore

/// System overview content: service status + controls, volumes, `system df` disk usage, a Prune
/// Center, and a system-logs viewer. Hosted header-less in the toolbar System morph panel (there's no
/// standalone System page). Daemon defaults, kernel, and DNS configuration live in Settings → Runtime.
struct SystemContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    /// Flat cards (no shadow) when hosted in the toolbar morph panel; elevated if shown standalone.
    var elevated = true
    var onClose: () -> Void = {}

    @State private var working = false
    @State private var pruneTarget: PruneTarget?
    @State private var showLogs = false
    @State private var inspectingVolume: VolumeResource?
    @State private var deletingVolume: VolumeResource?

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: Tokens.Space.m)]
    private let volumeColumns = [GridItem(.adaptive(minimum: Tokens.CardSize.largeMin,
                                                    maximum: Tokens.CardSize.largeMax),
                                          spacing: Tokens.Space.m)]

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
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    serviceCard
                    backgroundTasksSection
                    volumesSection
                    if let usage = app.diskUsage { diskSection(usage) }
                    pruneSection
                }
                .padding(Tokens.Space.l)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .task { await app.refreshSystemResources() }
        .sheet(isPresented: $showLogs) { SystemLogsSheet() }
        .sheet(item: $inspectingVolume) { JSONInspectorSheet(title: $0.name, value: $0) }
        .confirmationDialog("Delete volume \(deletingVolume?.name ?? "")?",
                            isPresented: deletingVolumeBinding, presenting: deletingVolume) { volume in
            Button("Delete", role: .destructive) { Task { await deleteVolume(volume) } }
        } message: { _ in Text("This permanently removes the volume and its data.") }
        .confirmationDialog(pruneTarget?.title ?? "", isPresented: pruneBinding, presenting: pruneTarget) { target in
            Button("Remove", role: .destructive) { Task { await prune(target) } }
        } message: { _ in Text("This permanently removes unused resources to reclaim disk space.") }
    }

    private var header: some View {
        ResourceCardHeader {
            GlassButtonItem(systemName: "gearshape.2", help: "System", isLabel: true)
        } content: {
            VStack(alignment: .leading, spacing: 1) {
                Text("System").font(.headline)
                Text("\(app.volumes.count) volume\(app.volumes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } trailing: {
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
            }
        }
        .padding(Tokens.Space.l)
    }

    // MARK: Volumes (migrated here from the standalone sidebar section)

    private var sortedVolumes: [VolumeResource] {
        app.volumes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var volumesSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack {
                Text("Volumes").font(.headline)
                Spacer()
                Button { onClose(); ui.dispatch(.createVolume) } label: { Label("New Volume", systemImage: "plus") }
                    .buttonStyle(.glass)
            }
            if app.volumes.isEmpty {
                emptyVolumesCard
            } else {
                LazyVGrid(columns: volumeColumns, spacing: Tokens.Space.m) {
                    ForEach(sortedVolumes) { volume in
                        VolumeCard(volume: volume,
                                   elevated: elevated,
                                   onInspect: { inspectingVolume = volume },
                                   onDelete: { deletingVolume = volume })
                    }
                }
            }
        }
    }

    private var emptyVolumesCard: some View {
        ResourceGlassCard(size: .small, elevated: elevated) {
            ResourceCardHeader {
                Image(systemName: "externaldrive")
                    .foregroundStyle(.secondary)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    Text("No volumes").font(.callout.weight(.medium))
                    Text("Create a volume to share persistent storage with containers.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } trailing: {
                EmptyView()
            }
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

    private var pruneSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Reclaim space").font(.headline)
            HStack(spacing: Tokens.Space.m) {
                pruneButton("Stopped containers", "shippingbox", .containers, nil)
                pruneButton("Unused images", "square.stack.3d.up", .images, app.diskUsage?.images.reclaimable)
                pruneButton("Unused volumes", "externaldrive", .volumes, app.diskUsage?.volumes.reclaimable)
                pruneButton("Unused networks", "network", .networks, nil)
            }
        }
    }

    private var backgroundTasksSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Background tasks").font(.headline)
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: Tokens.Space.m) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: Tokens.IconSize.headerChip, height: Tokens.IconSize.headerChip)
                            .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Image update check").font(.callout.weight(.medium))
                            Text(backgroundTaskDetail(now: context.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(countdown(to: app.imageUpdateNextRunDate, now: context.date))
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                            Text(app.imageUpdateIntervalDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            Task { await app.runImageUpdateSweepNow() }
                        } label: {
                            Label("Run Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                Divider()
                HStack {
                    Label("Refresh loop", systemImage: "dot.radiowaves.left.and.right")
                    Spacer()
                    Text(app.coordinator.isActive ? "Active" : "Paused")
                        .font(.callout)
                        .foregroundStyle(app.coordinator.isActive ? .green : .secondary)
                }
            }
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: elevated)
        }
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

    private func pruneButton(_ title: String, _ symbol: String, _ target: PruneTarget, _ reclaimable: UInt64?) -> some View {
        Button { pruneTarget = target } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption).multilineTextAlignment(.center)
                if let reclaimable, reclaimable > 0 {
                    Text(Format.bytes(reclaimable)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, Tokens.Space.m)
        }
        .buttonStyle(.glass)
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

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(spacing: Tokens.Space.s) {
                Circle().fill(app.serviceHealthy ? Color.green : Color.orange).frame(width: 10, height: 10)
                Text("Container service").font(.headline)
                Spacer()
                Text(app.serviceLabel).font(.callout).foregroundStyle(.secondary)
            }
            if let status = app.systemStatus {
                if let root = status.installRoot { labeled("Install root", root) }
                if let appRoot = status.appRoot { labeled("App root", appRoot) }
            }
            HStack(spacing: Tokens.Space.s) {
                Button { run { await app.startService() } } label: { Label("Start", systemImage: "play.fill") }
                    .disabled(app.serviceHealthy || working)
                Button { run { await app.stopService() } } label: { Label("Stop", systemImage: "stop.fill") }
                    .disabled(!app.serviceHealthy || working)
                Button { run { await app.restartService() } } label: { Label("Restart", systemImage: "arrow.clockwise") }
                    .disabled(working)
                Spacer(minLength: 0)
                Button { showLogs = true } label: { Label("Logs", systemImage: "text.alignleft") }
                if working { ProgressView().controlSize(.small) }
            }
            .buttonStyle(.glass)
            .padding(.top, Tokens.Space.xs)
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: elevated)
    }

    private func diskSection(_ usage: DiskUsage) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack {
                Text("Disk usage").font(.headline)
                Spacer()
                Text("\(Format.bytes(usage.totalReclaimableBytes)) reclaimable")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: Tokens.Space.m) {
                usageTile("Containers", "shippingbox", usage.containers)
                usageTile("Images", "square.stack.3d.up", usage.images)
                usageTile("Volumes", "externaldrive", usage.volumes)
            }
        }
    }

    private func usageTile(_ label: String, _ symbol: String, _ category: DiskUsage.Category) -> some View {
        MetricTile(label: "\(label) · \(category.active)/\(category.total) active",
                   value: Format.bytes(category.sizeInBytes), systemImage: symbol,
                   tint: .accentColor)
            .overlay(alignment: .bottomTrailing) {
                if category.reclaimable > 0 {
                    Text("\(Format.bytes(category.reclaimable)) reclaimable")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(Tokens.Space.m)
                }
            }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
                .font(.system(.callout, design: .monospaced))
        }
        .font(.callout)
    }

    private func run(_ action: @escaping () async -> Void) {
        working = true
        Task { await action(); working = false }
    }
}

/// A large, customizable volume card for the System page. Plots aggregated read/write I/O (summed
/// across the containers that mount the volume) and offers inspect / copy / delete.
private struct VolumeCard: View {
    @Environment(AppModel.self) private var app
    let volume: VolumeResource
    var elevated = true
    var onInspect: () -> Void
    var onDelete: () -> Void

    @State private var localMetric: GraphMetric?

    private static let metrics: [GraphMetric] = [.diskRead, .diskWrite]
    private var style: Personalization { app.volumeStyle(for: volume.name) }
    private var metric: GraphMetric {
        let stored = Self.metrics.contains(style.graphMetric) ? style.graphMetric : .diskRead
        return localMetric ?? stored
    }
    private var samples: [Double] { app.volumeIOHistory(for: volume.name, metric: metric) }

    private var subtitle: String {
        let config = volume.configuration
        let parts = [config.sizeInBytes.map { Format.bytes($0) }, config.format, config.source].compactMap { $0 }
        return parts.isEmpty ? "Local volume" : parts.joined(separator: "  ·  ")
    }

    var body: some View {
        ResourceGlassCard(size: .large,
                          fill: style.fillBackground ? style.color : nil,
                          fillOpacity: style.backgroundOpacity,
                          gradient: style.gradient,
                          gradientAngle: style.gradientAngle,
                          elevated: elevated) {
            ResourceCardHeader {
                CardStyleButton(style: style, target: .volume(name: volume.name), help: "Customize volume")
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: style.nickname.isEmpty ? volume.name : style.nickname)
                    ResourceCardSubtitleText(text: subtitle)
                }
            } trailing: {
                EmptyView()
            }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            ForEach(Self.metrics) { chip($0) }
        } footerActions: {
            action("doc.text.magnifyingglass", help: "Inspect", action: onInspect)
            action("doc.on.doc", help: "Copy name") { copyToPasteboard(volume.name) }
            action("trash", help: "Delete", tint: .red, action: onDelete)
        } widget: {
            LiveSparkline(samples: samples, color: style.color, style: style.graphStyle)
                .frame(height: 58)
        }
        .contextMenu { menu }
    }

    /// A tappable read/write chip showing the current rate; selecting it switches the plotted metric.
    private func chip(_ which: GraphMetric) -> some View {
        let active = metric == which
        let rate = app.volumeIORate(for: volume.name, metric: which)
        return Button { localMetric = which } label: {
            ResourceCardFooterMini {
                Image(systemName: which.systemImage).font(.caption2)
            } text: {
                ResourceCardMetricText(text: Format.compactRate(rate))
            }
            .foregroundStyle(active ? AnyShapeStyle(style.color) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .help(which == .diskRead ? "Read" : "Write")
        .accessibilityLabel(which == .diskRead ? "Read" : "Write")
    }

    private func action(_ systemName: String, help: String, tint: Color? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ResourceCardFooterMini {
                Image(systemName: systemName).font(.body)
            } text: {
                EmptyView()
            }
        }
            .buttonStyle(.plain)
            .foregroundStyle(tint ?? .secondary)
            .help(help)
            .accessibilityLabel(help)
    }

    @ViewBuilder
    private var menu: some View {
        Button(action: onInspect) { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
        Button { copyToPasteboard(volume.name) } label: { Label("Copy name", systemImage: "doc.on.doc") }
        Divider()
        Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
    }
}

/// Viewer for `container system logs` — last 500 lines, with an optional live follow.
struct SystemLogsSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var follow = false
    @State private var session = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.m) {
                Text("System logs").font(.headline)
                Toggle(isOn: $follow) { Label("Follow", systemImage: "arrow.down.to.line") }
                    .toggleStyle(.button).buttonStyle(.glass).buttonBorderShape(.capsule)
                    .onChange(of: follow) { _, _ in session += 1 }
                Spacer()
                GlassButton(singleItem: true) {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true) {
                        dismiss()
                    }
                }
            }
            .padding(Tokens.Space.l)
            if let client = app.client {
                StreamConsole(stream: { client.streamSystemLogs(follow: follow, last: 500) })
                    .id(session)
                    .padding(.horizontal, Tokens.Space.l)
                    .padding(.bottom, Tokens.Space.l)
            }
        }
        .frame(Tokens.SheetSize.wide)
        .sheetMaterial()
    }
}
