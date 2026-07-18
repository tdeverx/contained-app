import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("App logging settings")
@MainActor
struct AppLoggingTests {
    @Test func defaultLoggingSettingsAreUsefulButNotNoisy() {
        let settings = SettingsStore(database: AppDatabase(isStoredInMemoryOnly: true))

        #expect(settings.loggingLevel == .important)
        #expect(settings.enabledLogDestinations == [.activity])
        #expect(settings.enabledLogCategories == Set(AppLogCategory.allCases))
        #expect(settings.loggingLevel.includes(.info))
        #expect(settings.loggingLevel.includes(.warning))
        #expect(settings.loggingLevel.includes(.error))
        #expect(!settings.loggingLevel.includes(.debug))
    }

    @Test func loggingSettingsPersistRoundTrip() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        var settings: SettingsStore? = SettingsStore(database: database)
        settings?.loggingLevel = .verbose
        settings?.enabledLogDestinations = [.activity, .console]
        settings?.enabledLogCategories = [.compose, .image]
        settings = nil

        let reloaded = SettingsStore(database: database)
        #expect(reloaded.loggingLevel == .verbose)
        #expect(reloaded.enabledLogDestinations == [.activity, .console])
        #expect(reloaded.enabledLogCategories == [.compose, .image])
        #expect(reloaded.loggingLevel.includes(.debug))
    }

    @Test func statsNormalizationSettingPersistsRoundTrip() {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        var settings: SettingsStore? = SettingsStore(database: database)
        #expect(settings?.statsNormalizationMode == .container)

        settings?.statsNormalizationMode = .machine
        settings = nil

        let reloaded = SettingsStore(database: database)
        #expect(reloaded.statsNormalizationMode == .machine)
    }

    @Test func errorOnlyLoggingFiltersLowerSeverity() {
        #expect(AppLogLevel.errors.includes(.error))
        #expect(!AppLogLevel.errors.includes(.warning))
        #expect(!AppLogLevel.errors.includes(.info))
        #expect(!AppLogLevel.errors.includes(.debug))
    }

    @Test func recordedFailuresPersistOnlyAllowlistedMetadata() throws {
        let database = AppDatabase(isStoredInMemoryOnly: true)
        let settings = SettingsStore(database: database)
        let history = HistoryStore(database: database)
        let logger = AppLogger(settings: settings, history: history)
        let secret = "history-token-SENTINEL"
        let error = Core.Command.Error.nonZeroExit(
            code: 23,
            stderr: "backend leaked \(secret)",
            command: "run --env SECRET=\(secret) --volume /private/SENTINEL:/data"
        )

        logger.recordFailure("Container run failed", error: error, category: .lifecycle)

        let event = try #require(database.fetch(EventRecord.self).first)
        #expect(event.message.contains("exitCode=23"))
        #expect(!event.message.contains(secret))
        #expect(!event.message.contains("/private/SENTINEL"))
        #expect(!event.message.contains("SECRET="))
    }
}
