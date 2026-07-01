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
    /// Optional color wash applied inside toolbar glass buttons.
    var buttonTintEnabled: Bool { didSet { defaults.set(buttonTintEnabled, forKey: Keys.buttonTintEnabled) } }
    var buttonTint: AppTint { didSet { defaults.set(buttonTint.rawValue, forKey: Keys.buttonTint) } }
    var buttonTintOpacity: Double { didSet { defaults.set(buttonTintOpacity, forKey: Keys.buttonTintOpacity) } }
    var buttonTintGradient: Bool { didSet { defaults.set(buttonTintGradient, forKey: Keys.buttonTintGradient) } }
    var buttonTintGradientAngle: Double { didSet { defaults.set(buttonTintGradientAngle, forKey: Keys.buttonTintGradientAngle) } }
    var buttonTintBlendMode: ColorLayerBlendMode { didSet { defaults.set(buttonTintBlendMode.rawValue, forKey: Keys.buttonTintBlendMode) } }
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
    // MARK: Experimental features
    //
    // Opt-in gates for surfaces that aren't fully baked yet. All default **off** so a fresh install
    // ships the stable core; users enable them in Settings → Experimental. The command palette also
    // has a render-level backstop in `AppToolbar` so flipping it off fully hides the surface
    // regardless of any activation path.

    /// The `⌘K` command palette (toolbar search escalation + menu command + morph).
    var commandPaletteEnabled: Bool { didSet { defaults.set(commandPaletteEnabled, forKey: Keys.commandPaletteEnabled) } }
    /// Inline Docker Hub / registry image search (the creation "Search" path + palette Hub scope).
    var hubSearchEnabled: Bool { didSet { defaults.set(hubSearchEnabled, forKey: Keys.hubSearchEnabled) } }
    /// Compose (YAML) import — paste, file pick, and drag-and-drop.
    var composeImportEnabled: Bool { didSet { defaults.set(composeImportEnabled, forKey: Keys.composeImportEnabled) } }
    /// The Dockerfile image-build workspace.
    var imageBuildEnabled: Bool { didSet { defaults.set(imageBuildEnabled, forKey: Keys.imageBuildEnabled) } }
    /// Menu keyboard shortcuts and command shortcuts. Disabled by default.
    var keyboardShortcutsEnabled: Bool { didSet { defaults.set(keyboardShortcutsEnabled, forKey: Keys.keyboardShortcutsEnabled) } }
    /// Floating toolbar chrome. Off by default so the sidebar shell is the stable fresh-install path.
    var experimentalToolbarUI: Bool { didSet { defaults.set(experimentalToolbarUI, forKey: Keys.experimentalToolbarUI) } }
    /// Route eligible actions through toolbar morph panels instead of classic pages/sheets. Depends on
    /// the floating toolbar so page routing never targets panels without visible toolbar origins.
    var experimentalPanelNavigation: Bool { didSet { defaults.set(experimentalPanelNavigation, forKey: Keys.experimentalPanelNavigation) } }
    var usesPanelNavigation: Bool { experimentalToolbarUI && experimentalPanelNavigation }
    /// Classic-shell sidebar visibility. Separate from the toolbar toggle so users can keep the
    /// stable content shell but reclaim width when they want a page-only layout.
    var sidebarNavigationEnabled: Bool { didSet { defaults.set(sidebarNavigationEnabled, forKey: Keys.sidebarNavigationEnabled) } }

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
        buttonTintEnabled = defaults.object(forKey: Keys.buttonTintEnabled) as? Bool ?? false
        buttonTint = AppTint(rawValue: defaults.string(forKey: Keys.buttonTint) ?? "") ?? .multicolor
        buttonTintOpacity = defaults.object(forKey: Keys.buttonTintOpacity) as? Double ?? 0.18
        buttonTintGradient = defaults.object(forKey: Keys.buttonTintGradient) as? Bool ?? true
        buttonTintGradientAngle = defaults.object(forKey: Keys.buttonTintGradientAngle) as? Double ?? Personalization.defaultGradientAngle
        buttonTintBlendMode = ColorLayerBlendMode(rawValue: defaults.string(forKey: Keys.buttonTintBlendMode) ?? "") ?? .softLight
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
        // Experimental features default off (opt-in).
        commandPaletteEnabled = defaults.object(forKey: Keys.commandPaletteEnabled) as? Bool ?? false
        hubSearchEnabled = defaults.object(forKey: Keys.hubSearchEnabled) as? Bool ?? false
        composeImportEnabled = defaults.object(forKey: Keys.composeImportEnabled) as? Bool ?? false
        imageBuildEnabled = defaults.object(forKey: Keys.imageBuildEnabled) as? Bool ?? false
        keyboardShortcutsEnabled = defaults.object(forKey: Keys.keyboardShortcutsEnabled) as? Bool ?? false
        experimentalToolbarUI = defaults.object(forKey: Keys.experimentalToolbarUI) as? Bool ?? false
        experimentalPanelNavigation = defaults.object(forKey: Keys.experimentalPanelNavigation) as? Bool ?? false
        sidebarNavigationEnabled = defaults.object(forKey: Keys.sidebarNavigationEnabled) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func backupSnapshot() -> SettingsBackup {
        SettingsBackup(accentTint: accentTint,
                       appearance: appearance,
                       density: density,
                       windowMaterial: windowMaterial,
                       modalMaterial: modalMaterial,
                       buttonMaterial: buttonMaterial,
                       buttonTintEnabled: buttonTintEnabled,
                       buttonTint: buttonTint,
                       buttonTintOpacity: buttonTintOpacity,
                       buttonTintGradient: buttonTintGradient,
                       buttonTintGradientAngle: buttonTintGradientAngle,
                       buttonTintBlendMode: buttonTintBlendMode,
                       cardMaterial: cardMaterial,
                       showInfoTips: showInfoTips,
                       imageDefaultStyleEnabled: imageDefaultStyleEnabled,
                       keepInMenuBar: keepInMenuBar,
                       cliPathOverride: cliPathOverride,
                       refreshInterval: refreshInterval,
                       imageUpdateIntervalHours: imageUpdateIntervalHours,
                       imageUpdateChecksEnabled: imageUpdateChecksEnabled,
                       appUpdateChecksEnabled: appUpdateChecksEnabled,
                       autoRestartEnabled: autoRestartEnabled,
                       notifyOnCrash: notifyOnCrash,
                       revealCLI: revealCLI,
                       historyRetentionDays: historyRetentionDays,
                       loggingLevel: loggingLevel,
                       enabledLogDestinations: enabledLogDestinations,
                       enabledLogCategories: enabledLogCategories,
                       updateChannel: updateChannel,
                       commandPaletteEnabled: commandPaletteEnabled,
                       hubSearchEnabled: hubSearchEnabled,
                       composeImportEnabled: composeImportEnabled,
                       imageBuildEnabled: imageBuildEnabled,
                       keyboardShortcutsEnabled: keyboardShortcutsEnabled,
                       experimentalToolbarUI: experimentalToolbarUI,
                       experimentalPanelNavigation: experimentalPanelNavigation,
                       sidebarNavigationEnabled: sidebarNavigationEnabled)
    }

    func applyBackup(_ snapshot: SettingsBackup) {
        accentTint = snapshot.accentTint
        appearance = snapshot.appearance
        density = snapshot.density
        windowMaterial = snapshot.windowMaterial
        modalMaterial = snapshot.modalMaterial
        buttonMaterial = snapshot.buttonMaterial
        buttonTintEnabled = snapshot.buttonTintEnabled
        buttonTint = snapshot.buttonTint
        buttonTintOpacity = snapshot.buttonTintOpacity
        buttonTintGradient = snapshot.buttonTintGradient
        buttonTintGradientAngle = snapshot.buttonTintGradientAngle
        buttonTintBlendMode = snapshot.buttonTintBlendMode
        cardMaterial = snapshot.cardMaterial
        showInfoTips = snapshot.showInfoTips
        imageDefaultStyleEnabled = snapshot.imageDefaultStyleEnabled
        keepInMenuBar = snapshot.keepInMenuBar
        cliPathOverride = snapshot.cliPathOverride
        refreshInterval = snapshot.refreshInterval
        imageUpdateIntervalHours = snapshot.imageUpdateIntervalHours
        imageUpdateChecksEnabled = snapshot.imageUpdateChecksEnabled
        appUpdateChecksEnabled = snapshot.appUpdateChecksEnabled
        autoRestartEnabled = snapshot.autoRestartEnabled
        notifyOnCrash = snapshot.notifyOnCrash
        revealCLI = snapshot.revealCLI
        historyRetentionDays = snapshot.historyRetentionDays
        loggingLevel = snapshot.loggingLevel
        enabledLogDestinations = snapshot.enabledLogDestinations
        enabledLogCategories = snapshot.enabledLogCategories
        updateChannel = snapshot.updateChannel
        commandPaletteEnabled = snapshot.commandPaletteEnabled
        hubSearchEnabled = snapshot.hubSearchEnabled
        composeImportEnabled = snapshot.composeImportEnabled
        imageBuildEnabled = snapshot.imageBuildEnabled
        keyboardShortcutsEnabled = snapshot.keyboardShortcutsEnabled
        experimentalToolbarUI = snapshot.experimentalToolbarUI
        experimentalPanelNavigation = snapshot.experimentalPanelNavigation
        sidebarNavigationEnabled = snapshot.sidebarNavigationEnabled
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
        static let buttonTintEnabled = "buttonTint.enabled"
        static let buttonTint = "buttonTint.tint"
        static let buttonTintOpacity = "buttonTint.opacity"
        static let buttonTintGradient = "buttonTint.gradient"
        static let buttonTintGradientAngle = "buttonTint.gradientAngle"
        static let buttonTintBlendMode = "buttonTint.blendMode"
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
        static let commandPaletteEnabled = "experimental.commandPalette"
        static let hubSearchEnabled = "experimental.hubSearch"
        static let composeImportEnabled = "experimental.composeImport"
        static let imageBuildEnabled = "experimental.imageBuild"
        static let keyboardShortcutsEnabled = "experimental.keyboardShortcuts"
        static let experimentalToolbarUI = "experimental.toolbarUI"
        static let experimentalPanelNavigation = "experimental.panelNavigation"
        static let sidebarNavigationEnabled = "experimental.sidebarNavigation"
    }
}
