import SwiftUI
import ContainedCore
import ContainedUI

/// Menu-bar density for the runtime summary used by the full System panel.
struct MenuBarRuntimeCard: View {
    @Environment(AppModel.self) private var app

    let descriptor: Core.Runtime.Descriptor
    let openSystem: () -> Void

    @State private var working = false

    private var readiness: Core.RuntimeReadiness.State? {
        app.runtimeReadiness[descriptor.kind]?.state
    }

    private var snapshots: [Core.Container.Snapshot] {
        app.containers.snapshots.filter { $0.runtimeKind == descriptor.kind }
    }

    private var runningCount: Int {
        snapshots.filter { $0.state == .running }.count
    }

    private var stoppedCount: Int {
        snapshots.count - runningCount
    }

    private var imageCount: Int {
        app.images.filter { $0.runtimeKind == descriptor.kind }.count
    }

    var body: some View {
        UI.Surface.Content(alignment: .leading, padding: UI.Card.Padding.content) {
            VStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
                header
                metrics
            }
        }
    }

    private var header: some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            UI.Badge.Dot(color: statusTint, size: UI.Control.Size.serviceDot)

            VStack(alignment: .leading, spacing: UI.Layout.Spacing.xxs) {
                HStack(spacing: UI.Layout.Spacing.xs) {
                    Text(descriptor.displayName)
                        .designHeadlineLabelStyle()
                    UI.Badge.Status(text: statusLabel, tint: statusTint)
                }
                Text(runtimeDetail)
                    .designSecondaryMonospacedCaption()
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            controls
        }
    }

    private var metrics: some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            UI.Control.MetricTile(label: "Running", value: "\(runningCount)")
            UI.Control.MetricTile(label: "Stopped", value: "\(stoppedCount)")
            UI.Control.MetricTile(label: "Images", value: "\(imageCount)")
        }
    }

    private var controls: some View {
        UI.Action.Group(controlActions)
    }

    private var controlActions: [UI.Action.Item] {
        var actions: [UI.Action.Item] = []

        if descriptor.supports(.serviceControl) {
            actions.append(powerAction)
            actions.append(UI.Action.Item(systemName: "arrow.clockwise",
                                          help: AppText.restartService,
                                          isEnabled: !working) {
                run { await app.restartService(runtimeKind: descriptor.kind) }
            })
        } else if readiness != .ready {
            actions.append(UI.Action.Item(systemName: "arrow.clockwise",
                                          help: AppText.string("common.retry", defaultValue: "Retry"),
                                          isEnabled: !working) {
                run { await app.retryBootstrap() }
            })
        }

        actions.append(UI.Action.Item(systemName: "arrow.up.forward.app",
                                      help: "Open System",
                                      isEnabled: !working,
                                      action: openSystem))
        return actions
    }

    private var powerAction: UI.Action.Item {
        if readiness == .ready {
            return UI.Action.Item(systemName: "stop.fill",
                                  help: AppText.stopService,
                                  role: .destructive,
                                  isEnabled: !working) {
                run { await app.stopService(runtimeKind: descriptor.kind) }
            }
        }

        return UI.Action.Item(systemName: "play.fill",
                              help: AppText.startService,
                              isEnabled: !working) {
            run { await app.startService(runtimeKind: descriptor.kind) }
        }
    }

    private var statusLabel: String {
        switch readiness {
        case .ready: "Running"
        case .endpointUnavailable: "Stopped"
        case .unsupported: "Unsupported"
        case .cliMissing: "Unavailable"
        case nil: "Checking"
        }
    }

    private var statusTint: Color {
        switch readiness {
        case .ready: .green
        case .endpointUnavailable: .orange
        case .unsupported: .red
        case .cliMissing, nil: .secondary
        }
    }

    private var runtimeDetail: String {
        let executable = descriptor.executableName ?? descriptor.kind.rawValue
        if let version = app.runtimeVersion(for: descriptor.kind) {
            return "\(executable) \(version)"
        }
        return executable
    }

    private func run(_ action: @escaping () async -> Void) {
        working = true
        Task {
            await action()
            working = false
        }
    }
}
