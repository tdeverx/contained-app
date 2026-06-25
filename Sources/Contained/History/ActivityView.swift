import SwiftUI
import SwiftData

/// System-wide activity log: every recorded event across all containers, newest first, filterable
/// by kind. The persistent counterpart to the transient banners/notifications.
struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EventRecord.timestamp, order: .reverse) private var events: [EventRecord]
    @State private var filter: EventKind?

    private var filtered: [EventRecord] {
        guard let filter else { return events }
        return events.filter { $0.kind == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Activity", subtitle: "\(filtered.count) events", cancelHelp: "Close",
                        onCancel: { dismiss() })
            Picker("Filter", selection: $filter) {
                Text("All").tag(EventKind?.none)
                ForEach(EventKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue.capitalized).tag(EventKind?.some(kind))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Tokens.Space.l)
            .padding(.bottom, Tokens.Space.s)
            Divider()
            if filtered.isEmpty {
                ContentUnavailableView("No activity", systemImage: "clock.arrow.circlepath",
                                       description: Text("Events from container lifecycle, the watchdog, and healthchecks land here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filtered) { event in EventRow(event: event) }
                    }
                    .padding(Tokens.Space.l)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
        }
        .frame(Tokens.SheetSize.wide)
        .background(.regularMaterial)
    }
}
