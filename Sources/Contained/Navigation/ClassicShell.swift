import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
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
    @Environment(UIState.self) private var ui
    @Binding var selection: AppSection

    var body: some View {
        List(selection: $selection) {
            ForEach(AppSectionGroup.allCases) { group in
                let sections = AppSection.navigableSections(panelNavigationEnabled: ui.panelNavigationEnabled)
                    .filter { $0.group == group && isVisible($0) }
                if !sections.isEmpty {
                    Section(group.rawValue) {
                        ForEach(sections) { section in
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
        }
        .listStyle(.sidebar)
        .tint(app.settings.accentTint.color)
        .navigationTitle("Contained")
    }

    private func isVisible(_ section: AppSection) -> Bool {
        section != .build || app.settings.imageBuildEnabled
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
            ImagesPage()
        case .build:
            BuildPage()
        case .volumes:
            SystemContent(initialPage: .volumes, showClose: false, elevated: false, usesToolbarSelection: false)
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

private struct BuildPage: View {
    var body: some View {
        PageScaffold(symbol: "hammer",
                     title: "Build",
                     subtitle: "From a Dockerfile + build context") {
            EmptyView()
        } content: {
            BuildWorkspaceView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct NetworksPage: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var deletingNetwork: NetworkResource?

    private var sortedNetworks: [NetworkResource] {
        app.networks.filter(matchesFilter).sorted { lhs, rhs in
            switch ui.networkSort {
            case .name:
                break
            case .mode:
                let lhsMode = lhs.configuration.mode ?? ""
                let rhsMode = rhs.configuration.mode ?? ""
                if lhsMode.localizedCaseInsensitiveCompare(rhsMode) != .orderedSame {
                    return lhsMode.localizedCaseInsensitiveCompare(rhsMode) == .orderedAscending
                }
            case .plugin:
                let lhsPlugin = lhs.configuration.plugin ?? ""
                let rhsPlugin = rhs.configuration.plugin ?? ""
                if lhsPlugin.localizedCaseInsensitiveCompare(rhsPlugin) != .orderedSame {
                    return lhsPlugin.localizedCaseInsensitiveCompare(rhsPlugin) == .orderedAscending
                }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var networkSections: [(title: String, networks: [NetworkResource])] {
        switch ui.networkGrouping {
        case .none:
            return [("", sortedNetworks)]
        case .kind:
            return Dictionary(grouping: sortedNetworks) { $0.isBuiltin ? "Built-in" : "Custom" }
                .map { ($0.key, $0.value) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .mode:
            return Dictionary(grouping: sortedNetworks) { $0.configuration.mode ?? "No mode" }
                .map { ($0.key, $0.value) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        PageScaffold(symbol: "network",
                     title: "Networks",
                     subtitle: "\(sortedNetworks.count) network\(sortedNetworks.count == 1 ? "" : "s")") {
            DesignActionGroup(DesignAction(systemName: "plus",
                                           title: "New",
                                           help: "New network") {
                ui.dispatch(.createNetwork)
            })
        } content: {
            if sortedNetworks.isEmpty {
                ContentUnavailableView("No networks",
                                       systemImage: "network",
                                       description: Text("Create or refresh container networks to see them here."))
                    .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                LazyVStack(spacing: Tokens.Space.s) {
                    ForEach(Array(networkSections.enumerated()), id: \.offset) { _, section in
                        if ui.networkGrouping != .none {
                            ResourceBadgeText(text: section.title, font: .caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Tokens.Space.xs)
                        }
                        ForEach(section.networks) { network in
                            networkRow(network)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task { await app.refreshNetworks() }
        .confirmationDialog("Delete network \(deletingNetwork?.name ?? "")?",
                            isPresented: deleteNetworkBinding,
                            presenting: deletingNetwork) { network in
            Button("Delete", role: .destructive) { Task { await deleteNetwork(network) } }
        } message: { _ in
            Text("This removes the network. Containers must be detached first.")
        }
    }

    private func networkRow(_ network: NetworkResource) -> some View {
        ResourceCard(size: .medium,
                     elevated: false,
                     title: network.name,
                     subtitle: networkSubtitle(network)) {
            ResourceCardIconChip(symbol: network.isBuiltin ? "network.badge.shield.half.filled" : "network",
                                 tint: network.isBuiltin ? .secondary : .accentColor)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            GlassRowMenu { networkMenu(network) }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            if network.isBuiltin {
                ResourceCardFooterMini {
                    Image(systemName: "network.badge.shield.half.filled").font(.caption2)
                } text: {
                    ResourceCardMetricText(text: "Built-in")
                }
            }
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
        .contextMenu { networkMenu(network) }
    }

    @ViewBuilder
    private func networkMenu(_ network: NetworkResource) -> some View {
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

    private func matchesFilter(_ network: NetworkResource) -> Bool {
        switch ui.networkFilter {
        case .all: return true
        case .custom: return !network.isBuiltin
        case .builtin: return network.isBuiltin
        }
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

private struct ImagesPage: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var detail: LocalImageTagGroup?
    @State private var sourceFrame: CGRect?
    @State private var presented = false
    @State private var closeRequestToken = 0

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                ToolbarUpdatesPanel(showClose: false,
                                    coordinateSpaceName: pageImageSpace,
                                    hiddenImageGroupID: presented ? detail?.id : nil,
                                    onOpenImage: openImageDetail,
                                    onClose: {})

                if let detail, presented {
                    MorphingSingleSurfaceExpander(isPresented: detailBinding,
                                                  originFrame: usableSourceFrame ?? fallbackSourceFrame(in: viewport.size),
                                                  target: .anchored(size: Tokens.PanelSize.imageDetail,
                                                                    safeArea: imageDetailSafeAreaPolicy,
                                                                    margin: 16),
                                                  backdropStyle: .dim,
                                                  showsBackdrop: true,
                                                  closeRequestToken: closeRequestToken,
                                                  onBackdropTap: closeDetail) {
                        ToolbarImageGroupCard(group: currentGroup(detail),
                                              isExpanded: true,
                                              onTap: {},
                                              onClose: closeDetail)
                    }
                    .environment(\.appSafeAreas, imageDetailSafeAreas)
                    .zIndex(10)
                }
            }
            .coordinateSpace(.named(pageImageSpace))
        }
    }

    private let pageImageSpace = "imagesPage"

    private var imageDetailSafeAreaPolicy: AppSafeAreaPolicy {
        ui.toolbarUIEnabled ? AppSafeAreaPolicy(excluding: .both, padding: .small) : .content
    }

    private var imageDetailSafeAreas: AppSafeAreaManager {
        guard ui.toolbarUIEnabled else { return AppSafeAreaManager(system: EdgeInsets()) }
        return AppSafeAreaManager(system: EdgeInsets(),
                                  topToolbarHeight: AppToolbar.bandHeight,
                                  bottomToolbarHeight: AppToolbar.bandHeight)
    }

    private var detailBinding: Binding<Bool> {
        Binding(get: { presented }, set: { isPresented in
            if isPresented {
                presented = true
            } else {
                presented = false
                detail = nil
                sourceFrame = nil
            }
        })
    }

    private var usableSourceFrame: CGRect? {
        guard let sourceFrame,
              sourceFrame.width.isFinite, sourceFrame.height.isFinite,
              sourceFrame.minX.isFinite, sourceFrame.minY.isFinite,
              sourceFrame.width > 1, sourceFrame.height > 1
        else { return nil }
        return sourceFrame
    }

    private func fallbackSourceFrame(in size: CGSize) -> CGRect {
        CGRect(x: size.width / 2 - 1, y: size.height / 2 - 1, width: 2, height: 2)
    }

    private func openImageDetail(_ group: LocalImageTagGroup, _ frame: CGRect) {
        detail = group
        sourceFrame = frame
        presented = true
    }

    private func closeDetail() {
        closeRequestToken &+= 1
    }

    private func currentGroup(_ group: LocalImageTagGroup) -> LocalImageTagGroup {
        app.localImageGroups().first { $0.id == group.id } ?? group
    }
}
