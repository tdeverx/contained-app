import SwiftUI
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
    let snapshot: ContainerSnapshot
    @Query private var samples: [MetricSample]
    @Query private var events: [EventRecord]
    @State private var range: HistoryRange = .day

    init(snapshot: ContainerSnapshot) {
        self.snapshot = snapshot
        let id = snapshot.id
        _samples = Query(filter: #Predicate { $0.containerID == id }, sort: \MetricSample.timestamp)
        _events = Query(filter: #Predicate { $0.containerID == id },
                        sort: \EventRecord.timestamp, order: .reverse)
    }

    private var cutoff: Date { Date().addingTimeInterval(-range.seconds) }
    private var windowed: [MetricSample] { samples.filter { $0.timestamp >= cutoff } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                Picker("Range", selection: $range) {
                    ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                if windowed.isEmpty {
                    ContentUnavailableView("No history yet", systemImage: "chart.xyaxis.line",
                                           description: Text("Resource samples accumulate while the container runs."))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    chartCard("CPU", unit: "% of a core") {
                        Chart(windowed) { sample in
                            LineMark(x: .value("Time", sample.timestamp),
                                     y: .value("CPU", sample.cpuFraction * 100))
                            .foregroundStyle(Color.accentColor)
                            .interpolationMethod(.monotone)
                        }
                    }
                    chartCard("Memory", unit: "MB") {
                        Chart(windowed) { sample in
                            AreaMark(x: .value("Time", sample.timestamp),
                                     y: .value("Memory", sample.memoryBytes / 1_048_576))
                            .foregroundStyle(Color.accentColor.opacity(0.3))
                        }
                    }
                    chartCard("Network", unit: "KB/s") {
                        Chart(windowed) { sample in
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
                    VStack(alignment: .leading, spacing: Tokens.Space.s) {
                        Text("Events").font(.headline)
                        ForEach(events.prefix(50)) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
            .padding(Tokens.Space.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private func chartCard<C: View>(_ title: String, unit: String, @ViewBuilder chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            chart()
                .frame(height: 140)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        }
        .padding(Tokens.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card)
    }
}

/// One row in an event log (used by the history tab and the system Activity view).
struct EventRow: View {
    let event: EventRecord
    var elevated = true
    /// When true, the row is highlighted (accent dot + accent icon tint) to mark an event the user
    /// hasn't seen yet. The Activity panel passes this; the per-container history tab leaves it false.
    var isUnread = false
    var body: some View {
        ResourceGlassCard(size: .small,
                          isSelected: isUnread,
                          fill: isUnread ? Color.accentColor : nil,
                          fillOpacity: 0.10,
                          elevated: elevated) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: event.kind.symbol,
                                     tint: isUnread ? .accentColor : .secondary,
                                     backgroundOpacity: 0.22)
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: event.message)
                    ResourceCardSubtitleText(text: event.timestamp.formatted(date: .abbreviated, time: .shortened))
                }
            } trailing: {
                if isUnread {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                        .accessibilityLabel("Unread")
                } else {
                    EmptyView()
                }
            }
        }
    }
}
