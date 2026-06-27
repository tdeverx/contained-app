import SwiftUI
import ContainedCore

/// Show an image's layer history (from the first runnable variant's config).
struct ImageHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: ContainedCore.ImageResource

    private var history: [VariantConfig.HistoryEntry] {
        let variant = image.variants.first(where: \.isRunnable) ?? image.variants.first
        return variant?.config?.history ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "History", subtitle: Format.shortImage(image.reference),
                        cancelHelp: "Close", onCancel: { dismiss() })
            Divider()
            if history.isEmpty {
                ContentUnavailableView("No history", systemImage: "clock",
                                       description: Text("This image records no layer history."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                        ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.createdBy ?? entry.comment ?? "—")
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let created = entry.created {
                                    Text(created.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                            .padding(Tokens.Space.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                        }
                    }
                    .padding(Tokens.Space.l)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
        }
        .frame(Tokens.SheetSize.inspector)
        .sheetMaterial()
    }
}
