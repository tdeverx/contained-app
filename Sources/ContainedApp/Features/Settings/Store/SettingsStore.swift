import SwiftUI
import ContainedUI
import ServiceManagement
import ContainedCore

/// User preferences, persisted through the app database. `@Observable` so views update live.
@MainActor
@Observable
final class SettingsStore {
    var accentTint: UI.Theme.Tint { didSet { persist(accentTint.rawValue, for: Keys.tint) } }
    var appearance: UI.Theme.Appearance { didSet { persist(appearance.rawValue, for: Keys.appearance) } }
    var density: UI.Card.Density { didSet { persist(density.rawValue, for: Keys.density) } }
    /// Behind-window vibrancy material for the main content area.
    var windowMaterial: UI.Theme.WindowMaterial { didSet { persist(windowMaterial.rawValue, for: Keys.windowMaterial) } }
    /// Material behind modal sheets.
    var modalMaterial: UI.Theme.WindowMaterial { didSet { persist(modalMaterial.rawValue, for: Keys.modalMaterial) } }
    /// Material for toolbar control surfaces (glass buttons / search field).
    var buttonMaterial: UI.Theme.WindowMaterial { didSet { persist(buttonMaterial.rawValue, for: Keys.buttonMaterial) } }
    /// Optional color wash applied inside toolbar glass buttons.
    var buttonTintEnabled: Bool { didSet { persist(buttonTintEnabled, for: Keys.buttonTintEnabled) } }
    var buttonTint: UI.Theme.Tint { didSet { persist(buttonTint.rawValue, for: Keys.buttonTint) } }
    var buttonTintOpacity: Double { didSet { persist(buttonTintOpacity, for: Keys.buttonTintOpacity) } }
    var buttonTintGradient: Bool { didSet { persist(buttonTintGradient, for: Keys.buttonTintGradient) } }
    var buttonTintGradientAngle: Double { didSet { persist(buttonTintGradientAngle, for: Keys.buttonTintGradientAngle) } }
    var buttonTintBlendMode: UI.Theme.ColorBlendMode { didSet { persist(buttonTintBlendMode.rawValue, for: Keys.buttonTintBlendMode) } }
    /// Material for cards, both compact and expanded.
    var cardMaterial: UI.Theme.WindowMaterial { didSet { persist(cardMaterial.rawValue, for: Keys.cardMaterial) } }
    /// Show the info.circle help popovers throughout the app.
    var showInfoTips: Bool { didSet { persist(showInfoTips, for: Keys.showInfoTips) } }
    /// Let images without their own style inherit the default card design edited in Settings.
    var imageDefaultStyleEnabled: Bool { didSet { persist(imageDefaultStyleEnabled, for: Keys.imageDefaultStyleEnabled) } }
    var keepInMenuBar: Bool { didSet { persist(keepInMenuBar, for: Keys.keepInMenuBar) } }
    private var runtimePathOverrides: [Core.Runtime.Kind: String]
    var refreshInterval: Double { didSet { persist(refreshInterval, for: Keys.refresh) } }
    var statsNormalizationMode: Core.Metrics.NormalizationMode {
        didSet { persist(statsNormalizationMode.rawValue, for: Keys.statsNormalizationMode) }
    }
    var imageUpdateIntervalHours: Int { didSet { persist(imageUpdateIntervalHours, for: Keys.imageUpdateIntervalHours) } }
    /// Automation toggles (surfaced in System → Automation). Each gates a background task.
    var imageUpdateChecksEnabled: Bool { didSet { persist(imageUpdateChecksEnabled, for: Keys.imageUpdateChecksEnabled) } }
    var appUpdateChecksEnabled: Bool { didSet { persist(appUpdateChecksEnabled, for: Keys.appUpdateChecksEnabled) } }
    var autoRestartEnabled: Bool { didSet { persist(autoRestartEnabled, for: Keys.autoRestartEnabled) } }
    var notifyOnCrash: Bool { didSet { persist(notifyOnCrash, for: Keys.notifyOnCrash) } }
    /// Show "Reveal CLI" affordances on destructive/privileged actions (global gate).
    var revealCLI: Bool { didSet { persist(revealCLI, for: Keys.revealCLI) } }
    /// How many days of metrics/events the on-disk history keeps before pruning.
    var historyRetentionDays: Int { didSet { persist(historyRetentionDays, for: Keys.historyRetention) } }
    /// App event logging verbosity.
    var loggingLevel: AppLogLevel { didSet { persist(loggingLevel.rawValue, for: Keys.loggingLevel) } }
    /// Logging outputs. Activity history keeps events in-app; Console writes to macOS unified logging.
    var enabledLogDestinations: Set<AppLogDestination> {
        didSet { persist(enabledLogDestinations.map(\.rawValue).sorted(), for: Keys.logDestinations) }
    }
    /// Event categories the user wants recorded.
    var enabledLogCategories: Set<AppLogCategory> {
        didSet { persist(enabledLogCategories.map(\.rawValue).sorted(), for: Keys.logCategories) }
    }
    /// Which Sparkle update channel the user opts into (stable / beta / nightly).
    var updateChannel: UpdateChannel { didSet { persist(updateChannel.rawValue, for: Keys.updateChannel) } }
    // MARK: Experimental features
    //
    // Opt-in gates for surfaces that aren't fully baked yet. All default **off** so a fresh install
    // ships the stable core; users enable them in Settings → Experimental. The command palette also
    // has a render-level backstop in `AppToolbar` so flipping it off fully hides the surface
    // regardless of any activation path.

