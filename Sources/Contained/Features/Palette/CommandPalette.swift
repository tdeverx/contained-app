import SwiftUI
import ContainedCore

/// A global quick-action palette: search navigation, creation actions, page actions, and
/// per-container lifecycle without replacing the native sidebar or toolbar.
struct CommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    @State private var query = ""

    private var items: [PaletteItem] {
        PaletteItem.filtered(query, app: app, ui: ui)
    }

    var body: some View {
        @Bindable var ui = ui
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or run a command...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($fieldFocused)
                    .onSubmit { runSelected() }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Clear search")
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(Tokens.Space.l)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            row(item, selected: index == ui.paletteIndex)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture { run(item) }
                        }
                    }
                    .padding(Tokens.Space.s)
                }
                .frame(height: 360)
                .onChange(of: ui.paletteIndex) { _, new in proxy.scrollTo(new, anchor: .center) }
            }
        }
        .frame(width: 560)
        .sheetMaterial()
        .onAppear { fieldFocused = true; ui.paletteIndex = 0 }
        .onChange(of: query) { _, _ in ui.paletteIndex = 0 }
        .accessibilityElement(children: .contain)
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: item.icon)
                .foregroundStyle(item.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "return")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        ui.paletteIndex = min(max(0, ui.paletteIndex + delta), items.count - 1)
    }

    private func runSelected() {
        guard items.indices.contains(ui.paletteIndex) else { return }
        run(items[ui.paletteIndex])
    }

    private func run(_ item: PaletteItem) {
        dismiss()
        item.action()
    }
}

/// One command-palette entry: a titled, icon'd action.
struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let action: () -> Void

    /// Every available command: navigation, add actions, page/global actions, and per-container
    /// lifecycle. This is the app's single command surface now that the sidebar and toolbar are gone.
    @MainActor
    static func all(app: AppModel, ui: UIState) -> [PaletteItem] {
        var items: [PaletteItem] = []
        for section in AppSection.allCases {
            items.append(PaletteItem(title: "Go to \(section.title)", subtitle: "navigate",
                                     icon: section.systemImage, tint: .secondary) {
                ui.section = section
            })
        }
        // Add anything, from anywhere.
        let adds: [(String, String, PendingAction)] = [
            ("Run a container", "shippingbox", .runContainer),
            ("Pull an image", "arrow.down.circle", .pullImage),
            ("New volume", "externaldrive.badge.plus", .createVolume),
            ("New network", "network", .createNetwork),
            ("Registry login", "person.badge.key", .registryLogin),
        ]
        for (title, icon, action) in adds {
            items.append(PaletteItem(title: title, subtitle: "create", icon: icon, tint: .accentColor) {
                ui.dispatch(action)
            })
        }
        items.append(PaletteItem(title: "Import compose…", subtitle: "create", icon: "square.on.square", tint: .accentColor) {
            ui.section = .templates; ui.pendingComposeImport = true
        })
        // Page / global actions.
        items.append(PaletteItem(title: "Refresh", subtitle: "action", icon: "arrow.clockwise", tint: .secondary) {
            app.coordinator.wake()
        })
        let pageActions: [(String, String, PendingAction)] = [
            ("Load image tar…", "square.and.arrow.down", .loadImage),
            ("Prune images…", "trash", .pruneImages),
            ("Activity history", "clock.arrow.circlepath", .activityHistory),
            ("System logs", "text.alignleft", .systemLogs),
        ]
        for (title, icon, action) in pageActions {
            items.append(PaletteItem(title: title, subtitle: "action", icon: icon, tint: .secondary) {
                ui.dispatch(action)
            })
        }
        for snapshot in app.containers.snapshots {
            let name = app.personalization.resolved(id: snapshot.id, image: snapshot.image)
                .displayName(fallback: snapshot.id)
            if snapshot.state == .running {
                items.append(PaletteItem(title: "Stop \(name)", subtitle: "container", icon: "stop.fill", tint: .orange) {
                    Task { await app.containers.stop(snapshot.id) }
                })
                items.append(PaletteItem(title: "Restart \(name)", subtitle: "container", icon: "arrow.clockwise", tint: .blue) {
                    Task { await app.containers.restart(snapshot.id) }
                })
            } else {
                items.append(PaletteItem(title: "Start \(name)", subtitle: "container", icon: "play.fill", tint: .green) {
                    Task { await app.containers.start(snapshot.id) }
                })
            }
        }
        return items
    }

    /// Filter `all(...)` by a query — substring or per-word prefix (predictable for a small set).
    @MainActor
    static func filtered(_ query: String, app: AppModel, ui: UIState) -> [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let items = all(app: app, ui: ui)
        guard !q.isEmpty else { return items }
        return items.filter { item in
            let t = item.title.lowercased()
            return t.contains(q) || t.split(separator: " ").contains { $0.hasPrefix(q) }
        }
    }
}
