import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import SwiftData

/// System-wide activity log: every recorded event across all containers, newest first, filterable
/// by kind. The persistent counterpart to transient banners and alerts.
struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ActivityContent(showClose: true) { dismiss() }
            .frame(DesignTokens.SheetSize.wide)
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
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    var showClose = false
    /// Flat tiles (no shadow) when hosted in the toolbar morph panel; elevated in the standalone sheet.
    var elevated = true
    var onClose: () -> Void = {}

    private var filtered: [EventRecord] {
        guard let filter = ui.activityFilter else { return events }
        return events.filter { $0.kind == filter }
    }

    private var unreadCount: Int { events.lazy.filter { !$0.isRead }.count }

    private var subtitle: String {
        let base = AppText.string("activity.subtitle.events", defaultValue: "\(filtered.count) event\(filtered.count == 1 ? "" : "s")")
        let scoped = ui.activityFilter == nil ? base : "\(base) · \(ui.activityFilter!.rawValue.capitalized)"
        return unreadCount > 0
            ? AppText.string("activity.subtitle.unread", defaultValue: "\(scoped) · \(unreadCount) unread")
            : scoped
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
        @Bindable var ui = ui
        return Menu {
            Picker(AppText.string("activity.filter", defaultValue: "Filter"), selection: $ui.activityFilter) {
                Label(AppText.string("activity.filter.allEvents", defaultValue: "All events"), systemImage: "tray.full").tag(EventKind?.none)
                if !presentKinds.isEmpty { Divider() }
                ForEach(presentKinds, id: \.self) { kind in
                    Label(kind.rawValue.capitalized, systemImage: kind.symbol).tag(EventKind?.some(kind))
                }
            }
            .pickerStyle(.inline)
        } label: {
            DesignMenuActionLabel(systemName: ui.activityFilter == nil ? "line.3.horizontal.decrease"
                                                                        : "line.3.horizontal.decrease.circle.fill",
                                  help: ui.activityFilter == nil
                                      ? AppText.string("activity.filter", defaultValue: "Filter")
                                      : AppText.string("activity.filter.current", defaultValue: "Filter: \(ui.activityFilter!.rawValue.capitalized)"))
        }
        .buttonStyle(.plain)
        .disabled(presentKinds.isEmpty)
    }

    private var showsHeader: Bool {
        showClose || !ui.toolbarUIEnabled
    }

    var body: some View {
        DesignPanelScaffold(width: DesignTokens.PanelSize.activity.width) {
            if showsHeader {
                VStack(spacing: 0) {
                    PanelHeader(symbol: "bell",
                                title: AppText.sectionActivity,
                                subtitle: subtitle) {
                        DesignActionCluster {
                            filterMenu
                            DesignActionItems(activityHeaderActions)
                        }
                    }
                    Divider()
                }
            }
        } content: {
            if filtered.isEmpty {
                ContentUnavailableView(AppText.string("activity.empty", defaultValue: "No activity"),
                                       systemImage: "bell",
                                       description: Text(AppText.string("activity.empty.description", defaultValue: "Events from container lifecycle, the watchdog, and healthchecks land here.")))
                    .padding(.vertical, DesignTokens.Space.xl)
            } else {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Space.s) {
                    ForEach(filtered) { event in
                        EventRow(event: event, elevated: elevated, isUnread: !event.isRead)
                    }
                }
                .padding(DesignTokens.Space.s)
            }
        }
        // Once the user has seen the panel, the events are read — clears the toolbar badge on dismiss.
        .onDisappear(perform: markAllRead)
    }

    private var activityHeaderActions: [DesignAction] {
        var actions = [
            DesignAction(systemName: "checkmark.circle",
                         help: ui.activityFilter == nil
                             ? AppText.string("activity.markAllRead.help", defaultValue: "Mark all as read")
                             : AppText.string("activity.markFilteredRead.help", defaultValue: "Mark \(ui.activityFilter!.rawValue.capitalized) as read"),
                         isEnabled: filteredUnreadCount > 0,
                         action: markFilteredRead),
            DesignAction(systemName: "trash",
                         help: ui.activityFilter == nil
                             ? AppText.clearActivity
                             : AppText.string("activity.clearFiltered.help", defaultValue: "Clear \(ui.activityFilter!.rawValue.capitalized) events"),
                         role: .destructive,
                         isEnabled: !filtered.isEmpty,
                         action: clearFiltered)
        ]
        if showClose {
            actions.append(DesignAction(systemName: "xmark",
                                        help: AppText.close,
                                        isCancel: true,
                                        action: onClose))
        }
        return actions
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
        if let filter = ui.activityFilter {
            for event in events where event.kind == filter { modelContext.delete(event) }
        } else {
            try? modelContext.delete(model: EventRecord.self)
        }
        try? modelContext.save()
    }
}
