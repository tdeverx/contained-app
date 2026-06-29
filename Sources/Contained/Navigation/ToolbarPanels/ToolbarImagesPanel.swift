import SwiftUI
import SwiftData
import AppKit
import ContainedCore

struct ToolbarUpdatesPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var onOpenImage: (LocalImageTagGroup, CGRect) -> Void
    var onClose: () -> Void
    @State private var imageFrames: [LocalImageTagGroup.ID: CGRect] = [:]

    private var imageGroups: [LocalImageTagGroup] {
        LocalImageTagGroup.groups(for: app.images).sorted { lhs, rhs in
            let lhsRank = imageRank(lhs)
            let rhsRank = imageRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.primaryReference.localizedCaseInsensitiveCompare(rhs.primaryReference) == .orderedAscending
        }
    }

    private var updateCount: Int {
        imageGroups.filter { app.imageUpdateStatus(for: $0.primaryReference).state == .updateAvailable }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                    if imageGroups.isEmpty {
                        emptyCard
                    } else {
                        ForEach(imageGroups) { group in
                            imageRow(group)
                        }
                    }
                }
                .padding(Tokens.Space.m)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .morphPanelSize(Tokens.PanelSize.images)
        .morphPanelPlacement(.anchored)
        .task { await app.refreshImagesIfStale(force: true) }
    }

    private var header: some View {
        PanelHeader(symbol: "square.stack.3d.up",
                    title: "Images",
                    subtitle: "\(imageGroups.count) local · \(updateCount) update\(updateCount == 1 ? "" : "s")",
                    padding: Tokens.Space.m) {
            GlassButton {
                GlassButtonItem(systemName: "square.and.arrow.down", help: "Load Image Tar") {
                    ui.dispatch(.loadImage)
                    onClose()
                }
                GlassButtonItem(systemName: "arrow.triangle.2.circlepath", help: "Check for Updates") {
                    Task { await app.runImageUpdateSweepNow() }
                }
                GlassButtonItem(systemName: "trash", help: "Prune Images") {
                    ui.dispatch(.pruneImages)
                    onClose()
                }
                GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
            }
        }
    }

    private var emptyCard: some View {
        ResourceGlassCard(size: .small, elevated: false) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: "checkmark.circle.fill", tint: .green)
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: "No images")
                    ResourceCardSubtitleText(text: "Pull or build an image to see it here")
                }
            } trailing: {
                EmptyView()
            }
        }
    }

    private func imageRow(_ group: LocalImageTagGroup) -> some View {
        ToolbarImageGroupCard(group: group,
                              isExpanded: false,
                              onTap: {
                                  onOpenImage(group, imageFrames[group.id] ?? .zero)
                              },
                              onClose: {})
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            imageFrames[group.id] = proxy.frame(in: .named(AppToolbar.space))
                        }
                        .onChange(of: proxy.frame(in: .named(AppToolbar.space))) { _, frame in
                            imageFrames[group.id] = frame
                        }
                }
            }
    }

    private func imageRank(_ group: LocalImageTagGroup) -> Int {
        switch app.imageUpdateStatus(for: group.primaryReference).state {
        case .updateAvailable: return 0
        case .error: return 1
        case .checking: return 2
        case .unknown: return 3
        case .current: return 4
        }
    }

}

