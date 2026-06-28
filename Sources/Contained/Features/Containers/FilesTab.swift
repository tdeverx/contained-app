import SwiftUI
import AppKit
import ContainedCore

/// Browse a running container's filesystem (`exec ls -1ap`) and copy files in/out with the native
/// `container cp`. AppKit bridge (flagged): `NSOpenPanel`/`NSSavePanel` for host file selection.
struct FilesTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: ContainerSnapshot

    @State private var path = "/"
    @State private var entries: [String] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        if snapshot.state != .running {
            ContentUnavailableView {
                Label("Not running", systemImage: "folder")
            } description: { Text("Start the container to browse its files.") }
        } else {
            VStack(spacing: 0) {
                pathBar
                Divider()
                listing
            }
            .task(id: path) { await load() }
        }
    }

    private var pathBar: some View {
        HStack(spacing: Tokens.Space.s) {
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "chevron.up", help: "Parent") { goUp() }
                    .disabled(path == "/")
            }
            Text(path).font(.system(.callout, design: .monospaced)).lineLimit(1).truncationMode(.middle)
            Spacer()
            if loading { ProgressView().controlSize(.small) }
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "square.and.arrow.down", help: "Copy a file into this folder") {
                    copyIn()
                }
            }
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "arrow.clockwise", help: "Refresh") { Task { await load() } }
            }
        }
        .padding(Tokens.Space.m)
    }

    @ViewBuilder
    private var listing: some View {
        if let error {
            ContentUnavailableView {
                Label("Couldn't read folder", systemImage: "exclamationmark.triangle")
            } description: { Text(error) }
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(entries, id: \.self) { entry in row(entry) }
                }
                .padding(Tokens.Space.m)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }

    private func row(_ entry: String) -> some View {
        let isDir = entry.hasSuffix("/")
        let name = isDir ? String(entry.dropLast()) : entry
        return HStack(spacing: Tokens.Space.s) {
            Image(systemName: isDir ? "folder.fill" : "doc")
                .foregroundStyle(isDir ? Color.accentColor : Color.secondary)
                .frame(width: 18)
            Text(name).font(.system(.callout, design: .monospaced))
            Spacer()
            if isDir {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            } else {
                Button { copyOut(name) } label: { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Copy to host")
            }
        }
        .padding(.vertical, 4).padding(.horizontal, Tokens.Space.s)
        .contentShape(Rectangle())
        .onTapGesture { if isDir { path = joined(name) + "/" } }
    }

    // MARK: Actions

    private func load() async {
        guard let client = app.client else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            let out = try await client.execCapture(snapshot.id, ["ls", "-1ap", path])
            entries = out.split(separator: "\n").map(String.init)
                .filter { $0 != "./" && $0 != "../" && !$0.isEmpty }
                .sorted { ($0.hasSuffix("/") ? 0 : 1, $0.lowercased()) < ($1.hasSuffix("/") ? 0 : 1, $1.lowercased()) }
        } catch let e as CommandError { error = e.userMessage }
        catch { self.error = error.localizedDescription }
    }

    private func goUp() {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let slash = trimmed.lastIndex(of: "/") else { path = "/"; return }
        let parent = String(trimmed[..<slash])
        path = parent.isEmpty ? "/" : parent + "/"
    }

    private func joined(_ name: String) -> String {
        path.hasSuffix("/") ? path + name : path + "/" + name
    }

    private func copyOut(_ name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.message = "Copy \(name) from the container"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        Task {
            do {
                _ = try await app.client?.copy(source: "\(snapshot.id):\(joined(name))", destination: dest.path)
                app.flash("Copied \(name) to host")
            } catch let e as CommandError { app.flash(e.userMessage) }
            catch { app.flash(error.localizedDescription) }
        }
    }

    private func copyIn() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Copy a file into \(path)"
        guard panel.runModal() == .OK, let src = panel.url else { return }
        Task {
            do {
                _ = try await app.client?.copy(source: src.path,
                                               destination: "\(snapshot.id):\(joined(src.lastPathComponent))")
                app.flash("Copied \(src.lastPathComponent) into container")
                await load()
            } catch let e as CommandError { app.flash(e.userMessage) }
            catch { app.flash(error.localizedDescription) }
        }
    }
}
