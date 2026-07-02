import SwiftUI
import ContainedDesignSystem
import ContainedCore

struct CreationNetworkFields: View {
    @Binding var name: String
    @Binding var subnet: String
    @Binding var internalOnly: Bool
    let working: Bool
    var onSubmit: () -> Void

    var body: some View {
        CreationResourceForm(symbol: "network",
                             title: networkName,
                             subtitle: networkSubtitle,
                             command: previewCommand) {
            PanelSection(header: "Details", highlighted: hasValues) {
                PanelField(label: "Name",
                           info: "A readable name used by containers with `--network`.",
                           error: nameError) {
                    TextField("", text: $name, prompt: Text("my-network"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
                PanelField(label: "Subnet",
                           info: "Optional CIDR range for the network, for example `10.0.0.0/24`.") {
                    TextField("", text: $subnet, prompt: Text("optional, e.g. 10.0.0.0/24"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
                PanelToggleRow(title: "Internal only",
                               subtitle: "Restrict containers on this network from external access.",
                               isOn: $internalOnly)
            }
        } footer: {
            CreationSubmitBar(title: "Create network",
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
    private var nameError: String? { trimmedName.isEmpty ? "A network name is required." : nil }
    private var networkName: String { trimmedName.isEmpty ? "New network" : trimmedName }
    private var networkSubtitle: String {
        var parts = [internalOnly ? "internal" : "bridge"]
        if !trimmedSubnet.isEmpty { parts.append(trimmedSubnet) }
        return parts.joined(separator: "  ·  ")
    }
    private var previewCommand: [String] {
        ContainerCommands.networkCreate(name: trimmedName.isEmpty ? "<name>" : trimmedName,
                                        subnet: trimmedSubnet.isEmpty ? nil : trimmedSubnet,
                                        internalOnly: internalOnly)
    }

    private func submitIfReady() {
        guard canSubmit else { return }
        onSubmit()
    }
}

struct CreationVolumeFields: View {
    @Binding var name: String
    @Binding var size: String
    let working: Bool
    var onSubmit: () -> Void

    var body: some View {
        CreationResourceForm(symbol: "externaldrive",
                             title: volumeName,
                             subtitle: volumeSubtitle,
                             command: previewCommand) {
            PanelSection(header: "Details", highlighted: hasValues) {
                PanelField(label: "Name",
                           info: "A persistent storage name you can mount into containers.",
                           error: nameError) {
                    TextField("", text: $name, prompt: Text("my-volume"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
                PanelField(label: "Size",
                           info: "Optional runtime-specific size hint, such as `10G`. Leave blank for default.") {
                    TextField("", text: $size, prompt: Text("optional, e.g. 10G"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submitIfReady)
                }
            }
        } footer: {
            CreationSubmitBar(title: "Create volume",
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
    private var nameError: String? { trimmedName.isEmpty ? "A volume name is required." : nil }
    private var volumeName: String { trimmedName.isEmpty ? "New volume" : trimmedName }
    private var volumeSubtitle: String { trimmedSize.isEmpty ? "default size" : trimmedSize }
    private var previewCommand: [String] {
        ContainerCommands.volumeCreate(name: trimmedName.isEmpty ? "<name>" : trimmedName,
                                       size: trimmedSize.isEmpty ? nil : trimmedSize)
    }

    private func submitIfReady() {
        guard canSubmit else { return }
        onSubmit()
    }
}

struct CreationLocalImagesContent: View {
    @Environment(AppModel.self) private var app
    @Binding var query: String
    var onSelect: (RunSpec) -> Void

    var body: some View {
        LazyVStack(spacing: Tokens.Space.m) {
            DesignInputSurface {
                HStack(spacing: Tokens.Space.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Filter local images", text: $query)
                        .textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
            }

            if filteredLocalImages.isEmpty {
                ContentUnavailableView {
                    Label("No matching images", systemImage: "square.stack.3d.up")
                } description: {
                    Text(query.isEmpty ? "Pull or build an image first." : "Try a different filter.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.xs) {
                        ForEach(filteredLocalImages) { image in
                            CreationLocalImageRow(image: image) {
                                onSelect(RecommendedImage.spec(for: image.reference))
                            }
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                }
            }
        }
        .task { await app.refreshImagesIfStale() }
    }

    private var filteredLocalImages: [ContainedCore.ImageResource] {
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
        LazyVStack(alignment: .leading, spacing: Tokens.Space.m) {
            DesignInputSurface(horizontalPadding: Tokens.Space.s,
                               verticalPadding: Tokens.Space.s,
                               minHeight: 260) {
                TextEditor(text: $text)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
            }

            HStack {
                Spacer()
                Button(action: onImport) {
                    Label("Import", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.glassProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct CreationTemplatesContent: View {
    let templates: [Template]
    var onSelect: (RunSpec) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Tokens.Space.s) {
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
        HStack(spacing: Tokens.Space.s) {
            Spacer()
            if working { ProgressView().controlSize(.small) }
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.glassProminent)
            .disabled(!canSubmit || working)
        }
        .padding(Tokens.Space.s)
        .background(.clear)
    }
}

private struct CreationResourceForm<Fields: View, Footer: View>: View {
    let symbol: String
    let title: String
    let subtitle: String
    let command: [String]
    @ViewBuilder var fields: () -> Fields
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        LazyVStack(spacing: Tokens.Space.m) {
            ResourceGlassCard(size: .small, elevated: false) {
                ResourceCardHeader {
                    ResourceCardIconChip(symbol: symbol, tint: .accentColor)
                } content: {
                    VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                        ResourceCardTitleText(text: title)
                        ResourceCardSubtitleText(text: subtitle)
                    }
                } trailing: {
                    ResourceBadgeText(text: "new", font: .caption2.weight(.semibold))
                }
            }

            fields()

            CommandPreviewBar(command: command)
                .frame(maxWidth: .infinity)

            footer()
        }
    }
}

private struct CreationLocalImageRow: View {
    let image: ContainedCore.ImageResource
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
        ResourceGlassCard(size: .small, elevated: false, onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: symbol, tint: .accentColor)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                    ResourceCardTitleText(text: title)
                    if let subtitle, !subtitle.isEmpty {
                        ResourceCardMonospacedSubtitleText(text: subtitle)
                    }
                }
        } trailing: {
            GlassListRowChevron()
        }
        .contentShape(Rectangle())
    }
}
}
