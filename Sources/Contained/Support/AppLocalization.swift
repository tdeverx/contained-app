import Foundation
import ContainedCore
import ContainedDesignSystem

/// App-owned user-facing copy. Packages receive resolved strings from here; they do not own
/// localized resources or English defaults.
enum AppText {
    static func string(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: .main)
    }

    static var back: String { string("common.back", defaultValue: "Back") }
    static var cancel: String { string("common.cancel", defaultValue: "Cancel") }
    static var clearSearch: String { string("common.clearSearch", defaultValue: "Clear search") }
    static var close: String { string("common.close", defaultValue: "Close") }
    static var add: String { string("common.add", defaultValue: "Add") }
    static var copied: String { string("common.copied", defaultValue: "Copied") }
    static var copyCommand: String { string("common.copyCommand", defaultValue: "Copy command") }
    static var copyLog: String { string("common.copyLog", defaultValue: "Copy log") }
    static var copyAll: String { string("common.copyAll", defaultValue: "Copy all") }
    static var copyReference: String { string("common.copyReference", defaultValue: "Copy reference") }
    static var clear: String { string("common.clear", defaultValue: "Clear") }
    static var delete: String { string("common.delete", defaultValue: "Delete") }
    static var edit: String { string("common.edit", defaultValue: "Edit") }
    static var refresh: String { string("common.refresh", defaultValue: "Refresh") }
    static var completed: String { string("common.completed", defaultValue: "Completed") }
    static var direction: String { string("common.direction", defaultValue: "Direction") }
    static var done: String { string("common.done", defaultValue: "Done") }
    static var follow: String { string("common.follow", defaultValue: "Follow") }
    static var logIn: String { string("common.logIn", defaultValue: "Log in") }
    static var parent: String { string("common.parent", defaultValue: "Parent") }
    static var reconnect: String { string("common.reconnect", defaultValue: "Reconnect") }
    static var quit: String { string("common.quit", defaultValue: "Quit") }
    static var run: String { string("common.run", defaultValue: "Run") }
    static var save: String { string("common.save", defaultValue: "Save") }
    static var start: String { string("common.start", defaultValue: "Start") }
    static var stop: String { string("common.stop", defaultValue: "Stop") }
    static var restart: String { string("common.restart", defaultValue: "Restart") }
    static var working: String { string("common.working", defaultValue: "Working...") }

    static var addBuildArgument: String { string("build.addBuildArgument", defaultValue: "Add build argument") }
    static var buildImage: String { string("build.buildImage", defaultValue: "Build image") }
    static var cancelBuild: String { string("build.cancelBuild", defaultValue: "Cancel build") }
    static var chooseContextFolder: String { string("build.chooseContextFolder", defaultValue: "Choose context folder") }
    static var removeBuildArgument: String { string("build.removeBuildArgument", defaultValue: "Remove build argument") }
    static var cardColor: String { string("customize.cardColor", defaultValue: "Card Color") }
    static var current: String { string("common.current", defaultValue: "Current") }
    static var deleteTag: String { string("image.deleteTag", defaultValue: "Delete tag") }
    static var loadImageTar: String { string("image.loadImageTar", defaultValue: "Load Image Tar") }
    static var prune: String { string("image.prune", defaultValue: "Prune") }
    static var pruneImages: String { string("image.pruneImages", defaultValue: "Prune Images") }
    static var pullUpdate: String { string("image.pullUpdate", defaultValue: "Pull Update") }
    static var checkForUpdates: String { string("updates.checkForUpdates", defaultValue: "Check for Updates") }
    static var checkForUpdatesNow: String { string("updates.checkForUpdatesNow", defaultValue: "Check for app updates now") }
    static var runImageUpdateCheckNow: String {
        string("updates.runImageUpdateCheckNow", defaultValue: "Run image update check now")
    }
    static var addTag: String { string("image.addTag", defaultValue: "Add Tag") }
    static var push: String { string("image.push", defaultValue: "Push") }
    static var saveAsTemplate: String { string("template.saveAsTemplate", defaultValue: "Save as template") }
    static var newNetwork: String { string("network.newNetwork", defaultValue: "New Network") }
    static var newVolume: String { string("volume.newVolume", defaultValue: "New Volume") }
    static var refreshNetworks: String { string("network.refreshNetworks", defaultValue: "Refresh Networks") }
    static var refreshVolumes: String { string("volume.refreshVolumes", defaultValue: "Refresh Volumes") }
    static var systemLogs: String { string("system.systemLogs", defaultValue: "System Logs") }
    static var storageCleanup: String { string("system.storageCleanup", defaultValue: "Storage cleanup") }
    static var markAllRead: String { string("activity.markAllRead", defaultValue: "Mark all read") }
    static var clearActivity: String { string("activity.clearActivity", defaultValue: "Clear activity") }
    static var tint: String { string("common.tint", defaultValue: "Tint") }
    static var unread: String { string("common.unread", defaultValue: "Unread") }

    static var reconnectTerminal: String {
        string("terminal.reconnectTerminal", defaultValue: "Reconnect terminal")
    }

    static var startService: String { string("service.start", defaultValue: "Start service") }
    static var stopService: String { string("service.stop", defaultValue: "Stop service") }
    static var restartService: String { string("service.restart", defaultValue: "Restart service") }

    static func lineCount(_ count: Int) -> String {
        string("streamConsole.lineCount", defaultValue: "\(count) lines")
    }

    static func selectedCount(_ count: Int) -> String {
        string("selection.count", defaultValue: "\(count) selected")
    }

    static func customizeAccessibilityLabel(_ name: String) -> String {
        string("customize.accessibilityLabel", defaultValue: "Customize \(name)")
    }

    static func customizeImageStyleAccessibility(_ name: String) -> String {
        string("customize.imageStyleAccessibilityLabel", defaultValue: "Customize \(name) image style")
    }

    static func containerCardAccessibility(name: String, status: String) -> String {
        string("containerCard.accessibilityLabel", defaultValue: "\(name), \(status)")
    }

    static func removeScopeAccessibility(_ scope: String) -> String {
        string("palette.removeScopeAccessibilityLabel", defaultValue: "Remove \(scope) scope")
    }

    static func setAppTintTitle(_ tintName: String) -> String {
        string("palette.setAppTint", defaultValue: "Set app tint to \(tintName)")
    }
}

