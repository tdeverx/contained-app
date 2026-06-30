import SwiftUI
import ServiceManagement
import ContainedCore

/// User preferences, persisted to `UserDefaults`. `@Observable` so views update live.
@MainActor
@Observable
final class SettingsStore {
    var accentTint: AppTint { didSet { defaults.set(accentTint.rawValue, forKey: Keys.tint) } }
    var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    var density: CardDensity { didSet { defaults.set(density.rawValue, forKey: Keys.density) } }
    /// Behind-window vibrancy material for the main content area.
    var windowMaterial: WindowMaterial { didSet { defaults.set(windowMaterial.rawValue, forKey: Keys.windowMaterial) } }
    /// Material behind modal sheets.
    var modalMaterial: WindowMaterial { didSet { defaults.set(modalMaterial.rawValue, forKey: Keys.modalMaterial) } }
    /// Material for toolbar control surfaces (glass buttons / search field).
    var buttonMaterial: WindowMaterial { didSet { defaults.set(buttonMaterial.rawValue, forKey: Keys.buttonMaterial) } }
    /// Material for resource cards, both compact and expanded.
    var cardMaterial: WindowMaterial { didSet { defaults.set(cardMaterial.rawValue, forKey: Keys.cardMaterial) } }
    /// Show the info.circle help popovers throughout the app.
    var showInfoTips: Bool { didSet { defaults.set(showInfoTips, forKey: Keys.showInfoTips) } }
    /// Let images without their own style inherit the default card design edited in Settings.
    var imageDefaultStyleEnabled: Bool { didSet { defaults.set(imageDefaultStyleEnabled, forKey: Keys.imageDefaultStyleEnabled) } }
    var keepInMenuBar: Bool { didSet { defaults.set(keepInMenuBar, forKey: Keys.keepInMenuBar) } }
    var cliPathOverride: String { didSet { defaults.set(cliPathOverride, forKey: Keys.cliPath) } }
    var refreshInterval: Double { didSet { defaults.set(refreshInterval, forKey: Keys.refresh) } }
    var imageUpdateIntervalHours: Int { didSet { defaults.set(imageUpdateIntervalHours, forKey: Keys.imageUpdateIntervalHours) } }
    /// Automation toggles (surfaced in System → Automation). Each gates a background task.
    var imageUpdateChecksEnabled: Bool { didSet { defaults.set(imageUpdateChecksEnabled, forKey: Keys.imageUpdateChecksEnabled) } }
    var appUpdateChecksEnabled: Bool { didSet { defaults.set(appUpdateChecksEnabled, forKey: Keys.appUpdateChecksEnabled) } }
    var autoRestartEnabled: Bool { didSet { defaults.set(autoRestartEnabled, forKey: Keys.autoRestartEnabled) } }
    var notifyOnCrash: Bool { didSet { defaults.set(notifyOnCrash, forKey: Keys.notifyOnCrash) } }
    /// Show "Reveal CLI" affordances on destructive/privileged actions (global gate).
    var revealCLI: Bool { didSet { defaults.set(revealCLI, forKey: Keys.revealCLI) } }
    /// How many days of metrics/events the on-disk history keeps before pruning.
    var historyRetentionDays: Int { didSet { defaults.set(historyRetentionDays, forKey: Keys.historyRetention) } }
    /// App event logging verbosity.
    var loggingLevel: AppLogLevel { didSet { defaults.set(loggingLevel.rawValue, forKey: Keys.loggingLevel) } }
    /// Logging outputs. Activity history keeps events in-app; Console writes to macOS unified logging.
    var enabledLogDestinations: Set<AppLogDestination> {
        didSet { defaults.set(enabledLogDestinations.map(\.rawValue).sorted(), forKey: Keys.logDestinations) }
    }
    /// Event categories the user wants recorded.
    var enabledLogCategories: Set<AppLogCategory> {
        didSet { defaults.set(enabledLogCategories.map(\.rawValue).sorted(), forKey: Keys.logCategories) }
    }
    /// Which Sparkle update channel the user opts into (stable / beta / nightly).
    var updateChannel: UpdateChannel { didSet { defaults.set(updateChannel.rawValue, forKey: Keys.updateChannel) } }
    /// Register/unregister the app as a login item via `SMAppService`. Backed by the live service
    /// status; failures (e.g. unsigned dev build) leave the stored value and the status governs.
    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                // Best-effort: keep the toggle responsive even if registration isn't available.
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accentTint = AppTint(rawValue: defaults.string(forKey: Keys.tint) ?? "") ?? .multicolor
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        density = CardDensity(stored: defaults.string(forKey: Keys.density))
        windowMaterial = WindowMaterial(rawValue: defaults.string(forKey: Keys.windowMaterial) ?? "") ?? .fullScreenUI
        modalMaterial = WindowMaterial(rawValue: defaults.string(forKey: Keys.modalMaterial) ?? "") ?? .sheet
        buttonMaterial = WindowMaterial(rawValue: defaults.string(forKey: Keys.buttonMaterial) ?? "") ?? .glassClear
        cardMaterial = WindowMaterial(rawValue: defaults.string(forKey: Keys.cardMaterial) ?? "") ?? .glassRegular
        showInfoTips = defaults.object(forKey: Keys.showInfoTips) as? Bool ?? true
        imageDefaultStyleEnabled = defaults.object(forKey: Keys.imageDefaultStyleEnabled) as? Bool ?? true
        keepInMenuBar = defaults.object(forKey: Keys.keepInMenuBar) as? Bool ?? true
        cliPathOverride = defaults.string(forKey: Keys.cliPath) ?? ""
        refreshInterval = defaults.object(forKey: Keys.refresh) as? Double ?? 2.0
        imageUpdateIntervalHours = defaults.object(forKey: Keys.imageUpdateIntervalHours) as? Int ?? 6
        imageUpdateChecksEnabled = defaults.object(forKey: Keys.imageUpdateChecksEnabled) as? Bool ?? true
        appUpdateChecksEnabled = defaults.object(forKey: Keys.appUpdateChecksEnabled) as? Bool ?? true
        autoRestartEnabled = defaults.object(forKey: Keys.autoRestartEnabled) as? Bool ?? true
        notifyOnCrash = defaults.object(forKey: Keys.notifyOnCrash) as? Bool ?? true
        revealCLI = defaults.object(forKey: Keys.revealCLI) as? Bool ?? true
        historyRetentionDays = defaults.object(forKey: Keys.historyRetention) as? Int ?? 7
        loggingLevel = AppLogLevel(rawValue: defaults.string(forKey: Keys.loggingLevel) ?? "") ?? .important
        enabledLogDestinations = Self.loadSet(AppLogDestination.self,
                                              key: Keys.logDestinations,
                                              defaults: defaults,
                                              fallback: [.activity])
        enabledLogCategories = Self.loadSet(AppLogCategory.self,
                                            key: Keys.logCategories,
                                            defaults: defaults,
                                            fallback: Set(AppLogCategory.allCases))
        // Default to Nightly while the app is pre-1.0 — that's where the only builds ship, so a fresh
        // install actually receives updates. Users can switch to Beta/Stable in Settings → Updates.
        updateChannel = UpdateChannel(rawValue: defaults.string(forKey: Keys.updateChannel) ?? "") ?? .nightly
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func backupSnapshot() -> SettingsBackup {
        SettingsBackup(accentTint: accentTint,
                       appearance: appearance,
                       density: density,
                       windowMaterial: windowMaterial,
                       modalMaterial: modalMaterial,
                       buttonMaterial: buttonMaterial,
                       showInfoTips: showInfoTips,
                       imageDefaultStyleEnabled: imageDefaultStyleEnabled,
                       keepInMenuBar: keepInMenuBar,
                       cliPathOverride: cliPathOverride,
                       refreshInterval: refreshInterval,
                       imageUpdateIntervalHours: imageUpdateIntervalHours,
                       notifyOnCrash: notifyOnCrash,
                       revealCLI: revealCLI,
                       historyRetentionDays: historyRetentionDays,
                       loggingLevel: loggingLevel,
                       enabledLogDestinations: enabledLogDestinations,
                       enabledLogCategories: enabledLogCategories,
                       updateChannel: updateChannel)
    }

