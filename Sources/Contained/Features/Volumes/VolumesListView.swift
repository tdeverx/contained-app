import SwiftUI
import ContainedCore

/// Volumes: list + inspect + create + delete.
struct VolumesListView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var inspecting: VolumeResource?
    @State private var deleting: VolumeResource?
    @State private var creating = false

    private var volumes: [VolumeResource] {
        let all = app.volumes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !ui.searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(ui.searchText) }
    }

    var body: some View {
        ResourceScaffold(isEmpty: volumes.isEmpty, emptyTitle: "No volumes",
                         emptySymbol: "externaldrive",
                         emptyMessage: "Create a volume to share persistent storage with containers.") {
            ForEach(volumes) { volume in row(volume) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Image(systemName: "plus") }.help("Create a volume")
            }
        }
        .task { await app.refreshResource(.volumes) }
        .sheet(item: $inspecting) { JSONInspectorSheet(title: $0.name, value: $0) }
        .sheet(isPresented: $creating) {
            CreateVolumeSheet { name, size in await create(name: name, size: size) }
        }
        .confirmationDialog("Delete volume \(deleting?.name ?? "")?", isPresented: deleteBinding, presenting: deleting) { volume in
            Button("Delete", role: .destructive) { Task { await delete(volume) } }
        } message: { _ in Text("This permanently removes the volume and its data.") }
    }

    private func row(_ volume: VolumeResource) -> some View {
        let config = volume.configuration
        let parts = [config.sizeInBytes.map { Format.bytes($0) }, config.format, config.source].compactMap { $0 }
        return ResourceRow(symbol: "externaldrive", tint: .accentColor, title: volume.name,
                           subtitle: parts.joined(separator: "  ·  ")) {
            GlassRowMenu {
                Button { inspecting = volume } label: { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
                Button { copyToPasteboard(volume.name) } label: { Label("Copy name", systemImage: "doc.on.doc") }
                Divider()
                Button(role: .destructive) { deleting = volume } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func create(name: String, size: String?) async {
        guard let client = app.client else { return }
        do { _ = try await client.createVolume(name: name, size: size); await app.refreshResource(.volumes) }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    private func delete(_ volume: VolumeResource) async {
        guard let client = app.client else { return }
        do { _ = try await client.deleteVolumes([volume.name]); await app.refreshResource(.volumes) }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }
}

/// Minimal create-volume sheet: name + optional size.
struct CreateVolumeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, String?) async -> Void
    @State private var name = ""
    @State private var size = ""
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New volume", onCancel: { dismiss() }) {
                GlassCircleButton(systemName: "checkmark", prominent: true, help: "Create") { submit() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
            Form {
                TextField("Name", text: $name, prompt: Text("my-volume"))
                TextField("Size", text: $size, prompt: Text("optional, e.g. 10G"))
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(Tokens.SheetSize.small)
        .background(.regularMaterial)
    }

    private func submit() {
        busy = true
        Task {
            await onCreate(name.trimmingCharacters(in: .whitespaces),
                           size.trimmingCharacters(in: .whitespaces).isEmpty ? nil : size)
            dismiss()
        }
    }
}
