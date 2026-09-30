import Foundation
import SwiftData

@ModelActor
actor DatabaseHistoryMaintainer {
    /// This single-process store has no history-token consumer. Deleting framework history
    /// never deletes Contained's Activity, metrics, settings or inventory models.
    func purge() -> String? {
        do {
            try modelContext.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            return nil
        } catch {
            return AppDatabase.safeDetail(error)
        }
    }
}
