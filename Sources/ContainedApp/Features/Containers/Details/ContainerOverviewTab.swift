import SwiftUI
import ContainedUI
import ContainedCore

/// Read-only container configuration with its current resource snapshot kept close at hand.
struct ContainerOverviewTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: Core.Container.Snapshot
    @State private var processes = ""

    private var config: Core.Container.Configuration { snapshot.configuration }
    private var metrics: ContainerMetricsState { app.containers.metricsState(for: snapshot.scopedID) }
    private var delta: Core.Metrics.StatsDelta? { metrics.stats }
    private var history: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer] { metrics.historyByMetric }
    private var normalization: Core.Metrics.NormalizationContext { app.statsNormalizationContext }
    private var tint: Color { app.containerStyle(for: snapshot).color }

    var body: some View {
        ContainerTabScaffold {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
                liveStatistics
                section("General") {
                    row("Image", snapshot.image)
                    row("Platform", config.platform.display)
                    if let exec = config.initProcess.executable {
                        row("Command", ([exec] + config.initProcess.arguments).joined(separator: " "))
                    }
                    row("Working dir", config.initProcess.workingDirectory ?? "—")
                }
                section("Resources") {
                    row("CPUs", "\(config.resources.cpus)")
                    row("Memory", Format.bytes(config.resources.memoryInBytes))
                }
                if !processes.isEmpty {
                    section(AppText.string("stats.processes", defaultValue: "Processes")) {
                        Text(processes)
                            .designMonospacedCaption()
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !config.publishedPorts.isEmpty {
                    section("Ports") {
                        ForEach(config.publishedPorts, id: \.containerPort) { port in
                            row(port.proto?.uppercased() ?? "TCP", "\(port.hostAddress ?? "0.0.0.0"):\(port.display)")
                        }
                    }
                }
                if !config.mounts.isEmpty {
                    section("Mounts") {
                        ForEach(config.mounts, id: \.effectiveDestination) { mount in
                            row(mount.effectiveDestination ?? "—", "\(mount.source ?? "—") (\(mount.type ?? "?"))")
                        }
                    }
                }
                if !config.initProcess.environment.isEmpty {
                    section("Environment") {
                        ForEach(config.initProcess.environment, id: \.self) { env in
                            Text(env)
                                .designMonospacedCaption()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                        }
                    }
                }
                if !config.labels.isEmpty {
                    section("Labels") {
                        ForEach(config.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            row(key, value)
                        }
                    }
                }
            }
        }
        .task(id: snapshot.scopedID) { await refreshVisibleProcesses() }
    }

    @ViewBuilder private var liveStatistics: some View {
        VStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
            Text(AppText.string("stats.live", defaultValue: "Live statistics"))
                .designHeadlineLabelStyle()
                .padding(.leading, UI.Layout.Spacing.xs)
            if snapshot.state != .running {
                UI.State.Empty(AppText.string("stats.notRunning", defaultValue: "Not running"),
                               systemImage: "chart.xyaxis.line",
                               description: AppText.string("stats.notRunning.description", defaultValue: "Start the container to see live resource usage."))
            } else if let delta {
                UI.Surface.HorizontalScrollLane {
                    tile(.cpu, delta, "cpu")
                    memoryTile(delta)
                    tile(.netRx, delta, "arrow.down.circle")
                    tile(.netTx, delta, "arrow.up.circle")
                    tile(.diskRead, delta, "arrow.down.doc")
                    tile(.diskWrite, delta, "arrow.up.doc")
                    UI.Chart.MetricTile(label: AppText.string("stats.processes", defaultValue: "Processes"),
                                        value: "\(delta.numProcesses)",
                                        systemImage: "gearshape.2",
                                        tint: tint)
                        .frame(width: UI.Chart.Size.metricTileWidth)
                }
            } else {
                UI.State.Loading(AppText.string("stats.collecting", defaultValue: "Collecting stats..."))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: @escaping () -> Content) -> some View {
        UI.Panel.Section(header: title) { content() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        UI.List.KeyValueRow(label: label, value: value, selectsValue: true)
    }

    private func tile(_ metric: Core.Metrics.GraphMetric,
                      _ delta: Core.Metrics.StatsDelta,
                      _ symbol: String) -> some View {
        UI.Chart.MetricTile(label: metric.displayName,
                            value: metric.caption(from: delta, snapshot: snapshot, normalization: normalization),
                            systemImage: symbol,
                            tint: tint,
                            samples: history[metric]?.values,
                            sparklineScale: sparklineScale(for: metric))
            .frame(width: UI.Chart.Size.metricTileWidth)
    }

    private func memoryTile(_ delta: Core.Metrics.StatsDelta) -> some View {
        let memoryLimit = Core.Metrics.GraphMetric.memoryLimitBytes(for: delta,
                                                                   snapshot: snapshot,
                                                                   normalization: normalization)
        return UI.Chart.MetricTile(label: AppText.string("stats.memory.detail", defaultValue: "Memory \(Format.bytes(delta.memoryUsageBytes)) / \(Format.bytes(memoryLimit))"),
                                   value: Core.Metrics.GraphMetric.memory.caption(from: delta,
                                                                                  snapshot: snapshot,
                                                                                  normalization: normalization),
                                   systemImage: "memorychip",
                                   tint: tint,
                                   samples: history[.memory]?.values,
                                   sparklineScale: sparklineScale(for: .memory))
            .frame(width: UI.Chart.Size.metricTileWidth)
    }

    private func sparklineScale(for metric: Core.Metrics.GraphMetric) -> UI.Chart.Scale {
        switch metric {
        case .cpu, .memory: return .fraction
        case .netRx, .netTx, .diskRead, .diskWrite: return .normalized
        }
    }

    private func refreshVisibleProcesses() async {
        guard snapshot.state == .running, let client = app.client else {
            processes = ""
            return
        }
        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }
        processes = (try? await client.execCapture(snapshot.id, ["ps"], runtimeKind: snapshot.runtimeKind))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
