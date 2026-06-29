import SwiftUI
import ContainedCore

struct CreationNetworkFields: View {
    @Binding var name: String
    @Binding var subnet: String
    @Binding var internalOnly: Bool
    let working: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection {
                PanelField(label: "Name") {
                    TextField("", text: $name, prompt: Text("my-network")).textFieldStyle(.roundedBorder)
                }
                PanelField(label: "Subnet") {
                    TextField("", text: $subnet, prompt: Text("optional, e.g. 10.0.0.0/24")).textFieldStyle(.roundedBorder)
                }
                PanelToggleRow(title: "Host-only (internal)", isOn: $internalOnly)
            }
            CreationSubmitBar(canSubmit: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                              working: working,
                              action: onSubmit)
        }
    }
}

struct CreationVolumeFields: View {
    @Binding var name: String
    @Binding var size: String
    let working: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection {
                PanelField(label: "Name") {
                    TextField("", text: $name, prompt: Text("my-volume")).textFieldStyle(.roundedBorder)
                }
                PanelField(label: "Size") {
                    TextField("", text: $size, prompt: Text("optional, e.g. 10G")).textFieldStyle(.roundedBorder)
                }
            }
            CreationSubmitBar(canSubmit: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                              working: working,
                              action: onSubmit)
        }
    }
}

struct CreationLocalImagesContent: View {
    @Environment(AppModel.self) private var app
    @Binding var query: String
    var onSelect: (RunSpec) -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Filter local images", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.s)
            .glassSurface(.thin, cornerRadius: Tokens.Radius.control)

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
                            Button {
                                onSelect(RecommendedImage.spec(for: image.reference))
                            } label: {
                                CreationLocalImageRow(image: image)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .task { await app.refreshImagesIfStale(force: true) }
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
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            TextEditor(text: $text)
                .font(.system(.callout, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(Tokens.Space.s)
                .glassSurface(.thin, cornerRadius: Tokens.Radius.control)
                .frame(minHeight: 260)

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

struct CreationImageArchiveContent: View {
    var onSelect: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Choose an image archive", systemImage: "archivebox")
        } description: {
            Text("After loading, choose Local image to configure and run it.")
        } actions: {
            Button(action: onSelect) {
                Label("Select File", systemImage: "folder")
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreationTemplatesContent: View {
    let templates: [Template]
    var onSelect: (RunSpec) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Tokens.Space.s) {
                ForEach(templates) { template in
                    Button {
                        if let spec = template.spec { onSelect(spec) }
                    } label: {
                        CreationChoiceCard(symbol: "bookmark.fill",
                                           title: template.name,
                                           subtitle: Format.shortImage(template.spec?.image ?? "—"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CreationSubmitBar: View {
    let canSubmit: Bool
    let working: Bool
    var action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            if working { ProgressView().controlSize(.small) }
            Button(action: action) {
                Label("Create", systemImage: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .disabled(!canSubmit || working)
        }
        .padding(Tokens.Space.l)
        .background(.clear)
    }
}

private struct CreationLocalImageRow: View {
    let image: ContainedCore.ImageResource

    var body: some View {
        let runnable = image.variants.filter(\.isRunnable)
        let size = runnable.compactMap(\.size).max() ?? image.variants.compactMap(\.size).max()
        let arches = runnable.map(\.platform.architecture).joined(separator: ", ")
        let subtitle = [size.map { Format.bytes(UInt64($0)) }, arches.isEmpty ? nil : arches]
            .compactMap { $0 }.joined(separator: "  ·  ")

        CreationChoiceCard(symbol: "square.stack.3d.up",
                           title: Format.shortImage(image.reference),
                           subtitle: subtitle)
    }
}

private struct CreationChoiceCard: View {
    let symbol: String
    let title: String
    let subtitle: String?

    var body: some View {
        ResourceGlassCard(size: .small, elevated: false) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: symbol, tint: .accentColor)
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: title)
                    if let subtitle, !subtitle.isEmpty {
                        ResourceCardMonospacedSubtitleText(text: subtitle)
                    }
                }
            } trailing: {
                GlassListRowChevron()
            }
        }
    }
}
