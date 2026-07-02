import Foundation
import OSLog

/// User-selectable logging scope. `minimal` keeps durable history useful without recording every
/// background tick; `verbose` also records routine refreshes and cache updates.
enum AppLogLevel: String, CaseIterable, Identifiable {
    case off
    case errors
    case important
    case verbose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return AppText.string("logging.level.off", defaultValue: "Off")
        case .errors: return AppText.string("logging.level.errors", defaultValue: "Errors")
        case .important: return AppText.string("logging.level.important", defaultValue: "Important")
        case .verbose: return AppText.string("logging.level.verbose", defaultValue: "Verbose")
        }
    }

    var footnote: String {
        switch self {
        case .off: return AppText.string("logging.level.off.footnote", defaultValue: "No app events are recorded.")
        case .errors: return AppText.string("logging.level.errors.footnote", defaultValue: "Only failures are recorded.")
        case .important:
            return AppText.string(
                "logging.level.important.footnote",
                defaultValue: "User actions, failures, and state changes are recorded."
            )
        case .verbose:
            return AppText.string(
                "logging.level.verbose.footnote",
                defaultValue: "Adds routine refreshes and background work."
            )
        }
    }

    func includes(_ severity: AppLogSeverity) -> Bool {
        switch self {
        case .off: return false
        case .errors: return severity == .error
        case .important: return severity != .debug
        case .verbose: return true
        }
    }
}

enum AppLogDestination: String, CaseIterable, Identifiable {
    case activity
    case console

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .activity: return AppText.string("logging.destination.activity", defaultValue: "Activity history")
        case .console: return AppText.string("logging.destination.console", defaultValue: "macOS Console")
        }
    }
}

enum AppLogCategory: String, CaseIterable, Identifiable {
    case lifecycle
    case image
    case compose
    case system
    case health
    case registry
    case ui

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lifecycle: return AppText.string("logging.category.lifecycle", defaultValue: "Containers")
        case .image: return AppText.string("logging.category.image", defaultValue: "Images")
        case .compose: return AppText.string("logging.category.compose", defaultValue: "Compose")
        case .system: return AppText.string("logging.category.system", defaultValue: "System")
        case .health: return AppText.string("logging.category.health", defaultValue: "Health")
        case .registry: return AppText.string("logging.category.registry", defaultValue: "Registries")
        case .ui: return AppText.string("logging.category.ui", defaultValue: "Interface")
        }
    }

    var eventKind: EventKind {
        switch self {
        case .lifecycle: return .lifecycle
        case .image: return .image
        case .compose: return .compose
        case .system: return .system
        case .health: return .healthcheck
        case .registry: return .registry
        case .ui: return .ui
        }
    }
}

enum AppLogSeverity: String {
    case debug
    case info
    case warning
    case error

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

@MainActor
final class AppLogger {
    private let settings: SettingsStore
    private let history: HistoryStore
    private let osLoggers: [AppLogCategory: Logger]

    init(settings: SettingsStore, history: HistoryStore) {
        self.settings = settings
        self.history = history
        var loggers: [AppLogCategory: Logger] = [:]
        for category in AppLogCategory.allCases {
            loggers[category] = Logger(subsystem: "app.contained.Contained", category: category.rawValue)
        }
        self.osLoggers = loggers
    }

    func record(_ message: String,
                category: AppLogCategory,
                severity: AppLogSeverity = .info,
                containerID: String? = nil) {
        guard settings.loggingLevel.includes(severity),
              settings.enabledLogCategories.contains(category) else { return }

        if settings.enabledLogDestinations.contains(.activity) {
            history.record(category.eventKind, containerID: containerID, message: message)
        }
        if settings.enabledLogDestinations.contains(.console),
           let logger = osLoggers[category] {
            logger.log(level: severity.osLogType, "\(message, privacy: .public)")
        }
    }

    func recordFailure(_ prefix: String,
                       error: Error,
                       category: AppLogCategory,
                       severity: AppLogSeverity = .error,
                       containerID: String? = nil) {
        record(AppErrorPresentation.activityMessage(prefix, error: error),
               category: category,
               severity: severity,
               containerID: containerID)
    }
}
