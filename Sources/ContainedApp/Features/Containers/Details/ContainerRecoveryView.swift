import SwiftUI
import ContainedUI
import ContainedCore

/// A saved original remains discoverable even when no runtime card survived recreation.
struct ContainerRecoveryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let recovery: AppDatabase.ContainerRecreationRecovery
    @State private var confirmingKeep = false

    private var existing: Core.Container.Snapshot? {
        app.containers.snapshots.first { $0.scopedID == recovery.id }
    }

    var body: some View {
        UI.Panel.Scaffold(width: UI.Panel.SheetSize.inspector.width, scrolls: false) {
            UI.Panel.SheetTitleBar(title: AppText.string("recreate.recovery", defaultValue: "Container recovery"),
                                  cancelHelp: AppText.close, onCancel: { dismiss() }) {
                UI.Action.Group(UI.Action.Item(systemName: "arrow.counterclockwise", title: AppText.string("recreate.restore", defaultValue: "Restore Original"),
                                               help: AppText.string("recreate.restore.help", defaultValue: "Create the saved original without deleting any existing container"),
                                               isEnabled: existing == nil && app.database.canPersist && !app.containers.busyIDs.contains(recovery.id)) {
                    Task { if await app.restoreContainerRecreation(recovery) { dismiss() } }
                })
            }
        } content: {
            ScrollView {
                UI.Panel.Section(header: recovery.snapshot.displayName) {
                    let spec = ContainerFormState(document: recovery.document)
                    LabeledContent("Original image", value: recovery.snapshot.image)
                    LabeledContent("Recovery image", value: spec.image)
                    Text("Recreation did not complete. The saved original process, ports, and mounts remain available. Restoration creates a missing container and verifies its original running or stopped state; it does not delete containers or volumes. Runtime errors are shown when a restore fails.")
                        .foregroundStyle(.secondary)
                    if existing != nil {
                        Text("A container already uses this name. Use its normal controls to inspect or start it; recovery will not overwrite it.")
                        Button("Keep Existing Container") {
                            confirmingKeep = true
                        }
                        .disabled(app.containers.busyIDs.contains(recovery.id))
                    }
                    UI.Command.PreviewBar(commandText: app.previewCreateCommandText(for: spec, start: recovery.snapshot.state == .running), copyHelp: AppText.copyCommand,
                                          copiedAccessibilityLabel: AppText.copied)
                    Text("Requested command — the runtime may resolve saved image and disk identities to local recovery names before running it.")
                        .foregroundStyle(.secondary)
                    Text("The command may include saved environment values and host paths. Review it before copying or sharing.")
                        .foregroundStyle(.secondary)
                }
                .padding(UI.Panel.Padding.all)
            }
        }
        .frame(UI.Panel.SheetSize.inspector)
        .sheetMaterial()
        .interactiveDismissDisabled(app.containers.busyIDs.contains(recovery.id))
        .confirmationDialog("Keep the existing container and close recovery?", isPresented: $confirmingKeep) {
            Button("Keep Existing Container") {
                Task { if await app.keepExistingContainerRecreation(recovery) { dismiss() } }
            }
        } message: {
            Text("This discards the saved original recovery recipe without changing the existing container. Only continue if you have verified it works.")
        }
    }
}
