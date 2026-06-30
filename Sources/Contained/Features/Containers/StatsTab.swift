import SwiftUI
import ContainedCore

/// Live resource stats for one container. Reads the deltas the `RefreshCoordinator` already polls
/// into `ContainersStore` (so there's no second polling loop), and renders a tile per metric.
struct StatsTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: ContainerSnapshot

    @State private var processes: String = ""

    private var delta: StatsDelta? { app.containers.statsByID[snapshot.id] }
    private var history: [GraphMetric: SampleBuffer] { app.containers.historyByID[snapshot.id] ?? [:] }
    private var tint: Color {
        app.containerStyle(for: snapshot).color
    }

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: Tokens.Space.m)]

    var body: some View {
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
            .task(id: snapshot.id) { await loadProcesses() }
        } else {
            // Running but no sample yet (first tick pending).
            VStack(spacing: Tokens.Space.m) {
                ProgressView()
                Text("Collecting stats…").font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var processList: some View {
        if !processes.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Label("Processes", systemImage: "list.bullet.rectangle")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(processes)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Tokens.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: false)
        }
    }

    private func loadProcesses() async {
        guard snapshot.state == .running, let client = app.client else { processes = ""; return }
        // `ps` is present in most images (busybox/coreutils); ignore failures (e.g. distroless).
        processes = (try? await client.execCapture(snapshot.id, ["ps"]))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func tile(_ metric: GraphMetric, _ delta: StatsDelta, _ symbol: String) -> some View {
        MetricTile(label: metric.displayName, value: metric.caption(from: delta),
                   systemImage: symbol, tint: tint, samples: history[metric]?.values)
    }

    private func memoryTile(_ delta: StatsDelta) -> some View {
        MetricTile(label: "Memory \(Format.bytes(delta.memoryUsageBytes)) / \(Format.bytes(delta.memoryLimitBytes))",
                   value: Format.percent(delta.memoryFraction),
                   systemImage: "memorychip", tint: tint, samples: history[.memory]?.values)
    }
}
