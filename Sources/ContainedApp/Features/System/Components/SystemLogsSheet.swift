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
            HStack(spacing: DesignTokens.Space.m) {
                Text("System logs").font(.headline)
                DesignGlassToggle(isOn: $follow, title: AppText.follow, systemName: "arrow.down.to.line")
                    .onChange(of: follow) { _, _ in session += 1 }
                Spacer()
                DesignActionGroup(DesignAction(systemName: "xmark",
                                               help: AppText.close,
                                               isCancel: true) {
                        dismiss()
                })
            }
            .padding(DesignTokens.Space.s)
            if let client = app.client {
                StreamConsole(stream: { client.streamSystemLogs(follow: follow, last: 500) },
                              workingLabel: AppText.working,
                              completedLabel: AppText.completed,
                              lineCountLabel: AppText.lineCount,
                              copyLogHelp: AppText.copyLog,
                              failureLabel: AppErrorPresentation.message)
                    .id(session)
                    .padding(.horizontal, DesignTokens.Space.s)
                    .padding(.bottom, DesignTokens.Space.s)
            }
        }
        .frame(DesignTokens.SheetSize.wide)
        .sheetMaterial()
    }
}
