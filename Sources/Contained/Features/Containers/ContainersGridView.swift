import SwiftUI
import ContainedCore

/// The Containers screen: a responsive grid of personalized glass cards. Filters/density/run live
/// in the window toolbar; tapping a card opens the detail sheet; the dashed card opens Create/Run.
struct ContainersGridView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    @State private var detail: ContainerSnapshot?
    @State private var customizing: ContainerSnapshot?
    @State private var editing: ContainerSnapshot?
    @State private var deleting: ContainerSnapshot?
    @State private var selecting = false
    @State private var selection: Set<String> = []

    private var store: ContainersStore { app.containers }

    private var columns: [GridItem] {
        let density = app.settings.density
        let minWidth = density == .compact ? Tokens.CardSize.compactMin : Tokens.CardSize.largeMin
        let maxWidth = density == .compact ? Tokens.CardSize.compactMax : Tokens.CardSize.largeMax
        return [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: Tokens.Space.m)]
    }

    private var filtered: [ContainerSnapshot] {
        store.snapshots.filter { snapshot in
            (!ui.runningOnly || snapshot.state == .running) &&
            (ui.searchText.isEmpty
                || snapshot.displayName.localizedCaseInsensitiveContains(ui.searchText)
                || snapshot.image.localizedCaseInsensitiveContains(ui.searchText))
        }
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: Tokens.Space.m) {
                LazyVGrid(columns: columns, spacing: Tokens.Space.m) {
                    ForEach(filtered) { snapshot in
                        let style = app.personalization.resolved(id: snapshot.id, image: snapshot.image)
                        ContainerCard(
                            snapshot: snapshot,
                            style: style,
                            density: app.settings.density,
                            stats: store.statsByID[snapshot.id],
                            history: store.historyByID[snapshot.id]?[style.graphMetric]?.values ?? [],
                            isBusy: store.busyIDs.contains(snapshot.id),
                            onTap: { selecting ? toggle(snapshot.id) : (detail = snapshot) },
                            onStart: { Task { await store.start(snapshot.id) } },
                            onStop: { Task { await store.stop(snapshot.id) } },
                            onRestart: { Task { await store.restart(snapshot.id) } },
                            onCustomize: { customizing = snapshot },
                            onEdit: { editing = snapshot },
                            onDelete: { deleting = snapshot },
                            revealCLI: app.settings.revealCLI,
                            health: app.health.status(for: snapshot.id),
                            selecting: selecting,
                            isSelected: selection.contains(snapshot.id)
                        )
                    }
                    if !selecting {
                        NewContainerCard(density: app.settings.density) { ui.showRunSheet = true }
                    }
                }
            }
            .padding(Tokens.Space.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .overlay(alignment: .topTrailing) {
            if !filtered.isEmpty {
                Button(selecting ? "Done" : "Select") {
                    selecting.toggle()
                    if !selecting { selection.removeAll() }
                }
                .buttonStyle(.glass)
                .padding(Tokens.Space.m)
            }
        }
        .overlay(alignment: .bottom) {
            if selecting && !selection.isEmpty { batchBar } else if let message = store.errorMessage { ErrorToast(message: message) }
        }
        .overlay {
            if filtered.isEmpty { emptyState }
        }
        .sheet(item: $detail) { snapshot in
            ContainerDetailView(snapshot: snapshot, onClose: { detail = nil })
        }
        .sheet(item: $customizing) { snapshot in
            CustomizeSheet(snapshot: snapshot)
        }
        .sheet(item: $editing) { snapshot in
            ContainerEditSheet(mode: .edit(snapshot, onComplete: { editing = nil }))
        }
        .confirmationDialog(
            "Delete \(customizeName(deleting))?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let id = deleting?.id { Task { await store.remove(id, force: true) } }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("This removes the container. This can't be undone.")
        }
        .refreshable { await store.refresh() }
    }

    private var batchBar: some View {
        HStack(spacing: Tokens.Space.m) {
            Text("\(selection.count) selected").font(.callout.weight(.medium))
            Divider().frame(height: 16)
            Button { batch { await store.start($0) } } label: { Label("Start", systemImage: "play.fill") }
            Button { batch { await store.stop($0) } } label: { Label("Stop", systemImage: "stop.fill") }
            Button(role: .destructive) { batch { await store.remove($0, force: true) } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .buttonStyle(.glass)
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.s)
        .glassEffect(.regular, in: Capsule())
        .padding(.bottom, Tokens.Space.l)
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    /// Run an action over every selected container, then exit selection mode.
    private func batch(_ action: @escaping (String) async -> Void) {
        let ids = selection
        Task {
            for id in ids { await action(id) }
            selection.removeAll()
            selecting = false
        }
    }

    private func customizeName(_ snapshot: ContainerSnapshot?) -> String {
        guard let snapshot else { return "" }
        return app.personalization.resolved(id: snapshot.id, image: snapshot.image)
            .displayName(fallback: snapshot.id)
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No containers", systemImage: "shippingbox")
        } description: {
            Text(ui.runningOnly ? "No running containers." : "Run a container to see it here.")
        } actions: {
            Button("Run a container") { ui.showRunSheet = true }
        }
    }
}

/// The trailing dashed "+ new" card that starts a Create/Run flow.
struct NewContainerCard: View {
    var density: CardDensity
    var action: () -> Void
    private var height: CGFloat { density == .compact ? 118 : 154 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Tokens.Space.s) {
                Image(systemName: "plus").font(.system(size: 20, weight: .medium))
                Text("Run a container").font(.callout)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background {
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }
}

struct ErrorToast: View {
    let message: String
    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).font(.callout).lineLimit(2)
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.m)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.control)
        .padding(Tokens.Space.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
