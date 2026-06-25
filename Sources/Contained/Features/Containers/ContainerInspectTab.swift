import SwiftUI
import ContainedCore

/// The Inspect tab: the container snapshot rendered as pretty-printed JSON.
struct ContainerInspectTab: View {
    let snapshot: ContainerSnapshot
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
    private var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot), let s = String(data: data, encoding: .utf8) else {
            return "Couldn't render JSON."
        }
        return s
    }
}
