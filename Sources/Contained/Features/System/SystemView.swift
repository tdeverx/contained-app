import SwiftUI
import ContainedCore

/// System overview: service status + controls, `system df` disk usage, a Prune Center, the daemon
/// properties, and a system-logs viewer.
struct SystemView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var working = false
    @State private var pruneTarget: PruneTarget?
    @State private var showLogs = false
    @State private var showActivity = false
    @State private var dnsDomains: [String] = []
    @State private var confirmingKernel = false
    @State private var addingDNS = false
    @State private var newDomain = ""
    @State private var deletingDomain: String?

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: Tokens.Space.m)]

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
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                serviceCard
                backgroundTasksSection
                if let usage = app.diskUsage { diskSection(usage) }
                pruneSection
                kernelDNSSection
                if let props = app.properties { propertiesSection(props) }
            }
            .padding(Tokens.Space.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .task { await app.refreshResource(.system); await loadDNS() }
        .onAppear { consumePending() }
        .onChange(of: ui.pendingAction) { _, _ in consumePending() }
        .sheet(isPresented: $showLogs) { SystemLogsSheet() }
        .sheet(isPresented: $showActivity) { ActivityView() }
        .confirmationDialog(pruneTarget?.title ?? "", isPresented: pruneBinding, presenting: pruneTarget) { target in
            Button("Remove", role: .destructive) { Task { await prune(target) } }
        } message: { _ in Text("This permanently removes unused resources to reclaim disk space.") }
        .confirmationDialog("Install the recommended kernel?", isPresented: $confirmingKernel) {
            Button("Download & install") { Task { await installKernel() } }
        } message: {
            Text("Downloads and sets the recommended kernel as the default. This may take a moment.")
        }
        .confirmationDialog("Delete DNS domain \(deletingDomain ?? "")?",
                            isPresented: deletingDomainBinding, presenting: deletingDomain) { domain in
            Button("Delete", role: .destructive) { Task { await deleteDNS(domain) } }
        } message: { _ in Text("This may prompt for your administrator password (handled by the container CLI).") }
        .alert("New local DNS domain", isPresented: $addingDNS) {
            TextField("example.test", text: $newDomain)
            Button("Cancel", role: .cancel) { newDomain = "" }
            Button("Create") { Task { await addDNS() } }
        } message: {
            Text("Creating a domain may prompt for your administrator password (handled by the container CLI).")
        }
    }

    // MARK: Kernel & DNS (privileged)

    private var kernelDNSSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Kernel & DNS").font(.headline)
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                HStack {
                    Label("Recommended kernel", systemImage: "cpu")
                    Spacer()
                    Button("Install recommended…") { confirmingKernel = true }.buttonStyle(.glass)
                }
                revealCLIHint("container system kernel set --recommended")
                Divider()
                HStack {
                    Label("Local DNS domains", systemImage: "globe")
                    Spacer()
                    Button { newDomain = ""; addingDNS = true } label: { Image(systemName: "plus") }.buttonStyle(.glass)
                }
                if dnsDomains.isEmpty {
                    Text("No local DNS domains.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(dnsDomains, id: \.self) { domain in
                        HStack {
                            Text(domain).font(.system(.callout, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) { deletingDomain = domain } label: { Image(systemName: "trash") }
                                .buttonStyle(.glass).buttonBorderShape(.circle).controlSize(.small)
                        }
                    }
                }
                Text("Kernel and DNS changes may prompt for your administrator password — handled by the container CLI; Contained never sees it.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card)
        }
    }

    /// A small copyable CLI hint, shown only when the Reveal-CLI setting is on.
    @ViewBuilder
    private func revealCLIHint(_ command: String) -> some View {
        if app.settings.revealCLI {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "terminal").foregroundStyle(.secondary)
                Text(command).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button { copyToPasteboard(command) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Copy command")
            }
        }
    }

    private var deletingDomainBinding: Binding<Bool> {
        Binding(get: { deletingDomain != nil }, set: { if !$0 { deletingDomain = nil } })
    }

    private func loadDNS() async {
        guard let client = app.client else { return }
        if let domains = try? await client.dnsDomains() { dnsDomains = domains }
    }

    /// Pick up a toolbar/menu action addressed to the System page.
    private func consumePending() {
        switch ui.pendingAction {
        case .activityHistory: ui.pendingAction = nil; showActivity = true
        case .systemLogs:      ui.pendingAction = nil; showLogs = true
        default: break
        }
    }

    private func installKernel() async {
        guard let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.setRecommendedKernel() }) { app.flash(error) }
        else { app.flash("Recommended kernel installed"); await app.refreshResource(.system) }
    }

    private func addDNS() async {
        let domain = newDomain.trimmingCharacters(in: .whitespaces)
        newDomain = ""
        guard !domain.isEmpty, let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.createDNSDomain(domain) }) { app.flash(error) }
        else { await loadDNS() }
    }

    private func deleteDNS(_ domain: String) async {
        guard let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.deleteDNSDomain(domain) }) { app.flash(error) }
        else { await loadDNS() }
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
                            .font(.system(size: 18))
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
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card)
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
                Image(systemName: symbol).font(.system(size: 16))
                Text(title).font(.caption).multilineTextAlignment(.center)
                if let reclaimable, reclaimable > 0 {
                    Text(Format.bytes(reclaimable)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, Tokens.Space.m)
        }
        .buttonStyle(.glass)
    }

    private func propertiesSection(_ props: SystemProperties) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Defaults").font(.headline)
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                if let d = props.container {
                    if let c = d.cpus { labeled("Default CPUs", "\(c)") }
                    if let m = d.memory { labeled("Default memory", m) }
                }
                if let b = props.build {
                    if let img = b.image { labeled("Builder image", img) }
                    if let r = b.rosetta { labeled("Builder Rosetta", r ? "on" : "off") }
                }
                if let k = props.kernel, let path = k.binaryPath { labeled("Kernel", path) }
            }
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card)
        }
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
            await app.refreshResource(.system)
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
                if let version = status.apiServerVersion { labeled("API server", version) }
                if let root = status.installRoot { labeled("Install root", root) }
                if let appRoot = status.appRoot { labeled("App root", appRoot) }
            }
            if let cli = app.cliVersion { labeled("CLI", "v\(cli)") }
            HStack(spacing: Tokens.Space.s) {
                Button { run { await app.startService() } } label: { Label("Start", systemImage: "play.fill") }
                    .disabled(app.serviceHealthy || working)
                Button { run { await app.stopService() } } label: { Label("Stop", systemImage: "stop.fill") }
                    .disabled(!app.serviceHealthy || working)
                Button { run { await app.restartService() } } label: { Label("Restart", systemImage: "arrow.clockwise") }
                    .disabled(working)
                if working { ProgressView().controlSize(.small) }
            }
            .buttonStyle(.glass)
            .padding(.top, Tokens.Space.xs)
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card)
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
                        .font(.system(size: 10)).foregroundStyle(.secondary)
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
                GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true) { dismiss() }
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
