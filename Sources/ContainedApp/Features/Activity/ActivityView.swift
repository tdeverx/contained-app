import SwiftUI
import ContainedUX
import ContainedUI

/// System-wide activity log: every recorded event across all containers, newest first, filterable
/// by kind. The persistent counterpart to transient banners and alerts.
struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ActivityContent(showClose: true) { dismiss() }
            .frame(UI.Panel.SheetSize.wide)
            .sheetMaterial()
    }
}

struct ActivityContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var showClose = false
    /// Flat tiles (no shadow) when hosted in the toolbar morph panel; elevated in the standalone sheet.
    var elevated = true
    var onClose: () -> Void = {}
    @State private var projection = ActivityDisplayProjection(events: [], filter: nil)

    private func subtitle(_ projection: ActivityDisplayProjection) -> String {
        let base = AppText.string("activity.subtitle.events", defaultValue: "\(projection.filtered.count) event\(projection.filtered.count == 1 ? "" : "s")")
        let scoped = ui.activityFilter == nil ? base : "\(base) · \(ui.activityFilter!.rawValue.capitalized)"
        return projection.unreadCount > 0
            ? AppText.string("activity.subtitle.unread", defaultValue: "\(scoped) · \(projection.unreadCount) unread")
            : scoped
    }

    /// A single filter control: a glass menu whose checkmark tracks the active kind. It *filters* the
    /// list in place (it isn't a set of page tabs).
    private func filterMenu(_ projection: ActivityDisplayProjection) -> some View {
        @Bindable var ui = ui
        return Menu {
            Picker(AppText.string("activity.filter", defaultValue: "Filter"), selection: $ui.activityFilter) {
                Label(AppText.string("activity.filter.allEvents", defaultValue: "All events"), systemImage: "tray.full").tag(EventKind?.none)
                if !projection.presentKinds.isEmpty { Divider() }
                ForEach(projection.presentKinds, id: \.self) { kind in
                    Label(kind.rawValue.capitalized, systemImage: kind.symbol).tag(EventKind?.some(kind))
                }
            }
            .pickerStyle(.inline)
        } label: {
            UI.Action.MenuLabel(systemName: ui.activityFilter == nil ? "line.3.horizontal.decrease"
                                                                        : "line.3.horizontal.decrease.circle.fill",
                                  help: ui.activityFilter == nil
                                      ? AppText.string("activity.filter", defaultValue: "Filter")
                                      : AppText.string("activity.filter.current", defaultValue: "Filter: \(ui.activityFilter!.rawValue.capitalized)"))
        }
        .buttonStyle(.plain)
        .disabled(projection.presentKinds.isEmpty)
    }

    private var showsHeader: Bool {
        showClose || !ui.toolbarUIEnabled
    }

    var body: some View {
        let projection = projection
        UI.Panel.Scaffold(width: UI.Panel.Size.activity.width) {
            if showsHeader {
                VStack(spacing: 0) {
                    UI.Panel.Header(symbol: "bell",
                                title: AppText.sectionActivity,
                                subtitle: subtitle(projection)) {
                        UI.Action.Cluster {
                            filterMenu(projection)
                            UI.Action.Items(activityHeaderActions(projection))
                        }
                    }
                    Divider()
                }
            }
        } content: {
            if projection.filtered.isEmpty {
                UI.State.Empty(AppText.string("activity.empty", defaultValue: "No activity"),
                                 systemImage: "bell",
                                 description: AppText.string("activity.empty.description", defaultValue: "Events from container lifecycle, the watchdog, and healthchecks land here."))
            } else {
                UI.List.Stack {
                    ForEach(projection.filtered) { event in
                        EventRow(event: event,
                                 elevated: elevated,
                                 isUnread: !event.isRead,
                                 onReadChange: { app.historyStore.setEventRead(event.id, isRead: $0) },
                                 onDelete: { app.historyStore.deleteEvent(event.id) })
                    }
                }
            }
        }
        .task { await app.historyStore.loadRecentActivity() }
        .task(id: ActivityProjectionKey(revision: app.historyStore.activityRevision,
                                        filter: ui.activityFilter)) {
            let interval = PerformanceSignposts.activity.beginInterval("ActivityProjection")
            defer { PerformanceSignposts.activity.endInterval("ActivityProjection", interval) }
            self.projection = ActivityDisplayProjection(events: app.historyStore.recentActivity,
                                                        filter: ui.activityFilter)
        }
        // Once the user has seen the panel, the events are read — clears the toolbar badge on dismiss.
        .onDisappear(perform: markAllRead)
    }

    private func activityHeaderActions(_ projection: ActivityDisplayProjection) -> [UI.Action.Item] {
        var actions = [
            UI.Action.Item(systemName: "checkmark.circle",
                         help: ui.activityFilter == nil
                             ? AppText.string("activity.markAllRead.help", defaultValue: "Mark all as read")
                             : AppText.string("activity.markFilteredRead.help", defaultValue: "Mark \(ui.activityFilter!.rawValue.capitalized) as read"),
                         isEnabled: projection.filteredUnreadCount > 0,
                         action: markFilteredRead),
            UI.Action.Item(systemName: "trash",
                         help: ui.activityFilter == nil
                             ? AppText.clearActivity
                             : AppText.string("activity.clearFiltered.help", defaultValue: "Clear \(ui.activityFilter!.rawValue.capitalized) events"),
                         role: .destructive,
                         isEnabled: !projection.filtered.isEmpty,
                         action: clearFiltered)
        ]
        if showClose {
            actions.append(UI.Action.Item(systemName: "xmark",
                                        help: AppText.close,
                                        isCancel: true,
                                        action: onClose))
        }
        return actions
    }

    /// Marks every event read — used on dismiss (the whole panel has been seen).
    private func markAllRead() {
        app.historyStore.markAllEventsRead()
    }

    /// Header action: marks only the currently-shown (filtered) events read.
    private func markFilteredRead() {
        app.historyStore.markEventsRead(kind: ui.activityFilter)
    }

    /// Header action: clears only the currently-shown events. With no filter that's everything; with a
    /// filter active it removes just that kind.
    private func clearFiltered() {
        app.historyStore.clearEvents(kind: ui.activityFilter)
    }
}

private struct ActivityProjectionKey: Hashable {
    let revision: Int
    let filter: EventKind?
}

struct ActivityDisplayProjection: Equatable, Sendable {
    let filtered: [ActivityEvent]
    let presentKinds: [EventKind]
    let unreadCount: Int
    let filteredUnreadCount: Int

    init(events: [ActivityEvent], filter: EventKind?) {
        filtered = filter.map { kind in events.filter { $0.kind == kind } } ?? events
        let present = Set(events.map(\.kind))
        presentKinds = EventKind.allCases.filter(present.contains)
        unreadCount = events.lazy.filter { !$0.isRead }.count
        filteredUnreadCount = filtered.lazy.filter { !$0.isRead }.count
    }
}