struct ToolbarImageGroupCard: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    let group: LocalImageTagGroup
    let isExpanded: Bool
    var onTap: () -> Void
    var onClose: () -> Void

    @State private var inspecting: ContainedCore.ImageResource?
    @State private var historyFor: ContainedCore.ImageResource?
    @State private var tagging: ContainedCore.ImageResource?
    @State private var pushing: ContainedCore.ImageResource?
    @State private var deletingReference: String?
    @State private var pruning = false

    var body: some View {
        let image = primaryImage(group)
        let status = app.imageUpdateStatus(for: group.primaryReference)
        let resolved = app.imageGroupStyle(for: group)
        ResourceGlassCard(size: .medium,
                          isExpanded: isExpanded,
                          fill: resolved.fillBackground ? resolved.color : nil,
                          fillOpacity: resolved.backgroundOpacity,
                          gradient: resolved.gradient,
                          gradientAngle: resolved.gradientAngle,
                          elevated: false,
                          onTap: onTap) {
            cardHeader(group, image: image, style: resolved)
            } bodyContent: {
            tagList(group)
        } footerLeading: {
            HStack(spacing: 10) {
                imageFooterTagCount(group)
                imageFooterInfo(status)
            }
        } footerActions: {
            imageFooterActions(group)
        }
        .contextMenu { cardMenu(group) }
        .sheet(item: $inspecting) { JSONInspectorSheet(title: $0.reference, value: $0) }
        .sheet(item: $historyFor) { ImageHistorySheet(image: $0) }
        .sheet(item: $tagging) { TagImageSheet(source: $0.reference) }
        .sheet(item: $pushing) { PushImageSheet(reference: $0.reference) }
        .confirmationDialog("Delete \(Format.shortImage(deletingReference ?? ""))?",
                            isPresented: deletingBinding,
                            presenting: deletingReference) { reference in
            Button("Delete", role: .destructive) { Task { await delete(reference) } }
        } message: { _ in Text("This removes the selected local image reference.") }
        .confirmationDialog("Prune images?", isPresented: $pruning) {
            Button("Remove unused", role: .destructive) { Task { await prune(all: false) } }
            Button("Remove all unreferenced", role: .destructive) { Task { await prune(all: true) } }
        } message: {
            Text("Unused images aren't referenced by any container. “All” also removes dangling layers.")
        }
    }

    private func cardHeader(_ group: LocalImageTagGroup, image: ContainedCore.ImageResource?,
                            style: Personalization) -> some View {
        ResourceCardHeader {
            if let image {
                ImageStyleButton(reference: image.reference,
                                 style: style,
                                 target: .imageGroup(id: group.id, reference: group.primaryReference))
            } else {
                imageChip(style)
            }
        } content: {
            VStack(alignment: .leading, spacing: 1) {
                ResourceCardTitleText(text: repositoryTitle(group.primaryReference))
                ResourceCardSubtitleText(text: repositoryOwner(group.primaryReference))
            }
        } trailing: {
            if isExpanded {
                GlassButton(singleItem: true) {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                }
            } else {
                EmptyView()
            }
        }
    }

    private func imageFooterInfo(_ status: ImageUpdateStatus) -> some View {
        ResourceCardFooterMini {
            Image(systemName: updateSymbol(status.state))
                .font(.caption)
                .foregroundStyle(updateTint(status.state))
        } text: {
            ResourceCardSubtitleText(text: updateFooterText(status))
        }
    }

    private func imageFooterTagCount(_ group: LocalImageTagGroup) -> some View {
        ResourceCardFooterMini {
            Image(systemName: "tag")
                .font(.caption)
                .foregroundStyle(.secondary)
        } text: {
            ResourceCardMetricText(text: "\(group.references.count)")
        }
    }

    @ViewBuilder
    private func imageFooterActions(_ group: LocalImageTagGroup) -> some View {
        footerAction("play", help: "Run") {
            ui.runImage(group.primaryReference)
            if isExpanded { onClose() }
        }
        footerAction("arrow.triangle.2.circlepath", help: "Check for Updates") {
            Task { await app.checkImageUpdate(group.primaryReference) }
        }
        if app.imageUpdateStatus(for: group.primaryReference).state == .updateAvailable {
            footerAction("arrow.down.circle", help: "Pull Update", tint: .orange) {
                Task { await app.pullImageUpdate(group.primaryReference) }
            }
        }
        if let image = primaryImage(group) {
            footerAction("tag", help: "Add Tag") { tagging = image }
            footerAction("arrow.up.circle", help: "Push") { pushing = image }
            footerAction("arrow.up.doc", help: "Save") { save(image) }
        }
        footerAction("trash", help: "Prune", tint: .red) { pruning = true }
    }

    private func tagList(_ group: LocalImageTagGroup) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Tags").font(.headline)
            ScrollView(.vertical) {
                LazyVStack(spacing: Tokens.Space.s) {
                    ForEach(group.references, id: \.self) { reference in
                        tagRow(reference, in: group)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Tokens.Space.s)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }

    private func tagRow(_ reference: String, in group: LocalImageTagGroup) -> some View {
        let style = app.imageStyle(for: reference)
        return ResourceGlassCard(size: .medium,
                                 fill: style.fillBackground ? style.color : nil,
                                 fillOpacity: style.backgroundOpacity,
                                 gradient: style.gradient,
                                 gradientAngle: style.gradientAngle,
                                 elevated: false) {
            HStack(spacing: Tokens.Space.s) {
                ImageStyleButton(reference: reference,
                                 style: style,
                                 target: .imageTag(reference: reference, groupID: group.id))
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardMonospacedTitleText(text: Format.shortImage(reference))
                    ResourceCardSubtitleText(text: repositoryName(reference))
                }
            }
        } footerLeading: {
            Text("Local tag")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footerActions: {
            footerAction("play", help: "Run") {
                ui.runImage(reference)
                if isExpanded { onClose() }
            }
            footerAction("doc.on.doc", help: "Copy reference") { copyToPasteboard(reference) }
            footerAction("doc.text.magnifyingglass", help: "Inspect") { inspect(reference, in: group) }
            footerAction("trash", help: "Delete tag", tint: .red) { deletingReference = reference }
        }
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ResourceCardFooterMini {
                Image(systemName: systemName).font(.body)
            } text: {
                EmptyView()
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint ?? .secondary)
        .help(help)
        .accessibilityLabel(help)
    }

    @ViewBuilder
    private func cardMenu(_ group: LocalImageTagGroup) -> some View {
        Button { ui.runImage(group.primaryReference) } label: { Label("Run…", systemImage: "play") }
        if let image = primaryImage(group) {
            Button { tagging = image } label: { Label("Add Tag…", systemImage: "tag") }
            Button { pushing = image } label: { Label("Push…", systemImage: "arrow.up.circle") }
            Button { inspecting = image } label: { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
            Button { historyFor = image } label: { Label("History", systemImage: "clock.arrow.circlepath") }
            Button { save(image) } label: { Label("Save to tar…", systemImage: "arrow.up.doc") }
        }
        Divider()
        Button { Task { await app.checkImageUpdate(group.primaryReference) } } label: {
            Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
        }
        if app.imageUpdateStatus(for: group.primaryReference).state == .updateAvailable {
            Button { Task { await app.pullImageUpdate(group.primaryReference) } } label: {
                Label("Pull Update", systemImage: "arrow.down.circle")
            }
        }
        Divider()
        Button(role: .destructive) { deletingReference = group.primaryReference } label: {
            Label("Delete Primary Tag", systemImage: "trash")
        }
    }

    private func imageChip(_ style: Personalization) -> some View {
        ResourceCardIconChip(symbol: style.symbol, tint: style.color)
    }

    private func updateSymbol(_ state: ImageUpdateState) -> String {
        switch state {
        case .unknown: return "questionmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .current: return "checkmark.circle.fill"
        case .updateAvailable: return "arrow.down.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func updateTint(_ state: ImageUpdateState) -> Color {
        switch state {
        case .current: return .green
        case .updateAvailable, .error: return .orange
        case .checking: return .blue
        case .unknown: return .secondary
        }
    }

    private func repositoryName(_ reference: String) -> String {
        let parsed = RegistryImageReference.parse(reference)
        if parsed.registry == "registry-1.docker.io", parsed.repository.hasPrefix("library/") {
            return String(parsed.repository.dropFirst("library/".count))
        }
        return parsed.repository
    }

    private func repositoryTitle(_ reference: String) -> String {
        let parsed = RegistryImageReference.parse(reference)
        return parsed.repository.split(separator: "/").map(String.init).last ?? parsed.repository
    }

    private func repositoryOwner(_ reference: String) -> String {
        let parsed = RegistryImageReference.parse(reference)
        let parts = parsed.repository.split(separator: "/").map(String.init)
        if parts.count > 1 {
            return parts.dropLast().joined(separator: "/")
        }
        return parsed.registry == "registry-1.docker.io" ? "docker.io" : parsed.registry
    }

    private func updateFooterText(_ status: ImageUpdateStatus) -> String {
        switch status.state {
        case .unknown: return "Not checked"
        case .checking: return "Checking"
        case .current: return "Up to date"
        case .updateAvailable: return "Updates available"
        case .error: return "Check failed"
        }
    }

    private func primaryImage(_ group: LocalImageTagGroup) -> ContainedCore.ImageResource? {
        group.images.first { $0.reference == group.primaryReference } ?? group.images.first
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deletingReference != nil }, set: { if !$0 { deletingReference = nil } })
    }

    private func inspect(_ reference: String, in group: LocalImageTagGroup) {
        inspecting = group.images.first { $0.reference == reference }
    }

    private func delete(_ reference: String) async {
        guard let client = app.client else { return }
        do {
            _ = try await client.deleteImages([reference])
            await app.refreshImagesIfStale(force: true)
            app.flash("Deleted \(Format.shortImage(reference))")
            deletingReference = nil
        } catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    private func prune(all: Bool) async {
        guard let client = app.client else { return }
        do { _ = try await client.pruneImages(all: all); await app.refreshImagesIfStale(force: true) }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    private func save(_ image: ContainedCore.ImageResource) {
        guard let client = app.client else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.nameFieldStringValue = Format.shortImage(image.reference).replacingOccurrences(of: ":", with: "_") + ".tar"
        panel.message = "Save \(Format.shortImage(image.reference)) to a tar archive"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            if let error = await app.captured({ _ = try await client.saveImages([image.reference], to: url.path) }) {
                app.flash(error)
            } else {
                app.flash("Saved \(url.lastPathComponent)")
            }
        }
    }

}
