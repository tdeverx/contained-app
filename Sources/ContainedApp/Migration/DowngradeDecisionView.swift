import SwiftUI
import ContainedDesignSystem

struct DowngradeDecisionView: View {
    let schemaVersion: Int
    var onExportAndReset: () -> Void
    var onKeep: () -> Void
    var onQuit: () -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: DesignTokens.Space.l) {
            SheetHeader(title: AppText.string("downgrade.title", defaultValue: "This data was created by a newer version"),
                        subtitle: AppText.string("downgrade.subtitle", defaultValue: "Stored schema \(schemaVersion), this app supports \(StateMigrator.currentSchemaVersion)."),
                        cancelHelp: AppText.quit,
                        onCancel: onQuit)

            Text(AppText.string("downgrade.description", defaultValue: "You can export a backup before resetting incompatible local data, try to keep what this build can still read, or quit and install the newer build again."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVStack(alignment: .leading, spacing: DesignTokens.Space.s) {
                Button(AppText.string("downgrade.exportBackupThenReset", defaultValue: "Export Backup, Then Reset")) { onExportAndReset() }
                    .buttonStyle(.borderedProminent)
                Button(AppText.string("downgrade.keepReadableData", defaultValue: "Try to Keep Readable Data")) { onKeep() }
                Button(AppText.string("downgrade.quitContained", defaultValue: "Quit Contained"), role: .cancel) { onQuit() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Space.l)
        .frame(width: DesignTokens.SheetSize.dialogWidth)
    }
}
