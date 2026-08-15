import SwiftUI
import ContainedUI
import ContainedCore
import SwiftData

/// Notifications associated with one container, separated from its resource history.
struct ContainerAlertsTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: Core.Container.Snapshot
    @State private var events: [ActivityEvent] = []

    var body: some View {
        ContainerTabScaffold {
            if events.isEmpty {
                UI.State.Empty(AppText.string("containerAlerts.empty", defaultValue: "No alerts yet"),
                               systemImage: "bell",
                               description: AppText.string("containerAlerts.empty.description", defaultValue: "Lifecycle, health, image, and watchdog notifications for this container appear here."))
            } else {
                UI.List.Stack(padding: 0) {
                    ForEach(events) { event in
                        EventRow(event: event,
                                 elevated: false,
                                 isUnread: !event.isRead,
                                 onReadChange: { updateRead(event.id, isRead: $0) },
                                 onDelete: { deleteEvent(event.id) })
                    }
                }
            }
        }
        .task(id: AlertLoadKey(scopedContainerID: snapshot.scopedID,
                               retentionDays: app.settings.historyRetentionDays,
                               revision: app.historyStore.activityRevision)) {
            let cutoff = Date().addingTimeInterval(-TimeInterval(app.settings.historyRetentionDays) * 86_400)
            let loaded = await app.historyStore.containerEvents(scopedContainerID: snapshot.scopedID,
                                                                since: cutoff)
            guard !Task.isCancelled else { return }
            events = loaded
        }
    }

    private func updateRead(_ id: PersistentIdentifier, isRead: Bool) {
        app.historyStore.setEventRead(id, isRead: isRead)
        if let index = events.firstIndex(where: { $0.id == id }) {
            events[index].isRead = isRead
        }
    }

    private func deleteEvent(_ id: PersistentIdentifier) {
        app.historyStore.deleteEvent(id)
        events.removeAll { $0.id == id }
    }
}

private struct AlertLoadKey: Hashable {
    let scopedContainerID: String
    let retentionDays: Int
    let revision: Int
}
