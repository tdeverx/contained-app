import SwiftUI
import ContainedUI
import ContainedCore

struct StorageCleanupPreview: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let plans: [Core.System.CleanupPlan]
    let pruneRequests: [AppModel.RuntimePruneRequest]

    var body: some View {
        VStack(spacing: 0) {
            UI.Panel.SheetTitleBar(title: AppText.string("storage.preview", defaultValue: "Storage cleanup preview"),
                                  cancelHelp: AppText.close, onCancel: { if !app.storageCleanupInFlight { dismiss() } }) {
                UI.Action.Group(UI.Action.Item(systemName: "checkmark", title: AppText.string("storage.apply", defaultValue: "Apply Cleanup"),
                                               help: AppText.string("storage.apply.help", defaultValue: "Execute only the previewed cleanup commands"),
                                               role: !pruneRequests.isEmpty || plans.contains { $0.action.risk != .compaction } ? .destructive : nil,
                                               isEnabled: !app.storageCleanupInFlight && app.activity == nil && app.activeImageBuilds == 0 && (!pruneRequests.isEmpty || plans.contains { !$0.commands.isEmpty })) {
                    Task { await app.performStorageCleanup(plans, pruneRequests: pruneRequests); dismiss() }
                })
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
                    ForEach(plans) { plan in
                        UI.Panel.Section(header: StoragePresentation.title(plan.action)) {
                            Text(app.runtimeDescriptor(for: plan.runtimeKind)?.displayName ?? plan.runtimeKind.rawValue)
                            Text(StoragePresentation.consequence(plan.action)).foregroundStyle(.secondary)
                            Text("\(plan.resourceIDs.count) exact resource identities")
                            if let bytes = plan.candidateAllocatedBytes {
                                Text("Candidate allocation: \(Format.bytes(bytes)) — upper bound, not guaranteed reclaim")
                            } else {
                                Text("Reclaim estimate unavailable; host allocation is measured before and after.")
                            }
                            if plan.resourceIDs.isEmpty { Text("No matching resources.") }
                            else { Text(plan.resourceIDs.joined(separator: "\n")).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
                            if !plan.commands.isEmpty {
                                UI.Command.PreviewBar(commandText: plan.commands.map {
                                    app.commandPreviewText(arguments: $0, runtimeKind: plan.runtimeKind)
                                }.joined(separator: "\n"), copyHelp: AppText.copyCommand,
                                                      copiedAccessibilityLabel: AppText.copied)
                            }
                        }
                    }
                    ForEach(pruneRequests) { request in
                        UI.Panel.Section(header: StoragePresentation.title(request.action)) {
                            Text(app.runtimeDescriptor(for: request.runtimeKind)?.displayName ?? request.runtimeKind.rawValue)
                            Text(StoragePresentation.consequence(request.action)).foregroundStyle(.secondary)
                            Text("This runtime does not support exact storage previews. Its native prune command determines unused resources at execution. Apply Cleanup confirms this removal; it cannot be undone.")
                        }
                    }
                    Text("The preview expires after five minutes. Changed runtime inventory requires a new preview. No Apple Container internal files are deleted directly.")
                        .foregroundStyle(.secondary)
                    if app.storageCleanupInFlight { UI.State.ProgressIndicator() }
                }
                .padding(UI.Layout.Spacing.l)
            }
        }
        .frame(UI.Panel.SheetSize.inspector)
        .sheetMaterial()
        .interactiveDismissDisabled(app.storageCleanupInFlight)
    }
}
