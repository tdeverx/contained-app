import SwiftUI
import SwiftData
import ContainedCore

struct ClassicShell: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    let sidebarNavigationEnabled: Bool

    init(sidebarNavigationEnabled: Bool = true) {
        self.sidebarNavigationEnabled = sidebarNavigationEnabled
    }

    var body: some View {
        @Bindable var ui = ui
        NavigationSplitView(columnVisibility: sidebarColumnVisibility) {
            AppSidebar(selection: $ui.selectedSection)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if !sidebarNavigationEnabled { ui.sidebarVisible = false }
        }
        .onChange(of: sidebarNavigationEnabled) { _, enabled in
            withAnimation(.easeInOut(duration: 0.24)) {
                ui.sidebarVisible = enabled
            }
        }
    }

    private var detailColumn: some View {
        ZStack {
            detailPage
        }
        .overlay {
            if ui.toolbarUIEnabled {
                // The custom toolbar belongs to the detail column, not the whole split view. Mounting
                // it here keeps the sidebar outside the toolbar safe-area bands.
                AppToolbar()
                    .environment(\.appSafeAreas, toolbarSafeAreas)
                    .ignoresSafeArea(.container, edges: .vertical)
            }
        }
        .environment(\.appSafeAreas, AppSafeAreaManager(system: EdgeInsets()))
    }

    private var detailPage: some View {
        let insets = toolbarSafeAreas.insets(AppSafeAreaPolicy(excluding: .top, padding: .none))
        return ClassicSectionPage(section: ui.selectedSection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Body-only padding from the same custom safe-area measurer used by morph panels.
            .padding(.top, ui.toolbarUIEnabled ? insets.top : 0)
            .ignoresSafeArea(.container, edges: .vertical)
    }

    private var toolbarSafeAreas: AppSafeAreaManager {
        AppSafeAreaManager(system: EdgeInsets(),
                           topToolbarHeight: AppToolbar.bandHeight,
                           bottomToolbarHeight: AppToolbar.bandHeight)
    }

    private var sidebarColumnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            sidebarNavigationEnabled && ui.sidebarVisible ? .automatic : .detailOnly
        } set: { visibility in
            if visibility == .detailOnly {
                ui.sidebarVisible = false
            }
        }
    }
}

private struct AppSidebar: View {
    @Environment(AppModel.self) private var app
    @Binding var selection: AppSection

    var body: some View {
        List(selection: $selection) {
            ForEach(AppSectionGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(AppSection.allCases.filter { $0.group == group }) { section in
                        Label {
                            HStack {
                                Text(section.title)
                                Spacer()
                                if let badge = badge(for: section) {
                                    Text(badge)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: section.symbol)
                        }
                        .tag(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .tint(app.settings.accentTint.color)
        .navigationTitle("Contained")
    }

    private func badge(for section: AppSection) -> String? {
        switch section {
        case .containers:
            return "\(app.containers.snapshots.count)"
        case .images:
            return "\(app.images.count)"
        case .volumes:
            return "\(app.volumes.count)"
        case .networks:
            return "\(app.networks.count)"
        case .activity:
            return app.activity == nil ? nil : "1"
        default:
            return nil
        }
    }
}

private struct ClassicSectionPage: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    let section: AppSection

    var body: some View {
        switch section {
        case .containers:
            ContainersGridView()
        case .images:
            ToolbarUpdatesPanel(showClose: false, onOpenImage: { _, _ in }, onClose: {})
                .task { await app.refreshImagesIfStale(force: true) }
        case .volumes:
            SystemContent(initialPage: .volumes, showClose: false, elevated: false)
        case .networks:
            NetworksPage()
        case .system:
            SystemContent(showClose: false, elevated: false)
        case .registries:
            SettingsContent(initialPage: .registries)
        case .templates:
            ToolbarTemplatesPanel(showClose: false, onClose: {})
        case .activity:
            ActivityContent(showClose: false, elevated: false)
        case .settings:
            SettingsContent()
        }
    }
}

private struct NetworksPage: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var inspectingNetwork: NetworkResource?
    @State private var deletingNetwork: NetworkResource?

    private var sortedNetworks: [NetworkResource] {
        app.networks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        PageScaffold(symbol: "network",
                     title: "Networks",
                     subtitle: "\(sortedNetworks.count) network\(sortedNetworks.count == 1 ? "" : "s")") {
            GlassButton(singleItem: true) {
                GlassButtonItem(help: "New network", action: { ui.dispatch(.createNetwork) }) {
                    Label("New", systemImage: "plus")
                }
            }
        } content: {
            if sortedNetworks.isEmpty {
                ContentUnavailableView("No networks",
                                       systemImage: "network",
                                       description: Text("Create or refresh container networks to see them here."))
                    .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                LazyVStack(spacing: Tokens.Space.s) {
                    ForEach(sortedNetworks) { network in
                        networkRow(network)
                    }
                }
            }
        }
        .task { await app.refreshNetworks() }
        .sheet(item: $inspectingNetwork) { JSONInspectorSheet(title: $0.name, value: $0) }
        .confirmationDialog("Delete network \(deletingNetwork?.name ?? "")?",
                            isPresented: deleteNetworkBinding,
                            presenting: deletingNetwork) { network in
            Button("Delete", role: .destructive) { Task { await deleteNetwork(network) } }
        } message: { _ in
            Text("This removes the network. Containers must be detached first.")
        }
    }

    private func networkRow(_ network: NetworkResource) -> some View {
        ResourceGlassCard(size: .medium, elevated: false) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: network.isBuiltin ? "network.badge.shield.half.filled" : "network",
                                     tint: network.isBuiltin ? .secondary : .accentColor)
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: network.name)
                    ResourceCardSubtitleText(text: networkSubtitle(network))
                }
            } trailing: {
                GlassRowMenu { networkMenu(network) }
            }
        } footerLeading: {
            if network.isBuiltin {
                ResourceBadgeText(text: "builtin", font: .caption2.weight(.medium))
            }
        } footerActions: {
            EmptyView()
        }
        .contextMenu { networkMenu(network) }
    }

    @ViewBuilder
    private func networkMenu(_ network: NetworkResource) -> some View {
        Button { inspectingNetwork = network } label: {
            Label("Inspect", systemImage: "doc.text.magnifyingglass")
        }
        Button { copyToPasteboard(network.name) } label: {
            Label("Copy Name", systemImage: "doc.on.doc")
        }
        if let subnet = network.status?.ipv4Subnet {
            Button { copyToPasteboard(subnet) } label: {
                Label("Copy IPv4 Subnet", systemImage: "network")
            }
        }
        if !network.isBuiltin {
            Divider()
            Button(role: .destructive) { deletingNetwork = network } label: {
                Label("Delete Network", systemImage: "trash")
            }
        }
    }

    private func networkSubtitle(_ network: NetworkResource) -> String {
        [
            network.configuration.mode,
            network.configuration.plugin,
            network.status?.ipv4Subnet,
            network.status?.ipv4Gateway.map { "gateway \($0)" }
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    private var deleteNetworkBinding: Binding<Bool> {
        Binding(get: { deletingNetwork != nil }, set: { if !$0 { deletingNetwork = nil } })
    }

    private func deleteNetwork(_ network: NetworkResource) async {
        guard let client = app.client else { return }
        do {
            _ = try await client.deleteNetworks([network.name])
            await app.refreshNetworks()
        } catch let error as CommandError {
            app.flash(error.userMessage)
        } catch {
            app.flash(error.localizedDescription)
        }
    }
}
