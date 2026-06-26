import SwiftUI
import ContainedCore

/// A ⌘K quick-action palette: fuzzy-search across navigation, global actions, and per-container
/// lifecycle. Type to filter, ↑/↓ to move, ↵ to run, esc to dismiss.
struct CommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    @State private var query = ""
    @State private var index = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Run a command…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($fieldFocused)
                    .onSubmit { runSelected() }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
            }
            .padding(Tokens.Space.l)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            row(item, selected: i == index).id(i)
                                .onTapGesture { run(item) }
                        }
                    }
                    .padding(Tokens.Space.s)
                }
                .onChange(of: index) { _, new in proxy.scrollTo(new, anchor: .center) }
            }
            .frame(height: 360)
        }
        .frame(width: 560)
        .sheetMaterial()
        .onAppear { fieldFocused = true }
        .onChange(of: query) { _, _ in index = 0 }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: item.icon).foregroundStyle(item.tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.m).padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
        .contentShape(Rectangle())
    }

    // MARK: Items

    private var allItems: [PaletteItem] {
        var items: [PaletteItem] = []
        // Navigation
        for section in AppSection.allCases {
            items.append(PaletteItem(title: "Go to \(section.title)", subtitle: nil,
                                     icon: section.systemImage, tint: .secondary) {
                ui.section = section
            })
        }
        // Global actions
        items.append(PaletteItem(title: "Run a container", subtitle: nil, icon: "plus", tint: .accentColor) {
            ui.showRunSheet = true
        })
        // Per-container lifecycle
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

    private var items: [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allItems }
        // Substring or per-word prefix — predictable for a small curated command set.
        return allItems.filter { item in
            let t = item.title.lowercased()
            return t.contains(q) || t.split(separator: " ").contains { $0.hasPrefix(q) }
        }
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        index = min(max(0, index + delta), items.count - 1)
    }

    private func runSelected() {
        guard items.indices.contains(index) else { return }
        run(items[index])
    }

    private func run(_ item: PaletteItem) {
        dismiss()
        item.action()
    }
}

struct PaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let action: () -> Void
}
