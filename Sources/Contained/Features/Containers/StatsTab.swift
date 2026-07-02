import SwiftUI
import ContainedDesignSystem
import ContainedCore

/// Live resource stats for one container. Reads the deltas the `RefreshCoordinator` already polls
/// into `ContainersStore` (so there's no second polling loop), and renders a tile per metric.
struct StatsTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: ContainerSnapshot

    @State private var processes: String = ""

    private var metrics: ContainerMetricsState { app.containers.metricsState(for: snapshot.id) }
    private var delta: StatsDelta? { metrics.stats }
    private var history: [GraphMetric: SampleBuffer] { metrics.historyByMetric }
    private var normalization: StatsNormalizationContext { app.statsNormalizationContext }
    private var tint: Color {
        app.containerStyle(for: snapshot).color
    }

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: Tokens.Space.m)]

    var body: some View {
        Group {
            if snapshot.state != .running {
                ContentUnavailableView {
                    Label("Not running", systemImage: "chart.xyaxis.line")
                } description: { Text("Start the container to see live resource usage.") }
            } else if let delta {
                ContainerTabScaffold {
                    LazyVGrid(columns: columns, spacing: Tokens.Space.m) {
                        tile(.cpu, delta, "cpu")
                        memoryTile(delta)
                        tile(.netRx, delta, "arrow.down.circle")
                        tile(.netTx, delta, "arrow.up.circle")
                        tile(.diskRead, delta, "arrow.down.doc")
                        tile(.diskWrite, delta, "arrow.up.doc")
                        MetricTile(label: "Processes", value: "\(delta.numProcesses)", systemImage: "gearshape.2", tint: tint)
                    }
                    processList
                }
            } else {
                // Running but no sample yet (first tick pending).
                LazyVStack(spacing: Tokens.Space.m) {
                    ProgressView()
                    Text("Collecting stats…").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: snapshot.id) { await refreshVisibleProcesses() }
    }

    @ViewBuilder
    private var processList: some View {
        if !processes.isEmpty {
            ResourceCardInsetSection {
                Label("Processes", systemImage: "list.bullet.rectangle")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(processes)
                    .font(.system(.caption, design: .monospaced))
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

    private func tile(_ metric: GraphMetric, _ delta: StatsDelta, _ symbol: String) -> some View {
        MetricTile(label: metric.displayName,
                   value: metric.caption(from: delta, snapshot: snapshot, normalization: normalization),
                   systemImage: symbol,
                   tint: tint,
                   samples: history[metric]?.values,
                   sparklineScale: sparklineScale(for: metric))
    }

    private func memoryTile(_ delta: StatsDelta) -> some View {
        let memoryLimit = GraphMetric.memoryLimitBytes(for: delta,
                                                       snapshot: snapshot,
                                                       normalization: normalization)
        return MetricTile(label: "Memory \(Format.bytes(delta.memoryUsageBytes)) / \(Format.bytes(memoryLimit))",
                          value: GraphMetric.memory.caption(from: delta,
                                                            snapshot: snapshot,
                                                            normalization: normalization),
                          systemImage: "memorychip",
                          tint: tint,
                          samples: history[.memory]?.values,
                          sparklineScale: sparklineScale(for: .memory))
    }

    private func sparklineScale(for metric: GraphMetric) -> SparklineScale {
        switch metric {
        case .cpu, .memory: return .fraction
        case .netRx, .netTx, .diskRead, .diskWrite: return .normalized
        }
    }
}
