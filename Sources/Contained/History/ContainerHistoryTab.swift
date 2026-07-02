import SwiftUI
import ContainedDesignSystem
import SwiftData
import Charts
import ContainedCore

/// Selectable history windows for the timeline charts.
enum HistoryRange: String, CaseIterable, Identifiable {
    case hour = "1h"
    case day = "24h"
    case week = "7d"
    var id: String { rawValue }
    var seconds: TimeInterval {
        switch self {
        case .hour: return 3600
        case .day: return 86_400
        case .week: return 604_800
        }
    }
}

/// The "rewind" tab: persistent CPU / memory / network history for one container, plus its event
/// log — the long-term counterpart to the live sparklines. Backed by SwiftData via `@Query`.
struct ContainerHistoryTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: ContainerSnapshot
    @State private var range: HistoryRange = .day
    /// Window start, recomputed only when the range changes (not per render) so the windowed `@Query`
    /// inside `ContainerHistoryWindow` isn't rebuilt on every layout pass.
    @State private var cutoff = Date().addingTimeInterval(-HistoryRange.day.seconds)

    var body: some View {
        ContainerTabScaffold {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                Picker("Range", selection: $range) {
                    ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                ContainerHistoryWindow(snapshot: snapshot,
                                       cutoff: cutoff,
                                       normalization: app.statsNormalizationContext)
            }
        }
        .onChange(of: range) { _, newRange in cutoff = Date().addingTimeInterval(-newRange.seconds) }
    }
}

/// The charts + event list for one container, scoped to a time window. The window is pushed straight
/// into the SwiftData `@Query` predicates, so only the visible range is fetched — not the container's
/// entire retained history (which an unbounded query then re-filtered on every render).
private struct ContainerHistoryWindow: View {
    private let snapshot: ContainerSnapshot
    private let normalization: StatsNormalizationContext
    @Query private var samples: [MetricSample]
    @Query private var events: [EventRecord]

    init(snapshot: ContainerSnapshot, cutoff: Date, normalization: StatsNormalizationContext) {
        self.snapshot = snapshot
        self.normalization = normalization
        let containerID = snapshot.id
        _samples = Query(filter: #Predicate { $0.containerID == containerID && $0.timestamp >= cutoff },
                         sort: \MetricSample.timestamp)
        _events = Query(filter: #Predicate { $0.containerID == containerID && $0.timestamp >= cutoff },
                        sort: \EventRecord.timestamp, order: .reverse)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Tokens.Space.l) {
            if samples.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "chart.xyaxis.line",
                                       description: Text("Resource samples accumulate while the container runs."))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                chartCard("CPU", unit: percentUnit) {
                Chart(samples) { sample in
                    LineMark(x: .value("Time", sample.timestamp),
                             y: .value("CPU", historyValue(.cpu, sample) * 100))
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                }
            }
            chartCard("Memory", unit: percentUnit) {
                Chart(samples) { sample in
                    AreaMark(x: .value("Time", sample.timestamp),
                             y: .value("Memory", historyValue(.memory, sample) * 100))
                    .foregroundStyle(Color.accentColor.opacity(Tokens.Chart.areaOpacity))
                }
            }
            chartCard("Network", unit: "KB/s") {
                Chart(samples) { sample in
                    LineMark(x: .value("Time", sample.timestamp),
                             y: .value("Rx", sample.netRxBytesPerSec / 1024),
                             series: .value("Dir", "Rx"))
                    .foregroundStyle(.green)
                    LineMark(x: .value("Time", sample.timestamp),
                             y: .value("Tx", sample.netTxBytesPerSec / 1024),
                             series: .value("Dir", "Tx"))
                    .foregroundStyle(.orange)
                }
            }
        }

            if !events.isEmpty {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                    Text("Events").font(.headline)
                    ForEach(events.prefix(50)) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
    }

    private func chartCard<C: View>(_ title: String, unit: String, @ViewBuilder chart: @escaping () -> C) -> some View {
        ContainerTabSection {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            chart()
                .frame(height: Tokens.Chart.height)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: Tokens.Chart.axisDesiredCount)) }
        }
    }

    private var percentUnit: String {
        switch normalization.mode {
        case .container: return "% of container"
        case .machine: return "% of machine"
        }
    }

    private func historyValue(_ metric: GraphMetric, _ sample: MetricSample) -> Double {
        metric.value(from: sample,
                     snapshot: snapshot,
                     normalization: normalization,
                     memoryFallbackBytes: memoryFallbackBytes)
    }

    private var memoryFallbackBytes: UInt64 {
        UInt64(max(0, samples.map(\.memoryBytes).max() ?? 0))
    }
}

/// One row in an event log (used by the history tab and the system Activity view).
struct EventRow: View {
    let event: EventRecord
    var elevated = true
    /// When true, the row is highlighted (accent wash + dot) to mark an event the user hasn't seen yet.
    /// The Activity panel passes this; the per-container history tab leaves it false.
    var isUnread = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ResourceGlassCard(size: .small,
                          isSelected: isUnread,
                          elevated: elevated) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: event.kind.symbol,
                                     tint: event.kind.tint,
                                     backgroundOpacity: Tokens.ResourceCard.iconEmphasisBackgroundOpacity)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                    ResourceCardTitleText(text: event.message)
                    HStack(spacing: Tokens.Space.xs) {
                        ResourceBadgeText(text: event.kind.rawValue.capitalized)
                        ResourceCardSubtitleText(text: subtitle)
                    }
                }
            } trailing: {
                if isUnread {
                    DesignStatusDot(color: .accentColor)
                        .accessibilityLabel("Unread")
                } else {
                    EmptyView()
                }
            }
        }
        .selectionFill()
        .contextMenu { rowMenu }
    }

    /// Relative time, plus the container's short id when the event is container-scoped.
    private var subtitle: String {
        var parts = [event.timestamp.formatted(.relative(presentation: .numeric))]
        if let id = event.containerID, !id.isEmpty { parts.append(String(id.prefix(12))) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var rowMenu: some View {
        if event.isRead {
            Button { event.isRead = false; save() } label: { Label("Mark as Unread", systemImage: "circle") }
        } else {
            Button { event.isRead = true; save() } label: { Label("Mark as Read", systemImage: "checkmark.circle") }
        }
        Button { copyToPasteboard(event.message) } label: { Label("Copy Message", systemImage: "doc.on.doc") }
        Divider()
        Button(role: .destructive) { modelContext.delete(event); save() } label: {
            Label("Delete Event", systemImage: "trash")
        }
    }

    private func save() { try? modelContext.save() }
}

extension EventKind {
    /// A per-kind accent used for the event row's icon chip — gives the log visual texture and lets
    /// alerts/health transitions read at a glance.
    var tint: Color {
        switch self {
        case .lifecycle:   return .green
        case .image, .pull: return .blue
        case .compose:     return .purple
        case .build:       return .orange
        case .registry:    return .teal
        case .watchdog:    return .orange
        case .healthcheck: return .pink
        case .alert:       return .red
        case .system, .ui: return .secondary
        }
    }
}
