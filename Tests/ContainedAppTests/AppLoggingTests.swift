import Foundation
import Testing
@testable import Contained

@Suite("App logging settings")
@MainActor
struct AppLoggingTests {
    @Test func defaultLoggingSettingsAreUsefulButNotNoisy() {
        let defaults = suiteDefaults()
        let settings = SettingsStore(defaults: defaults)

        #expect(settings.loggingLevel == .important)
        #expect(settings.enabledLogDestinations == [.activity])
        #expect(settings.enabledLogCategories == Set(AppLogCategory.allCases))
        #expect(settings.loggingLevel.includes(.info))
        #expect(settings.loggingLevel.includes(.warning))
        #expect(settings.loggingLevel.includes(.error))
        #expect(!settings.loggingLevel.includes(.debug))
    }

    @Test func loggingSettingsPersistRoundTrip() {
        let defaults = suiteDefaults()
        var settings: SettingsStore? = SettingsStore(defaults: defaults)
        settings?.loggingLevel = .verbose
        settings?.enabledLogDestinations = [.activity, .console]
        settings?.enabledLogCategories = [.compose, .image]
        settings = nil

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.loggingLevel == .verbose)
        #expect(reloaded.enabledLogDestinations == [.activity, .console])
        #expect(reloaded.enabledLogCategories == [.compose, .image])
        #expect(reloaded.loggingLevel.includes(.debug))
    }

    @Test func statsNormalizationSettingPersistsRoundTrip() {
        let defaults = suiteDefaults()
        var settings: SettingsStore? = SettingsStore(defaults: defaults)
        #expect(settings?.statsNormalizationMode == .container)

        settings?.statsNormalizationMode = .machine
        settings = nil

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.statsNormalizationMode == .machine)
    }

    @Test func errorOnlyLoggingFiltersLowerSeverity() {
        #expect(AppLogLevel.errors.includes(.error))
        #expect(!AppLogLevel.errors.includes(.warning))
        #expect(!AppLogLevel.errors.includes(.info))
        #expect(!AppLogLevel.errors.includes(.debug))
    }

    private func suiteDefaults() -> UserDefaults {
        let name = "ContainedTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
