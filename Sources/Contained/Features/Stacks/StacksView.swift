import SwiftUI
import AppKit
import ContainedCore

/// Stacks: import a `compose.yaml`, translate the common subset to container runs, launch them as a
/// labelled group, and manage running stacks. AppKit bridge (flagged): `NSOpenPanel` to pick a file.
struct StacksView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var preview: ComposeProject?
    @State private var importError: String?

    /// Running containers grouped by their `contained.stack` label.
    private var stacks: [(name: String, containers: [ContainerSnapshot])] {
        let grouped = Dictionary(grouping: app.containers.snapshots.filter {
            $0.configuration.labels["contained.stack"] != nil
        }) { $0.configuration.labels["contained.stack"]! }
        return grouped.map { (name: $0.key, containers: $0.value) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if stacks.isEmpty {
                ContentUnavailableView {
                    Label("No stacks", systemImage: "square.on.square")
                } description: {
                    Text("Import a compose.yaml to launch a multi-container stack.")
                } actions: {
                    Button("Import compose file…") { importCompose() }.buttonStyle(.glassProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.m) {
                        ForEach(stacks, id: \.name) { stack in stackCard(stack) }
                    }
                    .padding(Tokens.Space.l)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
        }
        .sheet(item: $preview) { project in
            ComposePreviewSheet(project: project) { await launch(project) }
        }
        // Consume a File ▸ Import Compose… request (works whether this view was already on screen or
        // was just switched to by the Templates section).
        .onAppear { consumeComposeImportRequest() }
        .onChange(of: ui.pendingComposeImport) { _, pending in if pending { consumeComposeImportRequest() } }
        .alert("Couldn't import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }) else { return false }
            parseCompose(at: url)
            return true
        }
    }

    private func stackCard(_ stack: (name: String, containers: [ContainerSnapshot])) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack {
                Label(stack.name, systemImage: "square.on.square").font(.headline)
                Spacer()
                let running = stack.containers.filter { $0.state == .running }.count
                Text("\(running)/\(stack.containers.count) running").font(.caption).foregroundStyle(.secondary)
                GlassRowMenu { stackMenu(stack) }
            }
            ForEach(stack.containers) { container in
                HStack(spacing: Tokens.Space.s) {
                    StatusOrb(presentation: StatusPresentation(container.state), size: 7)
                    Text(container.displayName).font(.callout)
                    Spacer()
                    Text(Format.shortImage(container.image)).font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Tokens.Space.l)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card, glass: .clear)
        .contextMenu { stackMenu(stack) }
    }

    @ViewBuilder
    private func stackMenu(_ stack: (name: String, containers: [ContainerSnapshot])) -> some View {
        Button { Task { for c in stack.containers { await app.containers.start(c.id) } } } label: {
            Label("Start all", systemImage: "play.fill")
        }
        Button { Task { for c in stack.containers { await app.containers.stop(c.id) } } } label: {
            Label("Stop all", systemImage: "stop.fill")
        }
        Divider()
        Button(role: .destructive) {
            Task { for c in stack.containers { await app.containers.remove(c.id, force: true) } }
        } label: { Label("Remove all", systemImage: "trash") }
    }

    /// If a menu-driven import is pending, clear the flag and open the picker.
    private func consumeComposeImportRequest() {
        guard ui.pendingComposeImport else { return }
        ui.pendingComposeImport = false
        importCompose()
    }

    private func importCompose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.yaml]
        panel.message = "Choose a compose.yaml"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        parseCompose(at: url)
    }

    /// Parse a compose file at `url` into the preview sheet (shared by the picker and drag-and-drop).
    private func parseCompose(at url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let project = url.deletingLastPathComponent().lastPathComponent
            preview = try ComposeParser.parse(text, projectName: project.isEmpty ? "stack" : project)
        } catch let e as ComposeError {
            importError = { if case .invalid(let m) = e { return m }; return "Invalid compose file." }()
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Launch a stack in dependency order. `service_healthy` dependencies are awaited (bounded by a
    /// timeout) before their dependents start; the runtime has no native ordering, so the app does it
    /// (same philosophy as the restart watchdog).
    private func launch(_ project: ComposeProject) async {
        let (order, cycle) = ComposeOrder.sorted(project.services)
        if cycle { app.flash("Stack has a dependency cycle — launching in declared order.") }
        let byKey = Dictionary(uniqueKeysWithValues: project.services.map { ($0.key, $0) })
        for key in order {
            guard let service = byKey[key], service.image != nil else { continue }
            for dep in service.dependsOn where dep.condition == .healthy {
                await waitHealthy(byKey[dep.service])
            }
            let spec = RunSpec(service: service, projectName: project.name)
            // Pull the service image first (with progress) if it isn't local, then run.
            _ = await app.createContainer(spec)
        }
        preview = nil
    }

    /// Poll a dependency's compose healthcheck until it passes or a 60s deadline elapses.
    private func waitHealthy(_ service: ComposeService?) async {
        guard let service, let check = service.healthcheck, let client = app.client else { return }
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            if (try? await client.execCapture(service.name, check.test)) != nil { return }  // exit 0 = healthy
            try? await Task.sleep(for: .seconds(min(max(check.intervalSeconds, 1), 5)))
        }
        app.flash("Timed out waiting for \(service.name) to become healthy.")
    }
}

/// Preview a parsed compose project before launching: services + the not-translated report.
struct ComposePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: ComposeProject
    let onLaunch: () async -> Void
    @State private var launching = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Launch “\(project.name)”", subtitle: "\(project.services.count) services",
                        onCancel: { dismiss() }) {
                if launching {
                    ProgressView().controlSize(.small).frame(width: Tokens.IconSize.control, height: Tokens.IconSize.control)
                } else {
                    GlassCircleButton(systemName: "play.fill", prominent: true, help: "Launch") {
                        launching = true
                        Task { await onLaunch(); dismiss() }
                    }
                    .disabled(project.services.allSatisfy { $0.image == nil })
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.m) {
                    ForEach(project.services) { service in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Label(service.name, systemImage: "shippingbox").font(.callout.weight(.medium))
                                Spacer()
                                Text(service.image ?? "no image — skipped")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(service.image == nil ? .orange : .secondary)
                            }
                            if !service.ports.isEmpty {
                                Text("ports: \(service.ports.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(Tokens.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                    }
                    if !project.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Not translated", systemImage: "exclamationmark.triangle").font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            ForEach(Array(project.warnings.enumerated()), id: \.offset) { _, w in
                                Text("• \(w)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(Tokens.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                    }
                }
                .padding(Tokens.Space.l)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .frame(Tokens.SheetSize.inspector)
        .sheetMaterial()
    }
}
