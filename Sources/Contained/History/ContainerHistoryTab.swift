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
        let chartPoints = HistoryChartPoint.points(from: samples.map(MetricSampleSnapshot.init),
                                                   snapshot: snapshot,
                                                   normalization: normalization)

        LazyVStack(alignment: .leading, spacing: Tokens.Space.l) {
            if chartPoints.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "chart.xyaxis.line",
                                       description: Text("Resource samples accumulate while the container runs."))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                chartCard("CPU", unit: percentUnit) {
                    Chart(chartPoints) { point in
                        LineMark(x: .value("Time", point.timestamp),
                                 y: .value("CPU", point.cpuPercent))
                            .foregroundStyle(Color.accentColor)
                            .interpolationMethod(.monotone)
                    }
                    .percentHistoryScale()
                }
                chartCard("Memory", unit: percentUnit) {
                    Chart(chartPoints) { point in
                        AreaMark(x: .value("Time", point.timestamp),
                                 y: .value("Memory", point.memoryPercent))
                            .foregroundStyle(Color.accentColor.opacity(Tokens.Chart.areaOpacity))
                    }
                    .percentHistoryScale()
                }
                chartCard("Network", unit: "KB/s") {
                    Chart(chartPoints) { point in
                        LineMark(x: .value("Time", point.timestamp),
                                 y: .value("Rx", point.netRxKBPerSec),
                                 series: .value("Dir", "Rx"))
                            .foregroundStyle(.green)
                        LineMark(x: .value("Time", point.timestamp),
                                 y: .value("Tx", point.netTxKBPerSec),
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
                .transaction { transaction in transaction.animation = nil }
        }
    }

    private var percentUnit: String {
        switch normalization.mode {
        case .container: return "% of container"
        case .machine: return "% of machine"
        }
    }
}

struct HistoryChartPoint: Identifiable, Equatable {
    let id: Int
    let timestamp: Date
    let cpuPercent: Double
    let memoryPercent: Double
    let netRxKBPerSec: Double
    let netTxKBPerSec: Double

    static func points(from samples: [MetricSampleSnapshot],
                       snapshot: ContainerSnapshot,
                       normalization: StatsNormalizationContext) -> [HistoryChartPoint] {
        guard !samples.isEmpty else { return [] }

        let memoryFallbackBytes = samples.reduce(UInt64(0)) { current, sample in
            max(current, bytes(from: sample.memoryBytes))
        }
        let cpuLimit = normalization.cpuLimit(for: snapshot)
        let memoryLimit = normalization.memoryLimitBytes(for: snapshot, fallback: memoryFallbackBytes)

        return samples.enumerated().map { index, sample in
            let cpu = sanitized(sample.cpuFraction) / cpuLimit
            let memory = memoryLimit > 0 ? sanitized(sample.memoryBytes) / Double(memoryLimit) : 0
            return HistoryChartPoint(id: index,
                                     timestamp: sample.timestamp,
                                     cpuPercent: percent(cpu),
                                     memoryPercent: percent(memory),
                                     netRxKBPerSec: sanitized(sample.netRxBytesPerSec) / 1024,
                                     netTxKBPerSec: sanitized(sample.netTxBytesPerSec) / 1024)
        }
    }

    private static func percent(_ fraction: Double) -> Double {
        min(max(sanitized(fraction), 0), 1) * 100
    }

    private static func sanitized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return value
    }

    private static func bytes(from value: Double) -> UInt64 {
        UInt64(min(sanitized(value), Double(UInt64.max)))
    }
}

private extension View {
    func percentHistoryScale() -> some View {
        self
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisTick()
                    if let percent = value.as(Double.self) {
                        AxisValueLabel("\(Int(percent))%")
                    }
                }
            }
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
        ResourceCard(size: .small,
                     isSelected: isUnread,
                     elevated: elevated,
                     title: event.message,
                     subtitle: subtitle) {
            ResourceCardIconChip(symbol: event.kind.symbol,
                                 tint: event.kind.tint,
                                 backgroundOpacity: Tokens.ResourceCard.iconEmphasisBackgroundOpacity)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            ResourceBadgeText(text: event.kind.rawValue.capitalized)
        } headerAccessory: {
            if isUnread {
                DesignStatusDot(color: .accentColor)
                    .accessibilityLabel("Unread")
            } else {
                EmptyView()
            }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
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
