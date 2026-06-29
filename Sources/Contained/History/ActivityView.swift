import SwiftUI
import SwiftData

/// System-wide activity log: every recorded event across all containers, newest first, filterable
/// by kind. The persistent counterpart to transient banners and alerts.
struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ActivityContent(showClose: true) { dismiss() }
            .frame(Tokens.SheetSize.wide)
            .sheetMaterial()
    }
}

struct ActivityContent: View {
    @Query(sort: \EventRecord.timestamp, order: .reverse) private var events: [EventRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var filter: EventKind?
    var showClose = false
    /// Flat tiles (no shadow) when hosted in the toolbar morph panel; elevated in the standalone sheet.
    var elevated = true
    var onClose: () -> Void = {}

    private var filtered: [EventRecord] {
        guard let filter else { return events }
        return events.filter { $0.kind == filter }
    }

    private var unreadCount: Int { events.lazy.filter { !$0.isRead }.count }

    private var subtitle: String {
        let base = "\(filtered.count) event\(filtered.count == 1 ? "" : "s")"
        let scoped = filter == nil ? base : "\(base) · \(filter!.rawValue.capitalized)"
        return unreadCount > 0 ? "\(scoped) · \(unreadCount) unread" : scoped
    }

    /// The event-kind filter as a grouped-glass-button menu in the header (replacing the segmented
    /// tab-style picker).
    private var filterMenu: some View {
        Menu {
            Button { filter = nil } label: { Label("All", systemImage: "tray.full") }
            Divider()
            ForEach(EventKind.allCases, id: \.self) { kind in
                Button { filter = kind } label: { Text(kind.rawValue.capitalized) }
            }
        } label: {
            GlassButtonItem(systemName: "line.3.horizontal.decrease", help: "Filter", isLabel: true)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        MorphPanelScaffold(width: Tokens.PanelSize.activity.width) {
            VStack(spacing: 0) {
                PanelHeader(symbol: "bell",
                            title: "Activity",
                            subtitle: subtitle) {
                    GlassButton {
                        filterMenu
                        if unreadCount > 0 {
                            GlassButtonItem(systemName: "checkmark.circle", help: "Mark all as read",
                                            action: markAllRead)
                        }
                        if !events.isEmpty {
                            GlassButtonItem(systemName: "trash", help: "Clear activity", action: clearAll)
                        }
                        if showClose {
                            GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                        }
                    }
                }
                Divider()
            }
        } content: {
            if filtered.isEmpty {
                ContentUnavailableView("No activity", systemImage: "bell",
                                       description: Text("Events from container lifecycle, the watchdog, and healthchecks land here."))
                    .padding(.vertical, Tokens.Space.xl)
            } else {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                    ForEach(filtered) { event in
                        EventRow(event: event, elevated: elevated, isUnread: !event.isRead)
                    }
                }
                .padding(Tokens.Space.l)
            }
        }
        // Once the user has seen the panel, the events are read — clears the toolbar badge on dismiss.
        .onDisappear(perform: markAllRead)
    }

    private func markAllRead() {
        let unread = events.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        for event in unread { event.isRead = true }
        try? modelContext.save()
    }

    private func clearAll() {
        try? modelContext.delete(model: EventRecord.self)
        try? modelContext.save()
    }
}