    func applyBackup(_ snapshot: SettingsBackup) {
        accentTint = snapshot.accentTint
        appearance = snapshot.appearance
        density = snapshot.density
        windowMaterial = snapshot.windowMaterial
        modalMaterial = snapshot.modalMaterial
        buttonMaterial = snapshot.buttonMaterial
        showInfoTips = snapshot.showInfoTips
        imageDefaultStyleEnabled = snapshot.imageDefaultStyleEnabled
        keepInMenuBar = snapshot.keepInMenuBar
        cliPathOverride = snapshot.cliPathOverride
        refreshInterval = snapshot.refreshInterval
        imageUpdateIntervalHours = snapshot.imageUpdateIntervalHours
        notifyOnCrash = snapshot.notifyOnCrash
        revealCLI = snapshot.revealCLI
        historyRetentionDays = snapshot.historyRetentionDays
        loggingLevel = snapshot.loggingLevel
        enabledLogDestinations = snapshot.enabledLogDestinations
        enabledLogCategories = snapshot.enabledLogCategories
        updateChannel = snapshot.updateChannel
    }

    private static func loadSet<T: RawRepresentable & Hashable>(_ type: T.Type,
                                                                key: String,
                                                                defaults: UserDefaults,
                                                                fallback: Set<T>) -> Set<T> where T.RawValue == String {
        guard let raw = defaults.stringArray(forKey: key) else { return fallback }
        return Set(raw.compactMap { T(rawValue: $0) })
    }

