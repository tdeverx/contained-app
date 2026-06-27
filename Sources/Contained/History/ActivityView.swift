import SwiftUI
import SwiftData

/// System-wide activity log: every recorded event across all containers, newest first, filterable
/// by kind. The persistent counterpart to transient banners and alerts.
struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ActivityContent(showClose: true) { dismiss() }
            .frame(Tokens.SheetSize.wide)
            .sheetMaterial()
    }
}

struct ActivityContent: View {
    @Query(sort: \EventRecord.timestamp, order: .reverse) private var events: [EventRecord]
    @State private var filter: EventKind?
    var showClose = false
    var onClose: () -> Void = {}

    private var filtered: [EventRecord] {
        guard let filter else { return events }
        return events.filter { $0.kind == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Tokens.IconSize.control, height: Tokens.IconSize.control)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Activity").font(.headline)
                    Text("\(filtered.count) events").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if showClose {
                    GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                }
            }
            .padding(Tokens.Space.l)
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
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                        ForEach(filtered) { event in EventRow(event: event) }
                    }
                    .padding(Tokens.Space.l)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
        }
    }
}
