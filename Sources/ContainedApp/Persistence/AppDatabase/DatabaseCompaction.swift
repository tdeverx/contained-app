import Foundation
import SQLite3

extension AppDatabase {
    /// SQLite owns locking and atomic replacement; no framework table is accessed directly.
    /// Pause all app writers while VACUUM runs on a utility task.
    func compactDatabase() async {
        guard !isStoredInMemoryOnly, canPersist, historyMaintenanceTask == nil,
              let url = container.configurations.first?.url, save() else { return }
        isCompacting = true
        defer { isCompacting = false }
        await historyMaintenanceTask?.value
        let failure = await Task.detached(priority: .utility) {
            DatabaseCompaction.run(at: url)
        }.value
        maintenanceFailureCode = failure
    }
}

enum DatabaseCompaction {
    static func run(at url: URL) -> String? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .volumeAvailableCapacityForImportantUsageKey])
        guard let size = values?.fileSize,
              let free = values?.volumeAvailableCapacityForImportantUsage,
              free > Int64(size) * 2 + 268_435_456 else {
            return "insufficient-space"
        }
        var connection: OpaquePointer?
        let opened = sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        defer { if let connection { sqlite3_close(connection) } }
        guard opened == SQLITE_OK, let connection else { return "sqlite:\(opened)" }
        sqlite3_busy_timeout(connection, 1000)
        let checkpoint = sqlite3_exec(connection, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil)
        guard checkpoint == SQLITE_OK else { return "sqlite:\(checkpoint)" }
        let result = sqlite3_exec(connection, "VACUUM", nil, nil, nil)
        return result == SQLITE_OK ? nil : "sqlite:\(result)"
    }
}
