import SwiftUI
import ContainedCore

/// Maps the real 4-case runtime state (plus a derived "errored") to a presentation.
enum StatusPresentation: Sendable, Equatable {
    case running, stopped, stopping, unknown, errored

    init(_ status: RuntimeStatus, errored: Bool = false) {
        if errored { self = .errored; return }
        switch status {
        case .running: self = .running
        case .stopped: self = .stopped
        case .stopping: self = .stopping
        case .unknown: self = .unknown
        }
    }

    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .secondary
        case .stopping: return .orange
        case .unknown: return .gray
        case .errored: return .red
        }
    }

    var label: String {
        switch self {
        case .running: return AppText.string("status.running", defaultValue: "Running")
        case .stopped: return AppText.string("status.stopped", defaultValue: "Stopped")
        case .stopping: return AppText.string("status.stopping", defaultValue: "Stopping")
        case .unknown: return AppText.string("status.unknown", defaultValue: "Unknown")
        case .errored: return AppText.string("status.errored", defaultValue: "Errored")
        }
    }

    var isPulsing: Bool { self == .stopping }
}
