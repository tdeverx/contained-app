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
    var backdrop: BackdropStyle { didSet { defaults.set(backdrop.rawValue, forKey: Keys.backdrop) } }
    var reduceTranslucency: Bool { didSet { defaults.set(reduceTranslucency, forKey: Keys.reduceTranslucency) } }
    var keepInMenuBar: Bool { didSet { defaults.set(keepInMenuBar, forKey: Keys.keepInMenuBar) } }
    var cliPathOverride: String { didSet { defaults.set(cliPathOverride, forKey: Keys.cliPath) } }
    var refreshInterval: Double { didSet { defaults.set(refreshInterval, forKey: Keys.refresh) } }
    var notifyOnCrash: Bool { didSet { defaults.set(notifyOnCrash, forKey: Keys.notifyOnCrash) } }
    /// Show "Reveal CLI" affordances on destructive/privileged actions (global gate).
    var revealCLI: Bool { didSet { defaults.set(revealCLI, forKey: Keys.revealCLI) } }
    /// How many days of metrics/events the on-disk history keeps before pruning.
    var historyRetentionDays: Int { didSet { defaults.set(historyRetentionDays, forKey: Keys.historyRetention) } }
    /// Which Sparkle update channel the user opts into (stable / beta / nightly).
    var updateChannel: UpdateChannel { didSet { defaults.set(updateChannel.rawValue, forKey: Keys.updateChannel) } }
    /// Last-selected sidebar section, restored on launch.
    var lastSection: String { didSet { defaults.set(lastSection, forKey: Keys.lastSection) } }

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
        density = CardDensity(rawValue: defaults.string(forKey: Keys.density) ?? "") ?? .compact
        backdrop = BackdropStyle(rawValue: defaults.string(forKey: Keys.backdrop) ?? "") ?? .mesh
        reduceTranslucency = defaults.bool(forKey: Keys.reduceTranslucency)
        keepInMenuBar = defaults.object(forKey: Keys.keepInMenuBar) as? Bool ?? true
        cliPathOverride = defaults.string(forKey: Keys.cliPath) ?? ""
        refreshInterval = defaults.object(forKey: Keys.refresh) as? Double ?? 2.0
        notifyOnCrash = defaults.object(forKey: Keys.notifyOnCrash) as? Bool ?? true
        revealCLI = defaults.object(forKey: Keys.revealCLI) as? Bool ?? true
        historyRetentionDays = defaults.object(forKey: Keys.historyRetention) as? Int ?? 7
        // Default to Nightly while the app is pre-1.0 — that's where the only builds ship, so a fresh
        // install actually receives updates. Users can switch to Beta/Stable in Settings → Updates.
        updateChannel = UpdateChannel(rawValue: defaults.string(forKey: Keys.updateChannel) ?? "") ?? .nightly
        lastSection = defaults.string(forKey: Keys.lastSection) ?? ""
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private enum Keys {
        static let tint = "accentTint"
        static let appearance = "appearance"
        static let density = "density"
        static let backdrop = "backdrop"
        static let reduceTranslucency = "reduceTranslucency"
        static let keepInMenuBar = "keepInMenuBar"
        static let cliPath = "cliPathOverride"
        static let refresh = "refreshInterval"
        static let notifyOnCrash = "notifyOnCrash"
        static let revealCLI = "revealCLI"
        static let historyRetention = "historyRetentionDays"
        static let updateChannel = "updateChannel"
        static let lastSection = "lastSection"
    }
}
