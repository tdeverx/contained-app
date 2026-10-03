import SwiftUI
import ContainedUI
import ContainedCore

struct StorageCleanupPreview: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let plans: [Core.System.CleanupPlan]
    let pruneRequests: [AppModel.RuntimePruneRequest]
    let recommended: Bool
    @State private var selectedIDs: Set<UUID>

    init(plans: [Core.System.CleanupPlan], pruneRequests: [AppModel.RuntimePruneRequest], recommended: Bool = false) {
        self.plans = plans
        self.pruneRequests = pruneRequests
        self.recommended = recommended
        _selectedIDs = State(initialValue: Set(plans.filter {
            AppModel.cleanupSelectedByDefault($0.action, recommended: recommended)
        }.map(\.id) + pruneRequests.filter {
            AppModel.cleanupSelectedByDefault($0.action, recommended: recommended)
        }.map(\.id)))
    }

    private var selectedPlans: [Core.System.CleanupPlan] { plans.filter { selectedIDs.contains($0.id) } }
    private var selectedRequests: [AppModel.RuntimePruneRequest] { pruneRequests.filter { selectedIDs.contains($0.id) } }

    private func selection(_ id: UUID) -> Binding<Bool> {
        Binding(get: { selectedIDs.contains(id) }, set: { enabled in
            if enabled { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            UI.Panel.SheetTitleBar(title: recommended ? AppText.string("storage.freeUpSpace", defaultValue: "Free Up Space…") : AppText.string("storage.preview", defaultValue: "Storage cleanup preview"),
                                  cancelHelp: AppText.close, onCancel: { if !app.storageCleanupInFlight { dismiss() } }) {
                UI.Action.Group(UI.Action.Item(systemName: "checkmark", title: AppText.string("storage.apply", defaultValue: "Apply Cleanup"),
                                               help: AppText.string("storage.apply.help", defaultValue: "Execute only the previewed cleanup commands"),
                                               role: !selectedRequests.isEmpty || selectedPlans.contains { $0.action.risk != .compaction } ? .destructive : nil,
                                               isEnabled: !app.storageCleanupInFlight && app.activity == nil && app.activeImageBuilds == 0 && app.containers.busyIDs.isEmpty && (!selectedRequests.isEmpty || selectedPlans.contains { !$0.commands.isEmpty })) {
                    let confirmedPlans = selectedPlans
                    let confirmedRequests = selectedRequests
                    Task { await app.performStorageCleanup(confirmedPlans, pruneRequests: confirmedRequests); dismiss() }
                })
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
                    if recommended {
                        Text("Only compaction is selected by default. Select cache or unused-resource removal explicitly; volumes contain data and their deletion cannot be undone. Stopped containers and arbitrary temporary files are never included.")
                            .foregroundStyle(.secondary)
                        StorageAutomationControls()
                    }
                    ForEach(plans) { plan in
                        UI.Panel.Section(header: StoragePresentation.title(plan.action)) {
                            if recommended {
                                Toggle("Include this action", isOn: selection(plan.id))
                                    .disabled(app.storageCleanupInFlight || plan.commands.isEmpty)
                            }
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
                            if recommended { Toggle("Include this action", isOn: selection(request.id)).disabled(app.storageCleanupInFlight) }
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