extension AppTint {
    var localizedDisplayName: String {
        switch self {
        case .multicolor: return AppText.string("tint.multicolor", defaultValue: "App Accent")
        case .graphite: return AppText.string("tint.graphite", defaultValue: "Graphite")
        case .azure: return AppText.string("tint.azure", defaultValue: "Azure")
        case .teal: return AppText.string("tint.teal", defaultValue: "Teal")
        case .coral: return AppText.string("tint.coral", defaultValue: "Coral")
        case .indigo: return AppText.string("tint.indigo", defaultValue: "Indigo")
        case .green: return AppText.string("tint.green", defaultValue: "Green")
        case .amber: return AppText.string("tint.amber", defaultValue: "Amber")
        case .pink: return AppText.string("tint.pink", defaultValue: "Pink")
        }
    }

    var localizedSearchAliases: [String] {
        switch self {
        case .multicolor:
            return [
                AppText.string("tint.multicolor.alias.default", defaultValue: "default"),
                AppText.string("tint.multicolor.alias.appAccent", defaultValue: "app accent"),
                AppText.string("tint.multicolor.alias.system", defaultValue: "system"),
                AppText.string("tint.multicolor.alias.auto", defaultValue: "auto"),
                AppText.string("tint.multicolor.alias.rainbow", defaultValue: "rainbow"),
            ]
        case .graphite:
            return [
                AppText.string("tint.graphite.alias.gray", defaultValue: "gray"),
                AppText.string("tint.graphite.alias.grey", defaultValue: "grey"),
                AppText.string("tint.graphite.alias.slate", defaultValue: "slate"),
                AppText.string("tint.graphite.alias.charcoal", defaultValue: "charcoal"),
                AppText.string("tint.graphite.alias.silver", defaultValue: "silver"),
                AppText.string("tint.graphite.alias.neutral", defaultValue: "neutral"),
                AppText.string("tint.graphite.alias.mono", defaultValue: "mono"),
            ]
        case .azure:
            return [
                AppText.string("tint.azure.alias.blue", defaultValue: "blue"),
                AppText.string("tint.azure.alias.sky", defaultValue: "sky"),
                AppText.string("tint.azure.alias.ocean", defaultValue: "ocean"),
                AppText.string("tint.azure.alias.cobalt", defaultValue: "cobalt"),
            ]
        case .teal:
            return [
                AppText.string("tint.teal.alias.cyan", defaultValue: "cyan"),
                AppText.string("tint.teal.alias.aqua", defaultValue: "aqua"),
                AppText.string("tint.teal.alias.turquoise", defaultValue: "turquoise"),
                AppText.string("tint.teal.alias.mint", defaultValue: "mint"),
                AppText.string("tint.teal.alias.seafoam", defaultValue: "seafoam"),
            ]
        case .coral:
            return [
                AppText.string("tint.coral.alias.orange", defaultValue: "orange"),
                AppText.string("tint.coral.alias.salmon", defaultValue: "salmon"),
                AppText.string("tint.coral.alias.burnt", defaultValue: "burnt"),
                AppText.string("tint.coral.alias.terracotta", defaultValue: "terracotta"),
                AppText.string("tint.coral.alias.rust", defaultValue: "rust"),
            ]
        case .indigo:
            return [
                AppText.string("tint.indigo.alias.purple", defaultValue: "purple"),
                AppText.string("tint.indigo.alias.violet", defaultValue: "violet"),
                AppText.string("tint.indigo.alias.blurple", defaultValue: "blurple"),
                AppText.string("tint.indigo.alias.royal", defaultValue: "royal"),
            ]
        case .green:
            return [
                AppText.string("tint.green.alias.lime", defaultValue: "lime"),
                AppText.string("tint.green.alias.olive", defaultValue: "olive"),
                AppText.string("tint.green.alias.emerald", defaultValue: "emerald"),
                AppText.string("tint.green.alias.forest", defaultValue: "forest"),
                AppText.string("tint.green.alias.moss", defaultValue: "moss"),
            ]
        case .amber:
            return [
                AppText.string("tint.amber.alias.yellow", defaultValue: "yellow"),
                AppText.string("tint.amber.alias.gold", defaultValue: "gold"),
                AppText.string("tint.amber.alias.honey", defaultValue: "honey"),
                AppText.string("tint.amber.alias.mustard", defaultValue: "mustard"),
            ]
        case .pink:
            return [
                AppText.string("tint.pink.alias.magenta", defaultValue: "magenta"),
                AppText.string("tint.pink.alias.rose", defaultValue: "rose"),
                AppText.string("tint.pink.alias.fuchsia", defaultValue: "fuchsia"),
                AppText.string("tint.pink.alias.crimson", defaultValue: "crimson"),
                AppText.string("tint.pink.alias.hotPink", defaultValue: "hot pink"),
            ]
        }
    }
}

