import SwiftUI
import ContainedUI
import ContainedCore

struct CreationNetworkFields: View {
    @Binding var name: String
    @Binding var subnet: String
    @Binding var internalOnly: Bool
    @Binding var runtimeKind: Core.Runtime.Kind
    let runtimes: [Core.Runtime.Descriptor]
    let runtimePickerDisabledReason: String
    let working: Bool
    var onSubmit: () -> Void

    var body: some View {
        CreationResourceForm(symbol: "network",
                             title: networkName,
                             subtitle: networkSubtitle,
                             command: previewCommand,
                             runtimeKind: runtimeKind,
                             runtimes: runtimes) {
            UI.Panel.Section(header: AppText.string("creation.details", defaultValue: "Details"), highlighted: hasValues) {
                CreationRuntimePickerRow(runtimeKind: $runtimeKind,
                                         runtimes: runtimes,
                                         disabledReason: runtimePickerDisabledReason)
                UI.Panel.Field(label: AppText.string("creation.name", defaultValue: "Name"),
                           info: AppText.string("creation.network.name.info", defaultValue: "A readable name used by containers with `--network`."),
                           error: nameError) {
                    TextField("", text: $name, prompt: Text("my-network"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
                UI.Panel.Field(label: AppText.string("creation.subnet", defaultValue: "Subnet"),
                           info: AppText.string("creation.network.subnet.info", defaultValue: "Optional CIDR range for the network, for example `10.0.0.0/24`.")) {
                    TextField("", text: $subnet, prompt: Text("optional, e.g. 10.0.0.0/24"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
                UI.Panel.ToggleRow(title: AppText.string("creation.network.internalOnly", defaultValue: "Internal only"),
                               subtitle: AppText.string("creation.network.internalOnly.subtitle", defaultValue: "Restrict containers on this network from external access."),
                               isOn: $internalOnly)
            }
        } footer: {
            CreationSubmitBar(title: AppText.string("creation.network.create", defaultValue: "Create network"),
                              systemImage: "network.badge.plus",
                              canSubmit: canSubmit,
                              working: working,
                              action: onSubmit)
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedSubnet: String { subnet.trimmingCharacters(in: .whitespaces) }
    private var canSubmit: Bool { !trimmedName.isEmpty && !working }
    private var hasValues: Bool { !trimmedName.isEmpty || !trimmedSubnet.isEmpty || internalOnly }
    private var nameError: String? { trimmedName.isEmpty ? AppText.string("creation.network.name.required", defaultValue: "A network name is required.") : nil }
    private var networkName: String { trimmedName.isEmpty ? AppText.string("creation.network.new", defaultValue: "New network") : trimmedName }
    private var networkSubtitle: String {
        var parts = [internalOnly ? AppText.string("creation.network.mode.internal", defaultValue: "internal") : AppText.string("creation.network.mode.bridge", defaultValue: "bridge")]
        if !trimmedSubnet.isEmpty { parts.append(trimmedSubnet) }
        return parts.joined(separator: "  ·  ")
    }
    private var previewCommand: [String] {
        Core.Command.networkCreatePreview(name: trimmedName.isEmpty ? "<name>" : trimmedName,
                                        subnet: trimmedSubnet.isEmpty ? nil : trimmedSubnet,
                                        internalOnly: internalOnly,
                                        runtimeKind: runtimeKind)
    }

    private func submitIfReady() {
        guard canSubmit else { return }
        onSubmit()
    }
}

struct CreationVolumeFields: View {
    @Binding var name: String
    @Binding var size: String
    @Binding var runtimeKind: Core.Runtime.Kind
    let runtimes: [Core.Runtime.Descriptor]
    let runtimePickerDisabledReason: String
    let working: Bool
    var onSubmit: () -> Void

    var body: some View {
        CreationResourceForm(symbol: "externaldrive",
                             title: volumeName,
                             subtitle: volumeSubtitle,
                             command: previewCommand,
                             runtimeKind: runtimeKind,
                             runtimes: runtimes) {
            UI.Panel.Section(header: AppText.string("creation.details", defaultValue: "Details"), highlighted: hasValues) {
                CreationRuntimePickerRow(runtimeKind: $runtimeKind,
                                         runtimes: runtimes,
                                         disabledReason: runtimePickerDisabledReason)
                UI.Panel.Field(label: AppText.string("creation.name", defaultValue: "Name"),
                           info: AppText.string("creation.volume.name.info", defaultValue: "A persistent storage name you can mount into containers."),
                           error: nameError) {
                    TextField("", text: $name, prompt: Text("my-volume"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
                UI.Panel.Field(label: AppText.string("creation.volume.size", defaultValue: "Size"),
                           info: AppText.string("creation.volume.size.info", defaultValue: "Optional runtime-specific size hint, such as `10G`. Leave blank for default.")) {
                    TextField("", text: $size, prompt: Text("optional, e.g. 10G"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
            }
        } footer: {
            CreationSubmitBar(title: AppText.string("creation.volume.create", defaultValue: "Create volume"),
                              systemImage: "externaldrive.badge.plus",
                              canSubmit: canSubmit,
                              working: working,
                              action: onSubmit)
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedSize: String { size.trimmingCharacters(in: .whitespaces) }
    private var canSubmit: Bool { !trimmedName.isEmpty && !working }
    private var hasValues: Bool { !trimmedName.isEmpty || !trimmedSize.isEmpty }
    private var nameError: String? { trimmedName.isEmpty ? AppText.string("creation.volume.name.required", defaultValue: "A volume name is required.") : nil }
    private var volumeName: String { trimmedName.isEmpty ? AppText.string("creation.volume.new", defaultValue: "New volume") : trimmedName }
    private var volumeSubtitle: String { trimmedSize.isEmpty ? AppText.string("creation.volume.defaultSize", defaultValue: "default size") : trimmedSize }
    private var previewCommand: [String] {
        Core.Command.volumeCreatePreview(name: trimmedName.isEmpty ? "<name>" : trimmedName,
                                       size: trimmedSize.isEmpty ? nil : trimmedSize,
                                       runtimeKind: runtimeKind)
    }

    private func submitIfReady() {
        guard canSubmit else { return }
        onSubmit()
    }
}

struct CreationRuntimePickerRow: View {
    @Binding var runtimeKind: Core.Runtime.Kind
    let runtimes: [Core.Runtime.Descriptor]
    let disabledReason: String

    var body: some View {
        UI.Panel.Row(title: AppText.runtime,
                     subtitle: runtimes.count > 1 ? AppText.runtimeSubtitle : disabledReason) {
            Picker("", selection: $runtimeKind) {
                ForEach(runtimes, id: \.kind) { descriptor in
                    Text(descriptor.displayName).tag(descriptor.kind)
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(runtimes.count < 2)
        }
        .onAppear {
            guard let first = runtimes.first, !runtimes.contains(where: { $0.kind == runtimeKind }) else { return }
            runtimeKind = first.kind
        }
    }
}

struct CreationLocalImagesContent: View {
    @Environment(AppModel.self) private var app
    @Binding var query: String
    var onSelect: (ContainerFormState) -> Void

    var body: some View {
        LazyVStack(spacing: UI.Layout.Spacing.m) {
            UI.Control.SearchField(text: $query,
                              prompt: AppText.string("creation.localImages.filter", defaultValue: "Filter local images"),
                              clearLabel: AppText.clear)

            if filteredLocalImages.isEmpty {
                UI.State.Empty(AppText.string("creation.localImages.noMatches", defaultValue: "No matching images"),
                                 systemImage: "square.stack.3d.up",
                                 description: query.isEmpty
                                    ? AppText.string("creation.localImages.empty", defaultValue: "Pull or build an image first.")
                                    : AppText.string("creation.localImages.tryDifferentFilter", defaultValue: "Try a different filter."))
            } else {
                ScrollView {
                    LazyVStack(spacing: UI.Layout.Spacing.xs) {
                        ForEach(filteredLocalImages) { image in
                            CreationLocalImageRow(image: image) {
                                onSelect(RecommendedImage.spec(for: image.reference,
                                                               runtimeKind: image.runtimeKind))
                            }
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                }
            }
        }
        .task { await app.refreshImagesIfNeeded() }
    }

    private var filteredLocalImages: [Core.Image.Resource] {
        let images = app.images
            .filter { $0.variants.contains(where: \.isRunnable) || $0.variants.isEmpty }
            .sorted { $0.reference.localizedCaseInsensitiveCompare($1.reference) == .orderedAscending }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return images }
        return images.filter { $0.reference.localizedCaseInsensitiveContains(trimmed) }
    }
}

struct CreationPastedComposeContent: View {
    @Binding var text: String
    var onImport: () -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.m) {
            UI.Surface.Input(horizontalPadding: UI.Layout.Spacing.s,
                               verticalPadding: UI.Layout.Spacing.s,
                               minHeight: 260) {
                TextEditor(text: $text)
                    .designMonospacedCallout()
                    .scrollContentBackground(.hidden)
            }

            HStack {
                Spacer()
            UI.Action.TextButton(title: AppText.string("common.import", defaultValue: "Import"),
                                       systemName: "arrow.down.doc",
                                       prominence: .prominent,
                                       isEnabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    onImport()
                }
            }
        }
    }
}

struct CreationTemplatesContent: View {
    let templates: [RecipeRecord]
    var onSelect: (ContainerFormState) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: UI.Layout.Spacing.s) {
                ForEach(templates) { template in
                    CreationChoiceCard(symbol: "bookmark",
                                       title: template.name,
                                       subtitle: Format.shortImage(template.spec?.image ?? "—")) {
                        if let spec = template.spec { onSelect(spec) }
                    }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
}

private struct CreationSubmitBar: View {
    let title: String
    let systemImage: String
    let canSubmit: Bool
    let working: Bool
    var action: () -> Void

    var body: some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            Spacer()
            if working { UI.State.ProgressIndicator() }
            UI.Action.TextButton(title: title,
                                   systemName: systemImage,
                                   prominence: .prominent,
                                   isEnabled: canSubmit && !working) {
                action()
            }
        }
        .padding(UI.Layout.Spacing.s)
        .background(.clear)
    }
}

private struct CreationResourceForm<Fields: View, Footer: View>: View {
    let symbol: String
    let title: String
    let subtitle: String
    let command: [String]
    let runtimeKind: Core.Runtime.Kind
    let runtimes: [Core.Runtime.Descriptor]
    @ViewBuilder var fields: () -> Fields
    @ViewBuilder var footer: () -> Footer

    private var commandText: String {
        let executable = runtimes.first { $0.kind == runtimeKind }?.executableName ?? runtimeKind.rawValue
        return ([executable] + command).joined(separator: " ")
    }

    var body: some View {
        LazyVStack(spacing: UI.Layout.Spacing.m) {
            UI.Card.Scaffold(size: .small,
                         elevated: false,
                         title: title,
                         subtitle: subtitle) {
                UI.Card.IconChip(symbol: symbol, tint: .accentColor)
            } titleAccessory: {
                EmptyView()
            } subtitleAccessory: {
                EmptyView()
            } headerAccessory: {
                UI.Badge.Text(text: AppText.string("creation.badge.new", defaultValue: "new"), font: .caption2.weight(.semibold))
            } bodyContent: {
                EmptyView()
            } footerLeading: {
                EmptyView()
            } footerActions: {
                EmptyView()
            } widget: {
                EmptyView()
            }

            fields()

            UI.Command.PreviewBar(commandText: commandText,
                              copyHelp: AppText.copyCommand,
                              copiedAccessibilityLabel: AppText.copied)
                .frame(maxWidth: .infinity)

            footer()
        }
    }
}

private struct CreationLocalImageRow: View {
    let image: Core.Image.Resource
    var onSelect: () -> Void

    var body: some View {
        let runnable = image.variants.filter(\.isRunnable)
        let size = runnable.compactMap(\.size).max() ?? image.variants.compactMap(\.size).max()
        let arches = runnable.map(\.platform.architecture).joined(separator: ", ")
        let subtitle = [size.map { Format.bytes(UInt64($0)) }, arches.isEmpty ? nil : arches]
            .compactMap { $0 }.joined(separator: "  ·  ")

        CreationChoiceCard(symbol: "square.stack.3d.up",
                           title: Format.shortImage(image.reference),
                           subtitle: subtitle,
                           action: onSelect)
    }
}

private struct CreationChoiceCard: View {
    let symbol: String
    let title: String
    let subtitle: String?
    var action: () -> Void

    var body: some View {
        UI.Card.Scaffold(size: .small,
                     elevated: false,
                     onTap: action,
                     title: title,
                     subtitle: subtitle,
                     subtitleStyle: .monospaced) {
            UI.Card.IconChip(symbol: symbol, tint: .accentColor)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            UI.List.RowChevron()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
        .contentShape(Rectangle())
    }
}
