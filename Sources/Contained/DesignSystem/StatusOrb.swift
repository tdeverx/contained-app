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
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .stopping: return "Stopping"
        case .unknown: return "Unknown"
        case .errored: return "Errored"
        }
    }

    var isPulsing: Bool { self == .stopping }
}

/// A small color-coded status dot with a soft glow; pulses while transitioning.
struct StatusOrb: View {
    let presentation: StatusPresentation
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(presentation.color)
            .frame(width: size, height: size)
            .overlay {
                if presentation.isPulsing {
                    Circle()
                        .stroke(presentation.color.opacity(0.30), lineWidth: size * 0.45)
                        .frame(width: size * 1.85, height: size * 1.85)
                        .opacity(0.8)
                }
            }
            .accessibilityLabel(presentation.label)
    }
}
