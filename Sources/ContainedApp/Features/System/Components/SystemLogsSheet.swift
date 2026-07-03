import SwiftUI
import ContainedUI
import ContainedCore

struct SystemLogsSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var follow = false
    @State private var session = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: UI.Layout.Spacing.m) {
                Text("System logs").designHeadlineLabelStyle()
                UI.Action.ToggleButton(isOn: $follow, title: AppText.follow, systemName: "arrow.down.to.line")
                    .onChange(of: follow) { _, _ in session += 1 }
                Spacer()
                UI.Action.Group(UI.Action.Item(systemName: "xmark",
                                               help: AppText.close,
                                               isCancel: true) {
                        dismiss()
                })
            }
            .padding(UI.Layout.Spacing.s)
            if let client = app.client, app.appleRuntimeAvailable {
                UI.Console.Stream(stream: { client.streamSystemLogs(follow: follow, last: 500, runtimeKind: .appleContainer) },
                              workingLabel: AppText.working,
                              completedLabel: AppText.completed,
                              lineCountLabel: AppText.lineCount,
                              copyLogHelp: AppText.copyLog,
                              failureLabel: AppErrorPresentation.message)
                    .id(session)
                    .padding(.horizontal, UI.Layout.Spacing.s)
                    .padding(.bottom, UI.Layout.Spacing.s)
            }
        }
        .frame(UI.Panel.SheetSize.wide)
        .sheetMaterial()
    }
}
