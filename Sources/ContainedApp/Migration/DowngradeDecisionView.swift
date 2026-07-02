import SwiftUI
import ContainedUI

struct DowngradeDecisionView: View {
    let schemaVersion: Int
    var onExportAndReset: () -> Void
    var onKeep: () -> Void
    var onQuit: () -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
            UI.Panel.SheetTitleBar(title: AppText.string("downgrade.title", defaultValue: "This data was created by a newer version"),
                        subtitle: AppText.string("downgrade.subtitle", defaultValue: "Stored schema \(schemaVersion), this app supports \(StateMigrator.currentSchemaVersion)."),
                        cancelHelp: AppText.quit,
                        onCancel: onQuit)

            Text(AppText.string("downgrade.description", defaultValue: "You can export a backup before resetting incompatible local data, try to keep what this build can still read, or quit and install the newer build again."))
                .designSecondaryValueStyle()
                .fixedSize(horizontal: false, vertical: true)

            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                Button(AppText.string("downgrade.exportBackupThenReset", defaultValue: "Export Backup, Then Reset")) { onExportAndReset() }
                    .buttonStyle(.borderedProminent)
                Button(AppText.string("downgrade.keepReadableData", defaultValue: "Try to Keep Readable Data")) { onKeep() }
                Button(AppText.string("downgrade.quitContained", defaultValue: "Quit Contained"), role: .cancel) { onQuit() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(UI.Layout.Spacing.l)
        .frame(width: UI.Panel.SheetSize.dialogWidth)
    }
}