    /// The `⌘K` command palette (toolbar search escalation + menu command + morph).
    var commandPaletteEnabled: Bool { didSet { persist(commandPaletteEnabled, for: Keys.commandPaletteEnabled) } }
    /// Inline Docker Hub / registry image search (the creation "Search" path + palette Hub scope).
    var hubSearchEnabled: Bool { didSet { persist(hubSearchEnabled, for: Keys.hubSearchEnabled) } }
    /// Compose (YAML) import — paste, file pick, and drag-and-drop.
    var composeImportEnabled: Bool { didSet { persist(composeImportEnabled, for: Keys.composeImportEnabled) } }
    /// The Dockerfile image-build workspace.
    var imageBuildEnabled: Bool { didSet { persist(imageBuildEnabled, for: Keys.imageBuildEnabled) } }
    /// Menu keyboard shortcuts and command shortcuts. Disabled by default.
    var keyboardShortcutsEnabled: Bool { didSet { persist(keyboardShortcutsEnabled, for: Keys.keyboardShortcutsEnabled) } }
    /// Floating toolbar chrome. Off by default so the sidebar shell is the stable fresh-install path.
    var experimentalToolbarUI: Bool { didSet { persist(experimentalToolbarUI, for: Keys.experimentalToolbarUI) } }
    /// Route eligible actions through toolbar morph panels instead of classic pages/sheets. Depends on
    /// the floating toolbar so page routing never targets panels without visible toolbar origins.
    var experimentalPanelNavigation: Bool { didSet { persist(experimentalPanelNavigation, for: Keys.experimentalPanelNavigation) } }
    var usesPanelNavigation: Bool { experimentalToolbarUI && experimentalPanelNavigation }
    /// Classic-shell sidebar visibility. Separate from the toolbar toggle so users can keep the
    /// stable content shell but reclaim width when they want a page-only layout.
    var sidebarNavigationEnabled: Bool { didSet { persist(sidebarNavigationEnabled, for: Keys.sidebarNavigationEnabled) } }

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

    private let database: AppDatabase

