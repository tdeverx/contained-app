import SwiftUI

/// Pretty-print any `Encodable` value to sorted, indented JSON (shared by the inspector sheet and the
/// in-panel inspect morph page).
func prettyJSON<Value: Encodable>(_ value: Value) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(value), let s = String(data: data, encoding: .utf8) else {
        return "Couldn't render JSON."
    }
    return s
}

/// Header-less scrolling JSON body — reused by `JSONInspectorSheet` and the image-detail inspect page.
struct InlineJSONView: View {
    let json: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(json)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(Tokens.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }
}

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
                    GlassButtonItem(systemName: "doc.on.doc", help: "Copy") { copyToPasteboard(prettyJSON(value)) }
                }
                GlassButton(singleItem: true) {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true) {
                        dismiss()
                    }
                }
            }
            .padding(Tokens.Space.l)
            Divider()
            InlineJSONView(json: prettyJSON(value))
        }
        .frame(Tokens.SheetSize.inspector)
        .sheetMaterial()
    }
}
