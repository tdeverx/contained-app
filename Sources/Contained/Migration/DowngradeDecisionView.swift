import SwiftUI
import ContainedDesignSystem

struct DowngradeDecisionView: View {
    let schemaVersion: Int
    var onExportAndReset: () -> Void
    var onKeep: () -> Void
    var onQuit: () -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Tokens.Space.l) {
            SheetHeader(title: "This data was created by a newer version",
                        subtitle: "Stored schema \(schemaVersion), this app supports \(StateMigrator.currentSchemaVersion).",
                        cancelHelp: "Quit",
                        onCancel: onQuit)

            Text("You can export a backup before resetting incompatible local data, try to keep what this build can still read, or quit and install the newer build again.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                Button("Export Backup, Then Reset") { onExportAndReset() }
                    .buttonStyle(.borderedProminent)
                Button("Try to Keep Readable Data") { onKeep() }
                Button("Quit Contained", role: .cancel) { onQuit() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Tokens.Space.l)
        .frame(width: Tokens.SheetSize.dialogWidth)
    }
}