    init(database: AppDatabase = AppDatabase()) {
        self.database = database
        for descriptor in Core.Runtime.supportedDescriptors {
            _ = database.runtimeRecord(for: descriptor.kind)
        }
        accentTint = UI.Theme.Tint(rawValue: database.setting(Keys.tint, fallback: "")) ?? .multicolor
        appearance = UI.Theme.Appearance(rawValue: database.setting(Keys.appearance, fallback: "")) ?? .system
        density = UI.Card.Density(stored: database.setting(Keys.density, fallback: ""))
        windowMaterial = UI.Theme.WindowMaterial(rawValue: database.setting(Keys.windowMaterial, fallback: "")) ?? .fullScreenUI
        modalMaterial = UI.Theme.WindowMaterial(rawValue: database.setting(Keys.modalMaterial, fallback: "")) ?? .sheet
        buttonMaterial = UI.Theme.WindowMaterial(rawValue: database.setting(Keys.buttonMaterial, fallback: "")) ?? .glassClear
        buttonTintEnabled = database.setting(Keys.buttonTintEnabled, fallback: false)
        buttonTint = UI.Theme.Tint(rawValue: database.setting(Keys.buttonTint, fallback: "")) ?? .multicolor
        buttonTintOpacity = database.setting(Keys.buttonTintOpacity, fallback: 0.18)
        buttonTintGradient = database.setting(Keys.buttonTintGradient, fallback: true)
        buttonTintGradientAngle = database.setting(Keys.buttonTintGradientAngle, fallback: Personalization.defaultGradientAngle)
        buttonTintBlendMode = UI.Theme.ColorBlendMode(rawValue: database.setting(Keys.buttonTintBlendMode, fallback: "")) ?? .softLight
        cardMaterial = UI.Theme.WindowMaterial(rawValue: database.setting(Keys.cardMaterial, fallback: "")) ?? .glassRegular
        showInfoTips = database.setting(Keys.showInfoTips, fallback: true)
        imageDefaultStyleEnabled = database.setting(Keys.imageDefaultStyleEnabled, fallback: true)
        keepInMenuBar = database.setting(Keys.keepInMenuBar, fallback: true)
        runtimePathOverrides = Dictionary(uniqueKeysWithValues: Core.Runtime.supportedDescriptors.map { descriptor in
            (descriptor.kind, database.runtimePathOverride(for: descriptor.kind))
        })
        refreshInterval = database.setting(Keys.refresh, fallback: 2.0)
        statsNormalizationMode = Core.Metrics.NormalizationMode(rawValue: database.setting(Keys.statsNormalizationMode, fallback: "")) ?? .container
        imageUpdateIntervalHours = database.setting(Keys.imageUpdateIntervalHours, fallback: 6)
        imageUpdateChecksEnabled = database.setting(Keys.imageUpdateChecksEnabled, fallback: true)
        appUpdateChecksEnabled = database.setting(Keys.appUpdateChecksEnabled, fallback: true)
        autoRestartEnabled = database.setting(Keys.autoRestartEnabled, fallback: true)
        notifyOnCrash = database.setting(Keys.notifyOnCrash, fallback: true)
        revealCLI = database.setting(Keys.revealCLI, fallback: true)
        historyRetentionDays = database.setting(Keys.historyRetention, fallback: 7)
        loggingLevel = AppLogLevel(rawValue: database.setting(Keys.loggingLevel, fallback: "")) ?? .important
        enabledLogDestinations = Self.decodeRawSet(AppLogDestination.self,
                                                   raw: database.setting(Keys.logDestinations,
                                                                         fallback: [AppLogDestination.activity.rawValue]),
                                                   fallback: [.activity])
        enabledLogCategories = Self.decodeRawSet(AppLogCategory.self,
                                                 raw: database.setting(Keys.logCategories,
                                                                       fallback: AppLogCategory.allCases.map(\.rawValue)),
                                                 fallback: Set(AppLogCategory.allCases))
        // Default to Nightly while the app is pre-1.0 — that's where the only builds ship, so a fresh
        // install actually receives updates. Users can switch to Beta/Stable in Settings → Updates.
        updateChannel = UpdateChannel(rawValue: database.setting(Keys.updateChannel, fallback: "")) ?? .nightly
        // Experimental features default off (opt-in).
        commandPaletteEnabled = database.setting(Keys.commandPaletteEnabled, fallback: false)
        hubSearchEnabled = database.setting(Keys.hubSearchEnabled, fallback: false)
        composeImportEnabled = database.setting(Keys.composeImportEnabled, fallback: false)
        imageBuildEnabled = database.setting(Keys.imageBuildEnabled, fallback: false)
        keyboardShortcutsEnabled = database.setting(Keys.keyboardShortcutsEnabled, fallback: false)
        experimentalToolbarUI = database.setting(Keys.experimentalToolbarUI, fallback: false)
        experimentalPanelNavigation = database.setting(Keys.experimentalPanelNavigation, fallback: false)
        sidebarNavigationEnabled = database.setting(Keys.sidebarNavigationEnabled, fallback: true)
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
                       runtimePathOverrides: backupRuntimePathOverrides,
                       refreshInterval: refreshInterval,
                       statsNormalizationMode: statsNormalizationMode,
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
        for (rawKind, path) in snapshot.runtimePathOverrides {
            setRuntimePathOverride(path, for: Core.Runtime.Kind(rawValue: rawKind))
        }
        refreshInterval = snapshot.refreshInterval
        statsNormalizationMode = snapshot.statsNormalizationMode
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

    private func persist<T: Codable>(_ value: T, for key: String) {
        database.setSetting(value, for: key)
    }

    func runtimePathOverride(for kind: Core.Runtime.Kind) -> String {
        runtimePathOverrides[kind] ?? ""
    }

    func setRuntimePathOverride(_ path: String, for kind: Core.Runtime.Kind) {
        guard runtimePathOverrides[kind] != path else { return }
        runtimePathOverrides[kind] = path
        database.setRuntimePathOverride(path, for: kind)
    }

    private var backupRuntimePathOverrides: [String: String] {
        Dictionary(uniqueKeysWithValues: runtimePathOverrides.map { ($0.key.rawValue, $0.value) })
    }

    private static func decodeRawSet<T: RawRepresentable & Hashable>(_ type: T.Type,
                                                                     raw: [String],
                                                                     fallback: Set<T>) -> Set<T> where T.RawValue == String {
        guard !raw.isEmpty else { return fallback }
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
        static let refresh = "refreshInterval"
        static let statsNormalizationMode = "statsNormalizationMode"
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
