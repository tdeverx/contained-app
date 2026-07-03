import Foundation
import Testing
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
}
