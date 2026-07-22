import Foundation
import Testing
@testable import ContainedApp

@Suite("Bounded activity projections")
@MainActor
struct HistoryPerformanceTests {
    @Test func initialSummaryUsesCountsWithoutLoadingRows() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        database.context.insert(EventRecord(timestamp: Date(), containerID: nil,
                                            kind: .system, message: "read", isRead: true))
        database.context.insert(EventRecord(timestamp: Date(), containerID: nil,
                                            kind: .system, message: "unread"))
        database.context.insert(RecipeRecord(name: "Saved", documentData: Data()))
        database.save()

        let history = HistoryStore(database: database)

        #expect(history.activitySummary == ActivitySummary(totalEvents: 2,
                                                           unreadEvents: 1,
                                                           templateCount: 1))
        #expect(history.recentActivity.isEmpty)
    }

    @Test func recentActivityIsBoundedAndMutationsUpdateSummary() async throws {
        let history = HistoryStore(database: AppDatabase(isStoredInMemoryOnly: true))
        for index in 0..<305 {
            history.record(.ui, message: "event-\(index)")
        }

        await history.loadRecentActivity()
        #expect(history.activitySummary.totalEvents == 305)
        #expect(history.activitySummary.unreadEvents == 305)
        #expect(history.recentActivity.count == 300)
        #expect(history.recentActivity.first?.message == "event-304")

        let first = try #require(history.recentActivity.first)
        history.setEventRead(first.id, isRead: true)
        #expect(history.activitySummary.unreadEvents == 304)
        #expect(history.recentActivity.first?.isRead == true)

        history.deleteEvent(first.id)
        #expect(history.activitySummary.totalEvents == 304)
        #expect(history.recentActivity.contains { $0.id == first.id } == false)

        history.markAllEventsRead()
        #expect(history.activitySummary.unreadEvents == 0)
        #expect(history.recentActivity.allSatisfy { $0.isRead })
    }

    @Test func templateMutationsUpdateCachedCount() {
        let history = HistoryStore(database: AppDatabase(isStoredInMemoryOnly: true))
        let record = RecipeRecord(name: "Saved", documentData: Data())

        history.insertTemplate(record)
        #expect(history.activitySummary.templateCount == 1)

        history.deleteTemplate(record)
        #expect(history.activitySummary.templateCount == 0)
    }

    @Test func displayProjectionComputesOneFilteredSnapshot() async throws {
        let history = HistoryStore(database: AppDatabase(isStoredInMemoryOnly: true))
        history.record(.system, message: "system")
        history.record(.ui, message: "ui")
        await history.loadRecentActivity()

        let projection = ActivityDisplayProjection(events: history.recentActivity, filter: .system)

        #expect(projection.filtered.map(\.message) == ["system"])
        #expect(projection.presentKinds == [.system, .ui])
        #expect(projection.unreadCount == 2)
        #expect(projection.filteredUnreadCount == 1)
    }

    @Test func filteredClearPruneAndImportKeepSummaryCoherent() async {
        let now = Date()
        let database = AppDatabase(isStoredInMemoryOnly: true)
        database.context.insert(EventRecord(timestamp: now.addingTimeInterval(-10 * 86_400),
                                            containerID: nil, kind: .alert, message: "expired"))
        database.context.insert(EventRecord(timestamp: now,
                                            containerID: nil, kind: .system, message: "current"))
        database.save()
        let history = HistoryStore(database: database)
        history.retentionDays = 7

        history.pruneOld(now: now)
        #expect(history.activitySummary.totalEvents == 1)
        #expect(history.activitySummary.unreadEvents == 1)

        history.markEventsRead(kind: .system)
        #expect(history.activitySummary.unreadEvents == 0)
        history.clearEvents(kind: .system)
        #expect(history.activitySummary.totalEvents == 0)

        let sourceDatabase = AppDatabase(isStoredInMemoryOnly: true)
        sourceDatabase.context.insert(EventRecord(timestamp: now, containerID: "web",
                                                  kind: .ui, message: "imported"))
        sourceDatabase.save()
        let source = HistoryStore(database: sourceDatabase)
        history.applyHistory(source.historySnapshot(), replace: true)
        #expect(history.activitySummary.totalEvents == 1)
        #expect(history.activitySummary.unreadEvents == 1)

        await history.loadRecentActivity(force: true)
        #expect(history.recentActivity.map(\.message) == ["imported"])
    }

    @Test func containerHistoryReaderReturnsWindowedValues() async {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let now = Date()
        database.context.insert(EventRecord(timestamp: now.addingTimeInterval(-120),
                                            containerID: "web", kind: .ui, message: "old"))
        database.context.insert(EventRecord(timestamp: now, containerID: "web",
                                            kind: .ui, message: "current"))
        database.context.insert(MetricSample(timestamp: now, containerID: "web", cpuFraction: 0.2,
                                             memoryBytes: 1, netRxBytesPerSec: 2, netTxBytesPerSec: 3,
                                             diskReadBytesPerSec: 4, diskWriteBytesPerSec: 5))
        database.save()
        let history = HistoryStore(database: database)

        let snapshot = await history.containerHistory(containerID: "web",
                                                      since: now.addingTimeInterval(-60))

        #expect(snapshot.events.map(\.message) == ["current"])
        #expect(snapshot.metrics.count == 1)
    }
}
