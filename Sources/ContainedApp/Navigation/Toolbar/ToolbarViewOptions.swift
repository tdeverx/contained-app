import SwiftUI
import ContainedUI
import ContainedCore

/// Switches the container grid between all containers and session-local named groups. Group
/// creation stays attached to this toolbar item so the primary shell keeps a single navigation hub.
struct ToolbarContainerGroupSwitcher: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var showingNewGroup = false
    @State private var groupName = ""

    var body: some View {
        @Bindable var ui = ui
        return UI.Action.MenuButton {
            Button {
                ui.selectContainerGroup(nil)
            } label: {
                Label("All Containers",
                      systemImage: ui.selectedContainerGroupID == nil ? "checkmark.circle.fill" : "square.grid.2x2")
            }
            if !ui.containerGroups.isEmpty {
                Divider()
                ForEach(ui.containerGroups) { group in
                    Button {
                        ui.selectContainerGroup(group.id)
                    } label: {
                        Label(group.name,
                              systemImage: ui.selectedContainerGroupID == group.id ? "checkmark.circle.fill" : "folder")
                    }
                }
            }
            Divider()
            Button {
                groupName = ""
                showingNewGroup = true
            } label: {
                Label("New Group…", systemImage: "folder.badge.plus")
            }
            Divider()
            Picker(AppText.string("toolbar.sortBy", defaultValue: "Sort by"), selection: $ui.sort) {
                ForEach(ContainerSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Toggle(isOn: $ui.runningOnly) {
                Label(AppText.string("filter.runningOnly", defaultValue: "Running only"),
                      systemImage: "play.circle")
            }
        } labelContent: {
            UI.Toolbar.TitleSubtitle(symbol: ui.selectedContainerGroup == nil ? "square.grid.2x2" : "folder",
                                     title: ui.selectedContainerGroup?.name ?? "All Containers",
                                     subtitle: subtitle)
        }
        .help("Switch container group")
        .alert("New Group", isPresented: $showingNewGroup) {
            TextField("Group name", text: $groupName)
            Button("Create") { ui.createContainerGroup(named: groupName) }
                .disabled(!canCreateGroup)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this container group a name.")
        }
    }

    private var groupedSnapshots: [Core.Container.Snapshot] {
        ui.containers(in: app.containers.snapshots)
    }

    private var canCreateGroup: Bool {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !ui.containerGroups.contains {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private var subtitle: String {
        let total = groupedSnapshots.count
        let running = groupedSnapshots.filter { $0.state == .running }.count
        return "\(total) container\(total == 1 ? "" : "s") · \(running) running"
    }
}
