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
        case .off: return "Off"
        case .errors: return "Errors"
        case .important: return "Important"
        case .verbose: return "Verbose"
        }
    }

    var footnote: String {
        switch self {
        case .off: return "No app events are recorded."
        case .errors: return "Only failures are recorded."
        case .important: return "User actions, failures, and state changes are recorded."
        case .verbose: return "Adds routine refreshes and background work."
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
        case .activity: return "Activity history"
        case .console: return "macOS Console"
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
        case .lifecycle: return "Containers"
        case .image: return "Images"
        case .compose: return "Compose"
        case .system: return "System"
        case .health: return "Health"
        case .registry: return "Registries"
        case .ui: return "Interface"
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
}