extension AppearanceMode {
    var localizedDisplayName: String {
        switch self {
        case .system: return AppText.string("appearance.system", defaultValue: "System")
        case .light: return AppText.string("appearance.light", defaultValue: "Light")
        case .dark: return AppText.string("appearance.dark", defaultValue: "Dark")
        }
    }
}

extension CardDensity {
    var localizedDisplayName: String {
        switch self {
        case .small: return AppText.string("cardDensity.small", defaultValue: "Small")
        case .medium: return AppText.string("cardDensity.medium", defaultValue: "Medium")
        case .large: return AppText.string("cardDensity.large", defaultValue: "Large")
        }
    }
}

extension ColorLayerBlendMode {
    var localizedDisplayName: String {
        switch self {
        case .normal: return AppText.string("blendMode.normal", defaultValue: "Normal")
        case .softLight: return AppText.string("blendMode.softLight", defaultValue: "Soft Light")
        case .overlay: return AppText.string("blendMode.overlay", defaultValue: "Overlay")
        case .multiply: return AppText.string("blendMode.multiply", defaultValue: "Multiply")
        case .screen: return AppText.string("blendMode.screen", defaultValue: "Screen")
        }
    }
}

extension WindowMaterial {
    var localizedDisplayName: String {
        switch self {
        case .glassClear: return AppText.string("windowMaterial.glassClear", defaultValue: "Glass (Clear)")
        case .glassRegular: return AppText.string("windowMaterial.glassRegular", defaultValue: "Glass (Regular)")
        case .fullScreenUI: return AppText.string("windowMaterial.fullScreenUI", defaultValue: "Full-screen UI (default)")
        case .underWindowBackground: return AppText.string("windowMaterial.underWindowBackground", defaultValue: "Under Window")
        case .underPageBackground: return AppText.string("windowMaterial.underPageBackground", defaultValue: "Under Page")
        case .windowBackground: return AppText.string("windowMaterial.windowBackground", defaultValue: "Window")
        case .contentBackground: return AppText.string("windowMaterial.contentBackground", defaultValue: "Content")
        case .sidebar: return AppText.string("windowMaterial.sidebar", defaultValue: "Sidebar")
        case .headerView: return AppText.string("windowMaterial.headerView", defaultValue: "Header")
        case .titlebar: return AppText.string("windowMaterial.titlebar", defaultValue: "Titlebar")
        case .sheet: return AppText.string("windowMaterial.sheet", defaultValue: "Sheet")
        case .popover: return AppText.string("windowMaterial.popover", defaultValue: "Popover")
        case .menu: return AppText.string("windowMaterial.menu", defaultValue: "Menu")
        case .selection: return AppText.string("windowMaterial.selection", defaultValue: "Selection")
        case .hudWindow: return AppText.string("windowMaterial.hudWindow", defaultValue: "HUD")
        case .toolTip: return AppText.string("windowMaterial.toolTip", defaultValue: "Tooltip")
        }
    }
}

