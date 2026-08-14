import SwiftUI
import ContainedUI
import ContainedCore

/// Network inventory hosted by the System panel. This is the single network-browser surface.
struct SystemNetworksContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var elevated: Bool
    var onCreate: () -> Void
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
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
            HStack {
                Text(AppText.sectionNetworks).designHeadlineLabelStyle()
                UI.Badge.Text(text: "\(sortedNetworks.count)")
                Spacer()
                UI.Action.Cluster {
                    filterMenu
                    UI.Action.Items([UI.Action.Item(systemName: "plus",
                                                    title: AppText.string("common.new", defaultValue: "New"),
                                                    help: AppText.newNetwork,
                                                    action: onCreate)])
                }
            }
            if let message = app.resourceInventoryErrors["networks"] {
                UI.State.InlineStatus(message, isWorking: false)
            }
            if sortedNetworks.isEmpty {
                UI.Surface.Content(elevated: elevated, minHeight: 180, alignment: .center) {
                    UI.State.Empty(AppText.string("network.empty", defaultValue: "No networks"),
                                   systemImage: "network",
                                   description: AppText.string("network.empty.description", defaultValue: "Create or refresh container networks to see them here."),
                                   padding: UI.Layout.Spacing.xs)
                }
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
            }
        }
        .confirmationDialog(AppText.string("network.delete.confirmation", defaultValue: "Delete network \(deletingNetwork?.name ?? "")?"),
                            isPresented: deleteNetworkBinding,
                            presenting: deletingNetwork) { network in
            Button(AppText.delete, role: .destructive) { Task { await deleteNetwork(network) } }
        } message: { _ in
            Text(AppText.string("network.delete.message", defaultValue: "This removes the network. Containers must be detached first."))
        }
    }

    private var filterMenu: some View {
        @Bindable var ui = ui
        return Menu {
            Picker(AppText.string("toolbar.groupBy", defaultValue: "Group by"), selection: $ui.networkGrouping) {
                ForEach(NetworkGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker(AppText.string("toolbar.sortBy", defaultValue: "Sort by"), selection: $ui.networkSort) {
                ForEach(NetworkSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker(AppText.string("activity.filter", defaultValue: "Filter"), selection: $ui.networkFilter) {
                ForEach(NetworkFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol).tag(filter)
                }
            }
            .pickerStyle(.inline)
        } label: {
            UI.Action.MenuLabel(systemName: ui.networkFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill",
                                help: AppText.string("toolbar.networkFilters", defaultValue: "Network filters"))
        }
        .buttonStyle(.plain)
    }

    private func networkRow(_ network: Core.Network.Resource) -> some View {
        UI.Card.Scaffold(size: .medium,
                         elevated: elevated,
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
                    UI.Symbol.Image(systemName: "network.badge.shield.half.filled", size: .caption2)
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
        UI.Copy.ValueLabel("Copy Name", value: network.name)
        if let subnet = network.status?.ipv4Subnet {
            UI.Copy.ValueLabel("Copy IPv4 Subnet", value: subnet, systemName: "network")
        }
        if !network.isBuiltin {
            Divider()
            Button(role: .destructive) { deletingNetwork = network } label: {
                Label("Delete Network", systemImage: "trash")
            }
        }
    }

    private func networkSubtitle(_ network: Core.Network.Resource) -> String {
        [network.configuration.mode,
         network.configuration.plugin,
         network.status?.ipv4Subnet,
         network.status?.ipv4Gateway.map { "gateway \($0)" }]
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
            _ = try await client.deleteNetworks([network.name], runtimeKind: network.runtimeKind)
            await app.refreshNetworks()
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }
}
