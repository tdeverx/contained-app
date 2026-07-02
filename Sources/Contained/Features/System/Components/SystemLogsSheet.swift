import SwiftUI
import ContainedDesignSystem
import ContainedCore

struct SystemLogsSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var follow = false
    @State private var session = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.m) {
                Text("System logs").font(.headline)
                Toggle(isOn: $follow) { Label("Follow", systemImage: "arrow.down.to.line") }
                    .toggleStyle(.button).buttonStyle(.glass).buttonBorderShape(.capsule)
                    .onChange(of: follow) { _, _ in session += 1 }
                Spacer()
                GlassButton(singleItem: true) {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true) {
                        dismiss()
                    }
                }
            }
            .padding(Tokens.Space.s)
            if let client = app.client {
                StreamConsole(stream: { client.streamSystemLogs(follow: follow, last: 500) })
                    .id(session)
                    .padding(.horizontal, Tokens.Space.s)
                    .padding(.bottom, Tokens.Space.s)
            }
        }
        .frame(Tokens.SheetSize.wide)
        .sheetMaterial()
    }
}