    private enum Keys {
        static let tint = "accentTint"
        static let appearance = "appearance"
        static let density = "density"
        static let windowMaterial = "windowMaterial"
        static let modalMaterial = "modalMaterial"
        static let buttonMaterial = "buttonMaterial"
        static let cardMaterial = "cardMaterial"
        static let showInfoTips = "showInfoTips"
        static let imageDefaultStyleEnabled = "imageDefaultStyleEnabled"
        static let keepInMenuBar = "keepInMenuBar"
        static let cliPath = "cliPathOverride"
        static let refresh = "refreshInterval"
        static let imageUpdateIntervalHours = "imageUpdateIntervalHours"
        static let imageUpdateChecksEnabled = "imageUpdateChecksEnabled"
        static let appUpdateChecksEnabled = "appUpdateChecksEnabled"
        static let autoRestartEnabled = "autoRestartEnabled"
        static let notifyOnCrash = "notifyOnCrash"
        static let revealCLI = "revealCLI"
        static let historyRetention = "historyRetentionDays"
        static let loggingLevel = "loggingLevel"
        static let logDestinations = "logDestinations"
        static let logCategories = "logCategories"
        static let updateChannel = "updateChannel"
    }
}

struct SettingsBackup: Codable, Equatable {
    var accentTint: AppTint
    var appearance: AppearanceMode
    var density: CardDensity
    var windowMaterial: WindowMaterial
    var modalMaterial: WindowMaterial
    var buttonMaterial: WindowMaterial
    var showInfoTips: Bool
    var imageDefaultStyleEnabled: Bool
    var keepInMenuBar: Bool
    var cliPathOverride: String
    var refreshInterval: Double
    var imageUpdateIntervalHours: Int
    var notifyOnCrash: Bool
    var revealCLI: Bool
    var historyRetentionDays: Int
    var loggingLevel: AppLogLevel
    var enabledLogDestinations: Set<AppLogDestination>
    var enabledLogCategories: Set<AppLogCategory>
    var updateChannel: UpdateChannel
}
