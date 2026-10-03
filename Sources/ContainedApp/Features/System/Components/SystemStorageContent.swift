import SwiftUI
import ContainedUI
import ContainedCore

struct SystemStorageContent: View {
    @Environment(AppModel.self) private var app
    var elevated: Bool

    var body: some View {
        UI.Surface.Content(elevated: elevated, alignment: .leading) {
            VStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
                Text("Storage analysis").designHeadlineLabelStyle()
                UI.Action.TextButton(title: AppText.string("storage.freeUpSpace", defaultValue: "Free Up Space…"),
                                     systemName: "externaldrive.badge.minus",
                                     help: AppText.string("storage.freeUpSpace.help", defaultValue: "Review compaction and optional cleanup before changing anything")) {
                    Task { await app.prepareFreeUpSpace() }
                }
                .disabled(app.storagePlanInFlight || app.storageCleanupInFlight)
                Button("Refresh Storage Analysis") { Task { await app.refreshStorageAnalysis() } }
                ForEach(app.storageRuntimes, id: \.kind) { runtime in
                    if let error = app.storageAnalysisErrors[runtime.kind] { UI.State.InlineStatus(error, tone: .error) }
                    if let analysis = app.storageAnalyses[runtime.kind] {
                        Text(runtime.displayName).designHeadlineLabelStyle()
                        LabeledContent("Host allocated", value: Format.bytes(analysis.totalAllocatedBytes))
                        if let capacity = analysis.capacity {
                            LabeledContent("Host free space", value: ByteCountFormatter.string(fromByteCount: capacity.availableBytes, countStyle: .file))
                        }
                        if let usage = analysis.runtimeReported {
                            LabeledContent("Runtime reported usage", value: Format.bytes(usage.totalSizeInBytes))
                            LabeledContent("Runtime reported reclaimable", value: Format.bytes(usage.totalReclaimableBytes))
                        }
                        ForEach(Core.System.StorageCategory.allCases) { category in
                            LabeledContent(StoragePresentation.title(category), value: Format.bytes(analysis.allocatedBytes[category] ?? 0))
                        }
                        Text("Measured \(analysis.measuredAt.formatted()). Host allocation and runtime logical accounting are different; neither promises exact reclaimable bytes.")
                            .foregroundStyle(.secondary)
                        if !analysis.isComplete { Text("Partial measurement — unreadable entries or scan limit encountered. Automation will not use this result.").foregroundStyle(.orange) }
                        if !analysis.unsupportedEntries.isEmpty {
                            Text("Unclassified / orphan candidates — report only:").foregroundStyle(.secondary)
                            Text(analysis.unsupportedEntries.joined(separator: "\n")).textSelection(.enabled)
                        }
                        if !analysis.longRunningBindContainerIDs.isEmpty {
                            Text("Long-running bind-mounted workloads: \(analysis.longRunningBindContainerIDs.joined(separator: ", ")). Deleted host files may remain held by virtio-fs; stopping the affected container is Apple's workaround. This is a risk indicator, not proof of held files.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("No generic /tmp or cache deletion is safe across arbitrary images. Declare genuinely disposable paths as size-limited tmpfs mounts in Run/Edit instead; their contents disappear when the container stops.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StorageAutomationControls: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        @Bindable var settings = app.settings
        UI.Panel.Section(header: AppText.string("storage.automation", defaultValue: "Storage compaction automation")) {
            Toggle("Enable automatic compaction", isOn: $settings.storageCleanupPolicy.enabled)
            Toggle("Running application containers", isOn: $settings.storageCleanupPolicy.compactContainers)
            Toggle("Running builder", isOn: $settings.storageCleanupPolicy.compactBuilder)
            Stepper("Interval: \(settings.storageCleanupPolicy.intervalHours) hours", value: $settings.storageCleanupPolicy.intervalHours, in: 1...24)
            Stepper("Run below \(settings.storageCleanupPolicy.minimumFreeGiB) GiB free", value: $settings.storageCleanupPolicy.minimumFreeGiB, in: 1...1000)
            Stepper("Or above \(settings.storageCleanupPolicy.maximumAllocatedGiB) GiB allocated", value: $settings.storageCleanupPolicy.maximumAllocatedGiB, in: 1...1000)
            Text("Off by default. Checks hourly while Contained runs; compacts at most 16 running containers per scheduled category. Never deletes containers, volumes, images, networks, or builder cache. Stops nothing and skips active app builds/pulls.")
                .foregroundStyle(.secondary)
        }
    }
}
