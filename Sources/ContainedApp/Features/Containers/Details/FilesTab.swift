import SwiftUI
import ContainedUI
import AppKit
import ContainedCore

/// Browse a running container's filesystem (`exec ls -1ap`) and copy files in/out with the native
/// `container cp`. AppKit bridge (flagged): `NSOpenPanel`/`NSSavePanel` for host file selection.
struct FilesTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: Core.Container.Snapshot

    @State private var path = "/"
    @State private var entries: [String] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        if snapshot.state != .running {
            UI.State.Empty(AppText.string("files.notRunning", defaultValue: "Not running"),
                             systemImage: "folder",
                             description: AppText.string("files.notRunning.description", defaultValue: "Start the container to browse its files."))
        } else {
            ContainerToolTabScaffold {
                pathBar
            } content: {
                listing
            }
            .task(id: path) { await load() }
        }
    }

    private var pathBar: some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            UI.Action.Group(UI.Action.Item(systemName: "chevron.up",
                                           help: AppText.parent,
                                           isEnabled: path != "/") { goUp() })
            Text(path).designMonospacedCallout().lineLimit(1).truncationMode(.middle)
            Spacer()
            if loading { UI.State.InlineStatus(AppText.string("files.loading", defaultValue: "loading"), isWorking: true) }
            UI.Action.Group(UI.Action.Item(systemName: "square.and.arrow.down",
                                           help: AppText.string("files.copyIntoFolder", defaultValue: "Copy a file into this folder")) {
                    copyIn()
            })
            UI.Action.Group(UI.Action.Item(systemName: "arrow.clockwise", help: AppText.refresh) { Task { await load() } })
        }
    }

    @ViewBuilder
    private var listing: some View {
        if let error {
            UI.State.Empty(AppText.string("files.error.title", defaultValue: "Couldn't read folder"),
                             systemImage: "exclamationmark.triangle",
                             description: error,
                             tone: .error)
        } else {
            ScrollView {
                LazyVStack(spacing: UI.Layout.Spacing.hairline) {
                    ForEach(entries, id: \.self) { entry in row(entry) }
                }
                .padding(UI.Layout.Spacing.s)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }

    private func row(_ entry: String) -> some View {
        let isDir = entry.hasSuffix("/")
        let name = isDir ? String(entry.dropLast()) : entry
        return UI.List.MetadataRow(systemImage: isDir ? "folder.fill" : "doc",
                                 title: name,
                                 isMonospaced: true,
                                 tint: isDir ? .accentColor : .secondary,
                                 action: isDir ? { path = joined(name) + "/" } : nil) {
            if isDir {
                UI.List.RowChevron()
            } else {
                Button { copyOut(name) } label: {
                    UI.Symbol.Image(systemName: "square.and.arrow.up")
                }
                    .buttonStyle(.plain)
                    .help(AppText.string("files.copyToHost", defaultValue: "Copy to host"))
            }
        }
    }

    // MARK: Actions

    private func load() async {
        guard let client = app.client else { return }
        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            let out = try await client.execCapture(snapshot.id, ["ls", "-1ap", path])
            entries = out.split(separator: "\n").map(String.init)
                .filter { $0 != "./" && $0 != "../" && !$0.isEmpty }
                .sorted { ($0.hasSuffix("/") ? 0 : 1, $0.lowercased()) < ($1.hasSuffix("/") ? 0 : 1, $1.lowercased()) }
        } catch let e as Core.Command.Error { error = e.appDisplayMessage }
        catch { self.error = error.appDisplayMessage }
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
        panel.message = AppText.copyFileFromContainerPanel(name)
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        Task {
            do {
                _ = try await app.client?.copy(source: "\(snapshot.id):\(joined(name))", destination: dest.path)
                app.flash(AppText.copiedFileToHost(name))
            } catch let e as Core.Command.Error { app.flash(e.appDisplayMessage) }
            catch { app.flash(error.appDisplayMessage) }
        }
    }

    private func copyIn() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = AppText.copyFileIntoContainerPanel(path)
        guard panel.runModal() == .OK, let src = panel.url else { return }
        Task {
            do {
                _ = try await app.client?.copy(source: src.path,
                                               destination: "\(snapshot.id):\(joined(src.lastPathComponent))")
                app.flash(AppText.copiedFileIntoContainer(src.lastPathComponent))
                await load()
            } catch let e as Core.Command.Error { app.flash(e.appDisplayMessage) }
            catch { app.flash(error.appDisplayMessage) }
        }
    }
}
