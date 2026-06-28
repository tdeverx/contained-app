import SwiftUI

/// A reusable pretty-printed-JSON inspector sheet for any `Encodable` resource.
struct JSONInspectorSheet<Value: Encodable>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let value: Value

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline).lineLimit(1)
                Spacer()
                GlassButton(singleItem: true) {
                    GlassButtonItem(systemName: "doc.on.doc", help: "Copy") { copyToPasteboard(json) }
                }
                GlassButton(singleItem: true) {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true) {
                        dismiss()
                    }
                }
            }
            .padding(Tokens.Space.l)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(Tokens.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .frame(Tokens.SheetSize.inspector)
        .sheetMaterial()
    }

    private var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value), let s = String(data: data, encoding: .utf8) else {
            return "Couldn't render JSON."
        }
        return s
    }
}
