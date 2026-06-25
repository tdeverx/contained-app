import SwiftUI
import AppKit
import ContainedCore

/// The enlarged container detail (target of the card-zoom transition), with tabs: overview, logs,
/// terminal, stats, files, inspect.
struct ContainerDetailView: View {
    @Environment(AppModel.self) private var app
    let snapshot: ContainerSnapshot
    var onClose: () -> Void = {}

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case logs = "Logs"
        case terminal = "Terminal"
        case stats = "Stats"
        case history = "History"
        case files = "Files"
        case inspect = "Inspect"
        var id: String { rawValue }
    }
    @State private var tab: Tab = .overview
    @State private var confirmingDelete = false
    @State private var showCustomize = false
    @State private var showEdit = false

    private var style: Personalization {
        app.personalization.resolved(id: snapshot.id, image: snapshot.image)
    }
    private var presentation: StatusPresentation { StatusPresentation(snapshot.state) }
    private var isRunning: Bool { snapshot.state == .running }

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("Tab", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, Tokens.Space.l)
            .padding(.bottom, Tokens.Space.s)
            Divider()
            content
        }
        .frame(minWidth: 640, minHeight: 520)
        .background(.regularMaterial)
        .confirmationDialog("Delete \(style.displayName(fallback: snapshot.id))?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { await app.containers.remove(snapshot.id, force: true); onClose() }
            }
        } message: {
            Text("This removes the container. This can't be undone.")
        }
        .sheet(isPresented: $showCustomize) { CustomizeSheet(snapshot: snapshot) }
        .sheet(isPresented: $showEdit) {
            ContainerEditSheet(mode: .edit(snapshot, onComplete: onClose))
        }
    }

    private var subtitle: String {
        isRunning ? "\(presentation.label) · ↑ \(Format.uptime(since: snapshot.startedDate))" : presentation.label
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: style.symbol)
                .font(.system(size: 17))
                .foregroundStyle(style.color)
                .frame(width: Tokens.IconSize.headerChip, height: Tokens.IconSize.headerChip)
                .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(style.displayName(fallback: snapshot.id)).font(.headline)
                HStack(spacing: 6) {
                    StatusOrb(presentation: presentation, size: 7)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isRunning {
                GlassCircleButton(systemName: "stop.fill", help: "Stop") { Task { await app.containers.stop(snapshot.id) } }
                GlassCircleButton(systemName: "arrow.clockwise", help: "Restart") { Task { await app.containers.restart(snapshot.id) } }
            } else {
                GlassCircleButton(systemName: "play.fill", help: "Start") { Task { await app.containers.start(snapshot.id) } }
            }
            GlassRowMenu {
                Button { showCustomize = true } label: { Label("Customize…", systemImage: "paintbrush.pointed") }
                Button { showEdit = true } label: { Label("Edit…", systemImage: "slider.horizontal.3") }
                Button { copyToPasteboard(snapshot.id) } label: { Label("Copy ID", systemImage: "doc.on.doc") }
                Button { exportFilesystem() } label: { Label("Export filesystem (tar)…", systemImage: "arrow.up.doc") }
                Divider()
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
            }
            GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true) { onClose() }
        }
        .padding(Tokens.Space.l)
    }

    /// Export the container's filesystem as a tar archive (not an OCI image — the runtime has no
    /// native `commit`).
    private func exportFilesystem() {
        guard let client = app.client else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.nameFieldStringValue = "\(snapshot.id)-filesystem.tar"
        panel.message = "Export \(snapshot.id)'s filesystem (a tar archive, not an image)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            if let error = await app.captured({ _ = try await client.exportContainer(snapshot.id, to: url.path) }) {
                app.flash(error)
            } else {
                app.flash("Exported \(url.lastPathComponent)")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .overview: ContainerOverviewTab(snapshot: snapshot)
        case .logs: LogsTab(snapshot: snapshot)
        case .stats: StatsTab(snapshot: snapshot)
        case .history: ContainerHistoryTab(snapshot: snapshot)
        case .terminal: TerminalTab(snapshot: snapshot)
        case .files: FilesTab(snapshot: snapshot)
        case .inspect: ContainerInspectTab(snapshot: snapshot)
        }
    }
}