extension GraphStyle {
    var localizedDisplayName: String {
        switch self {
        case .area: return AppText.string("graphStyle.area", defaultValue: "Area")
        case .line: return AppText.string("graphStyle.line", defaultValue: "Line")
        case .bar: return AppText.string("graphStyle.bar", defaultValue: "Bar")
        case .points: return AppText.string("graphStyle.points", defaultValue: "Points")
        case .multiLine: return AppText.string("graphStyle.multiLine", defaultValue: "Multi-Line")
        case .range: return AppText.string("graphStyle.range", defaultValue: "Range")
        case .scatter: return AppText.string("graphStyle.scatter", defaultValue: "Scatter")
        }
    }
}

extension WidgetInterpolation {
    var localizedDisplayName: String {
        switch self {
        case .linear: return AppText.string("widgetInterpolation.linear", defaultValue: "Linear")
        case .catmullRom: return AppText.string("widgetInterpolation.catmullRom", defaultValue: "Smooth")
        case .cardinal: return AppText.string("widgetInterpolation.cardinal", defaultValue: "Cardinal")
        case .monotone: return AppText.string("widgetInterpolation.monotone", defaultValue: "Monotone")
        case .stepStart: return AppText.string("widgetInterpolation.stepStart", defaultValue: "Step Start")
        case .stepCenter: return AppText.string("widgetInterpolation.stepCenter", defaultValue: "Step Center")
        case .stepEnd: return AppText.string("widgetInterpolation.stepEnd", defaultValue: "Step End")
        }
    }
}

extension RestartPolicy {
    var localizedDisplayName: String {
        switch self {
        case .no: return AppText.string("restartPolicy.no", defaultValue: "No")
        case .onFailure: return AppText.string("restartPolicy.onFailure", defaultValue: "On failure")
        case .always: return AppText.string("restartPolicy.always", defaultValue: "Always")
        }
    }
}
