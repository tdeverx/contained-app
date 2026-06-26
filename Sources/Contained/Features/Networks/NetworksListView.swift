import SwiftUI
import ContainedCore

/// Networks: list + inspect + create + delete. Builtin networks can't be deleted.
struct NetworksListView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var inspecting: NetworkResource?
    @State private var deleting: NetworkResource?
    @State private var creating = false

    private var networks: [NetworkResource] {
        let all = app.networks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !ui.searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(ui.searchText) }
    }

    var body: some View {
        ResourceScaffold(isEmpty: networks.isEmpty, emptyTitle: "No networks",
                         emptySymbol: "network",
                         emptyMessage: "Create a network to connect containers.") {
            ForEach(networks) { network in row(network) }
        }
        .task { await app.refreshResource(.networks) }
        .onAppear { if ui.pendingAction == .createNetwork { ui.pendingAction = nil; creating = true } }
        .onChange(of: ui.pendingAction) { _, _ in if ui.pendingAction == .createNetwork { ui.pendingAction = nil; creating = true } }
        .sheet(item: $inspecting) { JSONInspectorSheet(title: $0.name, value: $0) }
        .sheet(isPresented: $creating) {
            CreateNetworkSheet { name, subnet, internalOnly in
                await create(name: name, subnet: subnet, internalOnly: internalOnly)
            }
        }
        .confirmationDialog("Delete network \(deleting?.name ?? "")?", isPresented: deleteBinding, presenting: deleting) { network in
            Button("Delete", role: .destructive) { Task { await delete(network) } }
        } message: { _ in Text("This removes the network. Containers must be detached first.") }
    }

    private func row(_ network: NetworkResource) -> some View {
        let subtitleParts = [network.configuration.mode, network.status?.ipv4Subnet,
                             network.status?.ipv4Gateway.map { "gw \($0)" }].compactMap { $0 }
        return ResourceRow(symbol: "network", tint: .accentColor, title: network.name,
                           subtitle: subtitleParts.joined(separator: "  ·  ")) {
            HStack(spacing: Tokens.Space.s) {
                if network.isBuiltin {
                    Text("builtin").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                GlassRowMenu { menuItems(network) }
            }
        }
        .contextMenu { menuItems(network) }
    }

    @ViewBuilder
    private func menuItems(_ network: NetworkResource) -> some View {
        Button { inspecting = network } label: { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
        Button { copyToPasteboard(network.name) } label: { Label("Copy name", systemImage: "doc.on.doc") }
        if !network.isBuiltin {
            Divider()
            Button(role: .destructive) { deleting = network } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func create(name: String, subnet: String?, internalOnly: Bool) async {
        guard let client = app.client else { return }
        do {
            _ = try await client.createNetwork(name: name, subnet: subnet, internalOnly: internalOnly)
            await app.refreshResource(.networks)
        } catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    private func delete(_ network: NetworkResource) async {
        guard let client = app.client else { return }
        do { _ = try await client.deleteNetworks([network.name]); await app.refreshResource(.networks) }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }
}

/// Minimal create-network sheet: name + optional subnet + host-only toggle.
struct CreateNetworkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, String?, Bool) async -> Void
    @State private var name = ""
    @State private var subnet = ""
    @State private var internalOnly = false
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New network", onCancel: { dismiss() }) {
                GlassCircleButton(systemName: "checkmark", prominent: true, help: "Create") { submit() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
            Form {
                TextField("Name", text: $name, prompt: Text("my-network"))
                TextField("Subnet", text: $subnet, prompt: Text("optional, e.g. 10.0.0.0/24"))
                Toggle("Host-only (internal)", isOn: $internalOnly)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(Tokens.SheetSize.small)
        .sheetMaterial()
    }

    private func submit() {
        busy = true
        Task {
            await onCreate(name.trimmingCharacters(in: .whitespaces),
                           subnet.trimmingCharacters(in: .whitespaces).isEmpty ? nil : subnet, internalOnly)
            dismiss()
        }
    }
}
