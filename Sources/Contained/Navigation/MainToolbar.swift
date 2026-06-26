import SwiftUI
import ContainedCore

/// One unified, **user-customizable** window toolbar shared by every section (right-click ▸ Customize
/// Toolbar… to rearrange, add, or remove items). It exposes every cross-cutting action as an
/// individual item plus a context-aware primary "Add" that adapts to the current section, and the
/// Containers view-options (Running filter, Card size). Replaces the old per-view `.toolbar` blocks
/// so the chrome is consistent — and the *default* layout below is just a starting point the user is
/// free to change.
private struct MainToolbar: ViewModifier {
    @Environment(AppModel.self) private var app
    @Bindable var ui: UIState
    @Bindable var settings: SettingsStore

    /// The section's primary add action, surfaced as the context-aware leading "＋".
    private struct AddSpec { let title: String; let icon: String; let run: () -> Void }

    private var primaryAdd: AddSpec? {
        switch ui.section {
        case .containers: return AddSpec(title: "New Container", icon: "plus") { ui.dispatch(.runContainer) }
        case .images:     return AddSpec(title: "Pull Image", icon: "arrow.down.circle") { ui.dispatch(.pullImage) }
        case .volumes:    return AddSpec(title: "New Volume", icon: "plus") { ui.dispatch(.createVolume) }
        case .networks:   return AddSpec(title: "New Network", icon: "plus") { ui.dispatch(.createNetwork) }
        case .registries: return AddSpec(title: "Registry Login", icon: "person.badge.key") { ui.dispatch(.registryLogin) }
        case .templates:  return AddSpec(title: "Import Compose", icon: "square.and.arrow.down") {
            ui.section = .templates; ui.pendingComposeImport = true
        }
        case .build, .system: return nil
        }
    }

    func body(content: Content) -> some View {
        content.toolbar(id: "main") {
            defaultItems
            paletteItems
        }
    }

    /// The starting layout: contextual add, Containers view-options, and Refresh.
    @ToolbarContentBuilder
    private var defaultItems: some CustomizableToolbarContent {
            // Context-aware primary add (its meaning follows the section).
            ToolbarItem(id: "primaryAdd", placement: .primaryAction) {
                if let add = primaryAdd {
                    Button { add.run() } label: { Label(add.title, systemImage: add.icon) }
                        .help(add.title)
                }
            }

            // Containers view options — kept visible by default; inert (disabled) elsewhere.
            ToolbarItem(id: "runningFilter", placement: .primaryAction) {
                Picker("Show", selection: $ui.runningOnly) {
                    Text("Running").tag(true)
                    Text("All").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden()
                .disabled(ui.section != .containers)
                .help("Filter running / all containers")
            }
            .defaultCustomization(.visible)

            ToolbarItem(id: "cardSize", placement: .primaryAction) {
                Picker("Card size", selection: $settings.density) {
                    Image(systemName: "rectangle.grid.1x2").tag(CardDensity.large)
                    Image(systemName: "square.grid.3x3").tag(CardDensity.compact)
                }
                .pickerStyle(.segmented).labelsHidden()
                .disabled(ui.section != .containers)
                .help("Card size")
            }
            .defaultCustomization(.visible)

            ToolbarItem(id: "refresh", placement: .primaryAction) {
                Button { app.coordinator.wake() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .help("Refresh now")
            }
            .defaultCustomization(.visible)
    }

    /// Every cross-cutting action as its own item — available from the Customize palette, hidden from
    /// the default layout so the bar stays uncluttered until the user opts in.
    @ToolbarContentBuilder
    private var paletteItems: some CustomizableToolbarContent {
            ToolbarItem(id: "newContainer", placement: .secondaryAction) {
                Button { ui.dispatch(.runContainer) } label: { Label("New Container", systemImage: "plus.square") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "pullImage", placement: .secondaryAction) {
                Button { ui.dispatch(.pullImage) } label: { Label("Pull Image", systemImage: "arrow.down.circle") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "loadImage", placement: .secondaryAction) {
                Button { ui.dispatch(.loadImage) } label: { Label("Load Image Tar", systemImage: "square.and.arrow.down") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "pruneImages", placement: .secondaryAction) {
                Button { ui.dispatch(.pruneImages) } label: { Label("Prune Images", systemImage: "trash") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "newVolume", placement: .secondaryAction) {
                Button { ui.dispatch(.createVolume) } label: { Label("New Volume", systemImage: "externaldrive.badge.plus") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "newNetwork", placement: .secondaryAction) {
                Button { ui.dispatch(.createNetwork) } label: { Label("New Network", systemImage: "network.badge.shield.half.filled") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "registryLogin", placement: .secondaryAction) {
                Button { ui.dispatch(.registryLogin) } label: { Label("Registry Login", systemImage: "person.badge.key") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "importCompose", placement: .secondaryAction) {
                Button { ui.section = .templates; ui.pendingComposeImport = true } label: {
                    Label("Import Compose", systemImage: "square.on.square")
                }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "activityHistory", placement: .secondaryAction) {
                Button { ui.dispatch(.activityHistory) } label: { Label("Activity History", systemImage: "clock.arrow.circlepath") }
            }
            .defaultCustomization(.hidden)
            ToolbarItem(id: "systemLogs", placement: .secondaryAction) {
                Button { ui.dispatch(.systemLogs) } label: { Label("System Logs", systemImage: "text.alignleft") }
            }
            .defaultCustomization(.hidden)
    }
}

extension View {
    /// Apply the shared, customizable window toolbar.
    func mainToolbar(ui: UIState, settings: SettingsStore) -> some View {
        modifier(MainToolbar(ui: ui, settings: settings))
    }
}
