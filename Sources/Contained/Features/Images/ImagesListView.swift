import SwiftUI
import AppKit
import ContainedCore

/// Local images: list, inspect, Run, pull (streamed), tag, delete, prune, save/load tar.
struct ImagesListView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var inspecting: ContainedCore.ImageResource?
    @State private var historyFor: ContainedCore.ImageResource?
    @State private var tagging: ContainedCore.ImageResource?
    @State private var pushing: ContainedCore.ImageResource?
    @State private var deleting: ContainedCore.ImageResource?
    @State private var pulling = false
    @State private var pruning = false

    private var images: [ContainedCore.ImageResource] {
        let all = app.images.sorted { $0.reference.localizedCaseInsensitiveCompare($1.reference) == .orderedAscending }
        guard !ui.searchText.isEmpty else { return all }
        return all.filter { $0.reference.localizedCaseInsensitiveContains(ui.searchText) }
    }

    var body: some View {
        Group {
            if let error = app.imagesError, app.images.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't list images", systemImage: "exclamationmark.triangle")
                } description: { Text(error) } actions: {
                    Button("Pull an image") { pulling = true }
                }
            } else {
                ResourceScaffold(isEmpty: images.isEmpty, emptyTitle: "No images",
                                 emptySymbol: "square.stack.3d.up",
                                 emptyMessage: "Pull or build an image to see it here.") {
                    ForEach(images) { image in row(image) }
                }
            }
        }
        .task { await app.refreshResource(.images) }
        .onAppear { consumePending() }
        .onChange(of: ui.pendingAction) { _, _ in consumePending() }
        .sheet(item: $inspecting) { JSONInspectorSheet(title: $0.reference, value: $0) }
        .sheet(item: $historyFor) { ImageHistorySheet(image: $0) }
        .sheet(item: $tagging) { TagImageSheet(source: $0.reference) }
        .sheet(item: $pushing) { PushImageSheet(reference: $0.reference) }
        .sheet(isPresented: $pulling) { PullImageSheet() }
        .confirmationDialog("Delete \(deleting.map { Format.shortImage($0.reference) } ?? "")?",
                            isPresented: deleteBinding, presenting: deleting) { image in
            Button("Delete", role: .destructive) { Task { await delete(image) } }
        } message: { _ in Text("This removes the image from the local store.") }
        .confirmationDialog("Prune images?", isPresented: $pruning) {
            Button("Remove unused", role: .destructive) { Task { await prune(all: false) } }
            Button("Remove all unreferenced", role: .destructive) { Task { await prune(all: true) } }
        } message: {
            Text("Unused images aren't referenced by any container. “All” also removes dangling layers.")
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "tar" }) else { return false }
            loadTar(at: url)
            return true
        }
        // Report the in-page search count so the toolbar can escalate an empty search into the palette.
        .onAppear { ui.pageResultCount = images.count }
        .onChange(of: images.count) { _, count in ui.pageResultCount = count }
    }

    private func row(_ image: ContainedCore.ImageResource) -> some View {
        let runnable = image.variants.filter(\.isRunnable)
        let size = runnable.compactMap(\.size).max() ?? image.variants.compactMap(\.size).max()
        let arches = runnable.map(\.platform.architecture).joined(separator: ", ")
        let style = app.personalization.imageDefault(for: image.reference) ?? Personalization()
        let title = style.displayName(fallback: Format.shortImage(image.reference))
        let subtitle = [size.map { Format.bytes(UInt64($0)) }, arches.isEmpty ? nil : arches]
            .compactMap { $0 }.joined(separator: "  ·  ")
        return HStack(spacing: Tokens.Space.m) {
            ImageStyleButton(image: image, style: style)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: Tokens.Space.s)
            GlassRowMenu { menuItems(image) }
        }
        .padding(Tokens.Space.m)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card,
                      fill: style.fillBackground ? style.color : nil,
                      fillOpacity: style.backgroundOpacity,
                      gradient: style.gradient,
                      gradientAngle: style.gradientAngle)
        .contextMenu { menuItems(image) }
    }

    /// The row's actions — shared by the ⋯ button and the right-click context menu.
    @ViewBuilder
    private func menuItems(_ image: ContainedCore.ImageResource) -> some View {
        Button { ui.runImage(image.reference) } label: { Label("Run…", systemImage: "play") }
        Button { tagging = image } label: { Label("Tag…", systemImage: "tag") }
        Button { pushing = image } label: { Label("Push…", systemImage: "arrow.up.circle") }
        Button { copyToPasteboard(image.reference) } label: { Label("Copy reference", systemImage: "doc.on.doc") }
        Button { inspecting = image } label: { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
        Button { historyFor = image } label: { Label("History", systemImage: "clock.arrow.circlepath") }
        Button { save(image) } label: { Label("Save to tar…", systemImage: "arrow.up.doc") }
        Divider()
        Button(role: .destructive) { deleting = image } label: { Label("Delete", systemImage: "trash") }
    }

    /// Pick up a toolbar/menu action addressed to this page (race-free across the section switch).
    private func consumePending() {
        switch ui.pendingAction {
        case .pullImage:   ui.pendingAction = nil; pulling = true
        case .loadImage:   ui.pendingAction = nil; load()
        case .pruneImages: ui.pendingAction = nil; pruning = true
        default: break
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func delete(_ image: ContainedCore.ImageResource) async {
        guard let client = app.client else { return }
        do { _ = try await client.deleteImages([image.reference]); await app.refreshResource(.images) }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    private func prune(all: Bool) async {
        guard let client = app.client else { return }
        do { _ = try await client.pruneImages(all: all); await app.refreshResource(.images) }
        catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    /// Save an image to an OCI tar archive (NSSavePanel).
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

    /// Load images from a tar archive (NSOpenPanel).
    private func load() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.message = "Choose an image tar archive"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadTar(at: url)
    }

    /// Load images from a tar at `url` (shared by the picker and drag-and-drop).
    private func loadTar(at url: URL) { app.loadImageTar(at: url) }
}
