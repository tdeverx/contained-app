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
    @State private var selectedResources: [UUID: Set<String>]

    init(plans: [Core.System.CleanupPlan], pruneRequests: [AppModel.RuntimePruneRequest], recommended: Bool = false) {
        self.plans = plans
        self.pruneRequests = pruneRequests
        self.recommended = recommended
        _selectedResources = State(initialValue: Dictionary(uniqueKeysWithValues: plans.map { ($0.id, Set($0.resourceIDs)) }))
        _selectedIDs = State(initialValue: Set(plans.filter {
            AppModel.cleanupSelectedByDefault($0.action, recommended: recommended)
        }.map(\.id) + pruneRequests.filter {
            AppModel.cleanupSelectedByDefault($0.action, recommended: recommended)
        }.map(\.id)))
    }

    private var selectedPlans: [Core.System.CleanupPlan] {
        plans.filter { selectedIDs.contains($0.id) }.compactMap {
            try? $0.selectingResources(selectedResources[$0.id] ?? [])
        }.filter { !$0.commands.isEmpty }
    }
    private var selectedRequests: [AppModel.RuntimePruneRequest] { pruneRequests.filter { selectedIDs.contains($0.id) } }

    private func selection(_ id: UUID) -> Binding<Bool> {
        Binding(get: { selectedIDs.contains(id) }, set: { enabled in
            if enabled { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
        })
    }

    private func resourceSelection(_ resourceID: String, in plan: Core.System.CleanupPlan) -> Binding<Bool> {
        Binding(get: { selectedResources[plan.id, default: []].contains(resourceID) }, set: { enabled in
            if plan.action == .resetBuilderCache {
                // The native builder reset is one operation, not per-builder deletion.
                selectedResources[plan.id] = enabled ? Set(plan.resourceIDs) : []
            } else if enabled {
                selectedResources[plan.id, default: []].insert(resourceID)
            } else {
                selectedResources[plan.id, default: []].remove(resourceID)
            }
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
                            Toggle("Include this action", isOn: selection(plan.id))
                                .disabled(app.storageCleanupInFlight || plan.commands.isEmpty)
                            Text(app.runtimeDescriptor(for: plan.runtimeKind)?.displayName ?? plan.runtimeKind.rawValue)
                            Text(StoragePresentation.consequence(plan.action)).foregroundStyle(.secondary)
                            let selected = selectedResources[plan.id, default: []]
                            let narrowed = try? plan.selectingResources(selected)
                            Text("\(selected.count) of \(plan.resourceIDs.count) resources selected")
                            if let bytes = narrowed?.candidateAllocatedBytes {
                                Text("Selected host allocation: \(Format.bytes(bytes)) — not guaranteed reclaim")
                            } else {
                                Text("Selected host allocation unavailable; host allocation is measured before and after.")
                            }
                            if plan.resourceIDs.isEmpty { Text("No matching resources.") }
                            ForEach(plan.resourceIDs, id: \.self) { resourceID in
                                Toggle(isOn: resourceSelection(resourceID, in: plan)) {
                                    VStack(alignment: .leading) {
                                        Text(resourceID).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                        Text(StoragePresentation.size(resourceID, in: plan)).foregroundStyle(.secondary)
                                    }
                                }
                                .disabled(app.storageCleanupInFlight || !selectedIDs.contains(plan.id))
                            }
                            if plan.action == .resetBuilderCache, !plan.resourceIDs.isEmpty {
                                Text("Builder cache reset is one operation; builder resources are selected together.")
                                    .foregroundStyle(.secondary)
                            }
                            if selectedIDs.contains(plan.id), let narrowed, !narrowed.commands.isEmpty {
                                UI.Command.PreviewBar(commandText: narrowed.commands.map {
                                    app.commandPreviewText(arguments: $0, runtimeKind: plan.runtimeKind)
                                }.joined(separator: "\n"), copyHelp: AppText.copyCommand,
                                                      copiedAccessibilityLabel: AppText.copied)
                            }
                        }
                    }
                    ForEach(pruneRequests) { request in
                        UI.Panel.Section(header: StoragePresentation.title(request.action)) {
                            Toggle("Include this action", isOn: selection(request.id)).disabled(app.storageCleanupInFlight)
                            Text(app.runtimeDescriptor(for: request.runtimeKind)?.displayName ?? request.runtimeKind.rawValue)
                            Text(StoragePresentation.consequence(request.action)).foregroundStyle(.secondary)
                            Text("Size unavailable. This runtime does not support exact storage previews or per-item exclusions. Its native prune command determines unused resources at execution. Exclude this entire action to keep those resources. Apply Cleanup confirms this removal; it cannot be undone.")
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
