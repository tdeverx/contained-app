import SwiftUI
import ContainedUX
import ContainedUI
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
                    .environment(\.morphSafeAreaManager, toolbarSafeAreaManager)
                    .ignoresSafeArea(.container, edges: .vertical)
            }
        }
        .environment(\.morphSafeAreaManager, UX.SafeArea.Manager(system: EdgeInsets()))
    }

    private var detailPage: some View {
        let insets = toolbarSafeAreaManager.insets(UX.SafeArea.Policy(excluding: .top, padding: .none))
        return ClassicSectionPage(section: ui.selectedSection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Body-only padding from the same custom safe-area measurer used by morph panels.
            .padding(.top, ui.toolbarUIEnabled ? insets.top : 0)
            .ignoresSafeArea(.container, edges: .vertical)
    }

    private var toolbarSafeAreaManager: UX.SafeArea.Manager {
        UX.SafeArea.Manager(system: EdgeInsets(),
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
                    Section(group.title) {
                        ForEach(sections) { section in
                        Label {
                            HStack {
                                Text(section.title)
                                Spacer()
                                if let badge = badge(for: section) {
                                    Text(badge)
                                        .designSecondaryMonospacedDigitCaption()
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
        UI.Panel.PageScaffold(symbol: "hammer",
                     title: AppText.sectionBuild,
                     subtitle: AppText.string("build.subtitle.context", defaultValue: "From a Dockerfile + build context")) {
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
    @State private var deletingNetwork: Core.Network.Resource?

    private var sortedNetworks: [Core.Network.Resource] {
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

    private var networkSections: [(title: String, networks: [Core.Network.Resource])] {
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
        UI.Panel.PageScaffold(symbol: "network",
                     title: AppText.sectionNetworks,
                     subtitle: AppText.string("network.count", defaultValue: "\(sortedNetworks.count) network\(sortedNetworks.count == 1 ? "" : "s")")) {
            UI.Action.Group(UI.Action.Item(systemName: "plus",
                                           title: AppText.string("common.new", defaultValue: "New"),
                                           help: AppText.string("network.newNetwork.lowercase", defaultValue: "New network")) {
                ui.dispatch(.createNetwork)
            })
        } content: {
            if sortedNetworks.isEmpty {
                UI.State.Empty(AppText.string("network.empty", defaultValue: "No networks"),
                                 systemImage: "network",
                                 description: AppText.string("network.empty.description", defaultValue: "Create or refresh container networks to see them here."),
                                 minHeight: 280)
            } else {
                LazyVStack(spacing: UI.Layout.Spacing.s) {
                    ForEach(Array(networkSections.enumerated()), id: \.offset) { _, section in
                        if ui.networkGrouping != .none {
                            UI.Badge.Text(text: section.title, font: .caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, UI.Layout.Spacing.xs)
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
        .confirmationDialog(AppText.string("network.delete.confirmation", defaultValue: "Delete network \(deletingNetwork?.name ?? "")?"),
                            isPresented: deleteNetworkBinding,
                            presenting: deletingNetwork) { network in
            Button(AppText.delete, role: .destructive) { Task { await deleteNetwork(network) } }
        } message: { _ in
            Text(AppText.string("network.delete.message", defaultValue: "This removes the network. Containers must be detached first."))
        }
    }

    private func networkRow(_ network: Core.Network.Resource) -> some View {
        UI.Card.Scaffold(size: .medium,
                     elevated: false,
                     title: network.name,
                     subtitle: networkSubtitle(network)) {
            UI.Card.IconChip(symbol: network.isBuiltin ? "network.badge.shield.half.filled" : "network",
                                 tint: network.isBuiltin ? .secondary : .accentColor)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            UI.Control.RowMenu(accessibilityLabel: AppText.string("menu.networkActions", defaultValue: "Network actions")) {
                networkMenu(network)
            }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            if network.isBuiltin {
                UI.Card.FooterMini {
                    UI.Symbol.Image(systemName: "network.badge.shield.half.filled",
                                 size: .caption2)
                } text: {
                    UI.Card.MetricText(text: "Built-in")
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
    private func networkMenu(_ network: Core.Network.Resource) -> some View {
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

    private func networkSubtitle(_ network: Core.Network.Resource) -> String {
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

    private func matchesFilter(_ network: Core.Network.Resource) -> Bool {
        switch ui.networkFilter {
        case .all: return true
        case .custom: return !network.isBuiltin
        case .builtin: return network.isBuiltin
        }
    }

    private var deleteNetworkBinding: Binding<Bool> {
        Binding(get: { deletingNetwork != nil }, set: { if !$0 { deletingNetwork = nil } })
    }

    private func deleteNetwork(_ network: Core.Network.Resource) async {
        guard let client = app.client else { return }
        do {
            _ = try await client.deleteNetworks([network.name])
            await app.refreshNetworks()
        } catch let error as Core.Command.Error {
            app.flash(error.appDisplayMessage)
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }
}

private struct ImagesPage: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var detail: Core.Image.LocalTagGroup?
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
                    UX.Morph.SingleSurfaceExpander(isPresented: detailBinding,
                                                  originFrame: usableSourceFrame ?? fallbackSourceFrame(in: viewport.size),
                                                  target: .anchored(size: UI.Panel.Size.imageDetail,
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
                    .environment(\.morphSafeAreaManager, imageDetailSafeAreaManager)
                    .zIndex(10)
                }
            }
            .coordinateSpace(.named(pageImageSpace))
        }
    }

    private let pageImageSpace = "imagesPage"

    private var imageDetailSafeAreaPolicy: UX.SafeArea.Policy {
        ui.toolbarUIEnabled ? UX.SafeArea.Policy(excluding: .both, padding: .small) : .content
    }

    private var imageDetailSafeAreaManager: UX.SafeArea.Manager {
        guard ui.toolbarUIEnabled else { return UX.SafeArea.Manager(system: EdgeInsets()) }
        return UX.SafeArea.Manager(system: EdgeInsets(),
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

    private func openImageDetail(_ group: Core.Image.LocalTagGroup, _ frame: CGRect) {
        detail = group
        sourceFrame = frame
        presented = true
    }

    private func closeDetail() {
        closeRequestToken &+= 1
    }

    private func currentGroup(_ group: Core.Image.LocalTagGroup) -> Core.Image.LocalTagGroup {
        app.localImageGroups().first { $0.id == group.id } ?? group
    }
}
