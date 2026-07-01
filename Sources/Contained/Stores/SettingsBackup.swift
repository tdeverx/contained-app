import Foundation

/// Portable snapshot of user preferences for config export/import.
struct SettingsBackup: Codable, Equatable {
    var accentTint: AppTint
    var appearance: AppearanceMode
    var density: CardDensity
    var windowMaterial: WindowMaterial
    var modalMaterial: WindowMaterial
    var buttonMaterial: WindowMaterial
    var buttonTintEnabled: Bool
    var buttonTint: AppTint
    var buttonTintOpacity: Double
    var buttonTintGradient: Bool
    var buttonTintGradientAngle: Double
    var buttonTintBlendMode: ColorLayerBlendMode
    var cardMaterial: WindowMaterial
    var showInfoTips: Bool
    var imageDefaultStyleEnabled: Bool
    var keepInMenuBar: Bool
    var cliPathOverride: String
    var refreshInterval: Double
    var imageUpdateIntervalHours: Int
    var imageUpdateChecksEnabled: Bool
    var appUpdateChecksEnabled: Bool
    var autoRestartEnabled: Bool
    var notifyOnCrash: Bool
    var revealCLI: Bool
    var historyRetentionDays: Int
    var loggingLevel: AppLogLevel
    var enabledLogDestinations: Set<AppLogDestination>
    var enabledLogCategories: Set<AppLogCategory>
    var updateChannel: UpdateChannel
    var commandPaletteEnabled: Bool
    var hubSearchEnabled: Bool
    var composeImportEnabled: Bool
    var imageBuildEnabled: Bool
    var keyboardShortcutsEnabled: Bool
    var experimentalToolbarUI: Bool
    var experimentalPanelNavigation: Bool
    var sidebarNavigationEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case accentTint, appearance, density, windowMaterial, modalMaterial, buttonMaterial
        case buttonTintEnabled, buttonTint, buttonTintOpacity, buttonTintGradient, buttonTintGradientAngle
        case buttonTintBlendMode
        case cardMaterial
        case showInfoTips, imageDefaultStyleEnabled, keepInMenuBar, cliPathOverride, refreshInterval
        case imageUpdateIntervalHours, imageUpdateChecksEnabled, appUpdateChecksEnabled, autoRestartEnabled
        case notifyOnCrash, revealCLI, historyRetentionDays, loggingLevel, enabledLogDestinations
        case enabledLogCategories, updateChannel, commandPaletteEnabled, hubSearchEnabled
        case composeImportEnabled, imageBuildEnabled, keyboardShortcutsEnabled, experimentalToolbarUI
        case experimentalPanelNavigation, sidebarNavigationEnabled
    }

    init(accentTint: AppTint,
         appearance: AppearanceMode,
         density: CardDensity,
         windowMaterial: WindowMaterial,
         modalMaterial: WindowMaterial,
         buttonMaterial: WindowMaterial,
         buttonTintEnabled: Bool = false,
         buttonTint: AppTint = .multicolor,
         buttonTintOpacity: Double = 0.18,
         buttonTintGradient: Bool = true,
         buttonTintGradientAngle: Double = Personalization.defaultGradientAngle,
         buttonTintBlendMode: ColorLayerBlendMode = .softLight,
         cardMaterial: WindowMaterial,
         showInfoTips: Bool,
         imageDefaultStyleEnabled: Bool,
         keepInMenuBar: Bool,
         cliPathOverride: String,
         refreshInterval: Double,
         imageUpdateIntervalHours: Int,
         imageUpdateChecksEnabled: Bool,
         appUpdateChecksEnabled: Bool,
         autoRestartEnabled: Bool,
         notifyOnCrash: Bool,
         revealCLI: Bool,
         historyRetentionDays: Int,
         loggingLevel: AppLogLevel,
         enabledLogDestinations: Set<AppLogDestination>,
         enabledLogCategories: Set<AppLogCategory>,
         updateChannel: UpdateChannel,
         commandPaletteEnabled: Bool,
         hubSearchEnabled: Bool,
         composeImportEnabled: Bool,
         imageBuildEnabled: Bool,
         keyboardShortcutsEnabled: Bool = false,
         experimentalToolbarUI: Bool,
         experimentalPanelNavigation: Bool = false,
         sidebarNavigationEnabled: Bool = true) {
        self.accentTint = accentTint
        self.appearance = appearance
        self.density = density
        self.windowMaterial = windowMaterial
        self.modalMaterial = modalMaterial
        self.buttonMaterial = buttonMaterial
        self.buttonTintEnabled = buttonTintEnabled
        self.buttonTint = buttonTint
        self.buttonTintOpacity = buttonTintOpacity
        self.buttonTintGradient = buttonTintGradient
        self.buttonTintGradientAngle = buttonTintGradientAngle
        self.buttonTintBlendMode = buttonTintBlendMode
        self.cardMaterial = cardMaterial
        self.showInfoTips = showInfoTips
        self.imageDefaultStyleEnabled = imageDefaultStyleEnabled
        self.keepInMenuBar = keepInMenuBar
        self.cliPathOverride = cliPathOverride
        self.refreshInterval = refreshInterval
        self.imageUpdateIntervalHours = imageUpdateIntervalHours
        self.imageUpdateChecksEnabled = imageUpdateChecksEnabled
        self.appUpdateChecksEnabled = appUpdateChecksEnabled
        self.autoRestartEnabled = autoRestartEnabled
        self.notifyOnCrash = notifyOnCrash
        self.revealCLI = revealCLI
        self.historyRetentionDays = historyRetentionDays
        self.loggingLevel = loggingLevel
        self.enabledLogDestinations = enabledLogDestinations
        self.enabledLogCategories = enabledLogCategories
        self.updateChannel = updateChannel
        self.commandPaletteEnabled = commandPaletteEnabled
        self.hubSearchEnabled = hubSearchEnabled
        self.composeImportEnabled = composeImportEnabled
        self.imageBuildEnabled = imageBuildEnabled
        self.keyboardShortcutsEnabled = keyboardShortcutsEnabled
        self.experimentalToolbarUI = experimentalToolbarUI
        self.experimentalPanelNavigation = experimentalPanelNavigation
        self.sidebarNavigationEnabled = sidebarNavigationEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accentTint = try container.decode(AppTint.self, forKey: .accentTint)
        appearance = try container.decode(AppearanceMode.self, forKey: .appearance)
        density = try container.decode(CardDensity.self, forKey: .density)
        windowMaterial = try container.decode(WindowMaterial.self, forKey: .windowMaterial)
        modalMaterial = try container.decode(WindowMaterial.self, forKey: .modalMaterial)
        buttonMaterial = try container.decodeIfPresent(WindowMaterial.self, forKey: .buttonMaterial) ?? .glassClear
        buttonTintEnabled = try container.decodeIfPresent(Bool.self, forKey: .buttonTintEnabled) ?? false
        buttonTint = try container.decodeIfPresent(AppTint.self, forKey: .buttonTint) ?? .multicolor
        buttonTintOpacity = try container.decodeIfPresent(Double.self, forKey: .buttonTintOpacity) ?? 0.18
        buttonTintGradient = try container.decodeIfPresent(Bool.self, forKey: .buttonTintGradient) ?? true
        buttonTintGradientAngle = try container.decodeIfPresent(Double.self, forKey: .buttonTintGradientAngle)
            ?? Personalization.defaultGradientAngle
        buttonTintBlendMode = try container.decodeIfPresent(ColorLayerBlendMode.self, forKey: .buttonTintBlendMode)
            ?? .softLight
        cardMaterial = try container.decodeIfPresent(WindowMaterial.self, forKey: .cardMaterial) ?? .glassRegular
        showInfoTips = try container.decodeIfPresent(Bool.self, forKey: .showInfoTips) ?? true
        imageDefaultStyleEnabled = try container.decodeIfPresent(Bool.self, forKey: .imageDefaultStyleEnabled) ?? true
        keepInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .keepInMenuBar) ?? true
        cliPathOverride = try container.decodeIfPresent(String.self, forKey: .cliPathOverride) ?? ""
        refreshInterval = try container.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? 2
        imageUpdateIntervalHours = try container.decodeIfPresent(Int.self, forKey: .imageUpdateIntervalHours) ?? 6
        imageUpdateChecksEnabled = try container.decodeIfPresent(Bool.self, forKey: .imageUpdateChecksEnabled) ?? true
        appUpdateChecksEnabled = try container.decodeIfPresent(Bool.self, forKey: .appUpdateChecksEnabled) ?? true
        autoRestartEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoRestartEnabled) ?? true
        notifyOnCrash = try container.decodeIfPresent(Bool.self, forKey: .notifyOnCrash) ?? true
        revealCLI = try container.decodeIfPresent(Bool.self, forKey: .revealCLI) ?? true
        historyRetentionDays = try container.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? 7
        loggingLevel = AppLogLevel(rawValue: try container.decodeIfPresent(String.self, forKey: .loggingLevel) ?? "")
            ?? .important
        enabledLogDestinations = Set((try container.decodeIfPresent([String].self, forKey: .enabledLogDestinations) ?? [AppLogDestination.activity.rawValue])
            .compactMap(AppLogDestination.init(rawValue:)))
        enabledLogCategories = Set((try container.decodeIfPresent([String].self, forKey: .enabledLogCategories) ?? AppLogCategory.allCases.map(\.rawValue))
            .compactMap(AppLogCategory.init(rawValue:)))
        updateChannel = try container.decodeIfPresent(UpdateChannel.self, forKey: .updateChannel) ?? .nightly
        commandPaletteEnabled = try container.decodeIfPresent(Bool.self, forKey: .commandPaletteEnabled) ?? false
        hubSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .hubSearchEnabled) ?? false
        composeImportEnabled = try container.decodeIfPresent(Bool.self, forKey: .composeImportEnabled) ?? false
        imageBuildEnabled = try container.decodeIfPresent(Bool.self, forKey: .imageBuildEnabled) ?? false
        keyboardShortcutsEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyboardShortcutsEnabled) ?? false
        experimentalToolbarUI = try container.decodeIfPresent(Bool.self, forKey: .experimentalToolbarUI) ?? false
        experimentalPanelNavigation = try container.decodeIfPresent(Bool.self, forKey: .experimentalPanelNavigation) ?? false
        sidebarNavigationEnabled = try container.decodeIfPresent(Bool.self, forKey: .sidebarNavigationEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accentTint, forKey: .accentTint)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(density, forKey: .density)
        try container.encode(windowMaterial, forKey: .windowMaterial)
        try container.encode(modalMaterial, forKey: .modalMaterial)
        try container.encode(buttonMaterial, forKey: .buttonMaterial)
        try container.encode(buttonTintEnabled, forKey: .buttonTintEnabled)
        try container.encode(buttonTint, forKey: .buttonTint)
        try container.encode(buttonTintOpacity, forKey: .buttonTintOpacity)
        try container.encode(buttonTintGradient, forKey: .buttonTintGradient)
        try container.encode(buttonTintGradientAngle, forKey: .buttonTintGradientAngle)
        try container.encode(buttonTintBlendMode, forKey: .buttonTintBlendMode)
        try container.encode(cardMaterial, forKey: .cardMaterial)
        try container.encode(showInfoTips, forKey: .showInfoTips)
        try container.encode(imageDefaultStyleEnabled, forKey: .imageDefaultStyleEnabled)
        try container.encode(keepInMenuBar, forKey: .keepInMenuBar)
        try container.encode(cliPathOverride, forKey: .cliPathOverride)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        try container.encode(imageUpdateIntervalHours, forKey: .imageUpdateIntervalHours)
        try container.encode(imageUpdateChecksEnabled, forKey: .imageUpdateChecksEnabled)
        try container.encode(appUpdateChecksEnabled, forKey: .appUpdateChecksEnabled)
        try container.encode(autoRestartEnabled, forKey: .autoRestartEnabled)
        try container.encode(notifyOnCrash, forKey: .notifyOnCrash)
        try container.encode(revealCLI, forKey: .revealCLI)
        try container.encode(historyRetentionDays, forKey: .historyRetentionDays)
        try container.encode(loggingLevel.rawValue, forKey: .loggingLevel)
        try container.encode(enabledLogDestinations.map(\.rawValue).sorted(), forKey: .enabledLogDestinations)
        try container.encode(enabledLogCategories.map(\.rawValue).sorted(), forKey: .enabledLogCategories)
        try container.encode(updateChannel, forKey: .updateChannel)
        try container.encode(commandPaletteEnabled, forKey: .commandPaletteEnabled)
        try container.encode(hubSearchEnabled, forKey: .hubSearchEnabled)
        try container.encode(composeImportEnabled, forKey: .composeImportEnabled)
        try container.encode(imageBuildEnabled, forKey: .imageBuildEnabled)
        try container.encode(keyboardShortcutsEnabled, forKey: .keyboardShortcutsEnabled)
        try container.encode(experimentalToolbarUI, forKey: .experimentalToolbarUI)
        try container.encode(experimentalPanelNavigation, forKey: .experimentalPanelNavigation)
        try container.encode(sidebarNavigationEnabled, forKey: .sidebarNavigationEnabled)
    }
}
