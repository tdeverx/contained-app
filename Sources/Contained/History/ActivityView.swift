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

/// Recent-events fetch for the Activity panel. The fetch is **capped** — an unbounded query plus the
/// full-list layout the hugging morph panel performs on open was making the panel slow to appear. The
/// panel is a recent-activity view; older events are still pruned on the retention schedule.
private let activityEventsDescriptor: FetchDescriptor<EventRecord> = {
    var descriptor = FetchDescriptor<EventRecord>(sortBy: [SortDescriptor(\EventRecord.timestamp, order: .reverse)])
    descriptor.fetchLimit = 300
    return descriptor
}()

struct ActivityContent: View {
    @Query(activityEventsDescriptor) private var events: [EventRecord]
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

    /// Event kinds that actually appear in the current events — the only kinds worth offering as a
    /// filter (no empty buckets).
    private var presentKinds: [EventKind] {
        let present = Set(events.map(\.kind))   // one pass, then 11 lookups
        return EventKind.allCases.filter(present.contains)
    }

    private var filteredUnreadCount: Int { filtered.lazy.filter { !$0.isRead }.count }

    /// A single filter control: a glass menu whose checkmark tracks the active kind. It *filters* the
    /// list in place (it isn't a set of page tabs).
    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $filter) {
                Label("All events", systemImage: "tray.full").tag(EventKind?.none)
                if !presentKinds.isEmpty { Divider() }
                ForEach(presentKinds, id: \.self) { kind in
                    Label(kind.rawValue.capitalized, systemImage: kind.symbol).tag(EventKind?.some(kind))
                }
            }
            .pickerStyle(.inline)
        } label: {
            GlassButtonItem(systemName: filter == nil ? "line.3.horizontal.decrease"
                                                      : "line.3.horizontal.decrease.circle.fill",
                            help: filter == nil ? "Filter" : "Filter: \(filter!.rawValue.capitalized)")
        }
        .buttonStyle(.plain)
        .disabled(presentKinds.isEmpty)
    }

    var body: some View {
        MorphPanelScaffold(width: Tokens.PanelSize.activity.width) {
            VStack(spacing: 0) {
                PanelHeader(symbol: "bell",
                            title: "Activity",
                            subtitle: subtitle) {
                    GlassButton {
                        filterMenu
                        GlassButtonItem(systemName: "checkmark.circle",
                                        help: filter == nil ? "Mark all as read"
                                                            : "Mark \(filter!.rawValue.capitalized) as read",
                                        action: markFilteredRead)
                            .disabled(filteredUnreadCount == 0)
                        GlassButtonItem(systemName: "trash",
                                        role: .destructive,
                                        help: filter == nil ? "Clear activity"
                                                            : "Clear \(filter!.rawValue.capitalized) events",
                                        action: clearFiltered)
                            .disabled(filtered.isEmpty)
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
                .padding(Tokens.Space.s)
            }
        }
        // Once the user has seen the panel, the events are read — clears the toolbar badge on dismiss.
        .onDisappear(perform: markAllRead)
    }

    /// Marks every event read — used on dismiss (the whole panel has been seen).
    private func markAllRead() {
        let unread = events.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        for event in unread { event.isRead = true }
        try? modelContext.save()
    }

    /// Header action: marks only the currently-shown (filtered) events read.
    private func markFilteredRead() {
        let unread = filtered.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        for event in unread { event.isRead = true }
        try? modelContext.save()
    }

    /// Header action: clears only the currently-shown events. With no filter that's everything; with a
    /// filter active it removes just that kind.
    private func clearFiltered() {
        if let filter {
            for event in events where event.kind == filter { modelContext.delete(event) }
        } else {
            try? modelContext.delete(model: EventRecord.self)
        }
        try? modelContext.save()
    }
}
