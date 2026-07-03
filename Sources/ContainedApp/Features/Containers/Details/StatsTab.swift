import SwiftUI
import ContainedUI
import ContainedCore

/// Live resource stats for one container. Reads the deltas the `RefreshCoordinator` already polls
/// into `ContainersStore` (so there's no second polling loop), and renders a tile per metric.
struct StatsTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: Core.Container.Snapshot

    @State private var processes: String = ""

    private var metrics: ContainerMetricsState { app.containers.metricsState(for: snapshot.id) }
    private var delta: Core.Metrics.StatsDelta? { metrics.stats }
    private var history: [Core.Metrics.GraphMetric: UI.Chart.SampleBuffer] { metrics.historyByMetric }
    private var normalization: Core.Metrics.NormalizationContext { app.statsNormalizationContext }
    private var tint: Color {
        app.containerStyle(for: snapshot).color
    }

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: UI.Layout.Spacing.m)]

    var body: some View {
        Group {
            if snapshot.state != .running {
                UI.State.Empty(AppText.string("stats.notRunning", defaultValue: "Not running"),
                                 systemImage: "chart.xyaxis.line",
                                 description: AppText.string("stats.notRunning.description", defaultValue: "Start the container to see live resource usage."))
            } else if let delta {
                ContainerTabScaffold {
                    LazyVGrid(columns: columns, spacing: UI.Layout.Spacing.m) {
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
                    }
                    processList
                }
            } else {
                UI.State.Loading(AppText.string("stats.collecting", defaultValue: "Collecting stats..."))
            }
        }
        .task(id: snapshot.id) { await refreshVisibleProcesses() }
    }

    @ViewBuilder
    private var processList: some View {
        if !processes.isEmpty {
            UI.Card.InsetSection {
                Label(AppText.string("stats.processes", defaultValue: "Processes"), systemImage: "list.bullet.rectangle")
                    .designSectionLabelStyle()
                Text(processes)
                    .designMonospacedCaption()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func loadProcesses() async {
        guard snapshot.state == .running, let client = app.client else { processes = ""; return }
        // `ps` is present in most images (busybox/coreutils); ignore failures (e.g. distroless).
        processes = (try? await client.execCapture(snapshot.id, ["ps"]))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func refreshVisibleProcesses() async {
        guard snapshot.state == .running else { processes = ""; return }
        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }
        await loadProcesses()
    }

    private func tile(_ metric: Core.Metrics.GraphMetric, _ delta: Core.Metrics.StatsDelta, _ symbol: String) -> some View {
        UI.Chart.MetricTile(label: metric.displayName,
                   value: metric.caption(from: delta, snapshot: snapshot, normalization: normalization),
                   systemImage: symbol,
                   tint: tint,
                   samples: history[metric]?.values,
                   sparklineScale: sparklineScale(for: metric))
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
    }

    private func sparklineScale(for metric: Core.Metrics.GraphMetric) -> UI.Chart.Scale {
        switch metric {
        case .cpu, .memory: return .fraction
        case .netRx, .netTx, .diskRead, .diskWrite: return .normalized
        }
    }
}
