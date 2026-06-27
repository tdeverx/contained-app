import SwiftUI
import AppKit
import ContainedCore

/// Local images as expandable glass cards. Each card groups local tags that point at the same
/// image digest/id; expanding exposes tag actions, update checks, pull/update, inspect, push, save,
/// and delete without leaving the Images page.
struct ImagesListView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    @State private var detail: LocalImageTagGroup?
    @State private var expanded = false
    @State private var cardFrames: [String: CGRect] = [:]
    @State private var inspecting: ContainedCore.ImageResource?
    @State private var historyFor: ContainedCore.ImageResource?
    @State private var tagging: ContainedCore.ImageResource?
    @State private var pushing: ContainedCore.ImageResource?
    @State private var deletingReference: String?
    @State private var pruning = false

    private let detailSpring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    private var groups: [LocalImageTagGroup] {
        let all = LocalImageTagGroup.groups(for: app.images)
        let q = ui.searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { group in
            group.references.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        GeometryReader { viewport in
            ZStack {
                content(viewport: viewport)
                    .disabled(detail != nil)
                    .blur(radius: expanded ? 8 : 0)

                if detail != nil {
                    Rectangle()
                        .fill(.black.opacity(expanded ? 0.28 : 0))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { closeDetail() }
                        .zIndex(5)
                }

                if let detail {
                    let current = currentGroup(detail)
                    let target = panelRect(in: viewport.size)
                    let source = cardFrames[current.id].flatMap { $0.isUsableForImageMorph ? $0 : nil } ?? target
                    let rect = expanded ? target : source
                    ZStack {
                        ExteriorShadow(cornerRadius: Tokens.Radius.card,
                                       color: .black.opacity(0.16), radius: 60, y: 26)
                        imageCard(current, isExpanded: true)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .zIndex(10)
                }
            }
            .coordinateSpace(.named("image-grid"))
            .onPreferenceChange(ImageCardFrameKey.self) { cardFrames = $0 }
        }
        .task { await app.refreshResource(.images) }
        .onAppear { consumePending(); ui.pageResultCount = groups.count }
        .onChange(of: ui.pendingAction) { _, _ in consumePending() }
        .onChange(of: groups.count) { _, count in ui.pageResultCount = count }
        .sheet(item: $inspecting) { JSONInspectorSheet(title: $0.reference, value: $0) }
        .sheet(item: $historyFor) { ImageHistorySheet(image: $0) }
        .sheet(item: $tagging) { TagImageSheet(source: $0.reference) }
        .sheet(item: $pushing) { PushImageSheet(reference: $0.reference) }
        .confirmationDialog("Delete \(Format.shortImage(deletingReference ?? ""))?",
                            isPresented: deletingBinding, presenting: deletingReference) { reference in
            Button("Delete", role: .destructive) { Task { await delete(reference) } }
        } message: { _ in Text("This removes the selected local image reference.") }
        .confirmationDialog("Prune images?", isPresented: $pruning) {
            Button("Remove unused", role: .destructive) { Task { await prune(all: false) } }
            Button("Remove all unreferenced", role: .destructive) { Task { await prune(all: true) } }
        } message: {
            Text("Unused images aren't referenced by any container. “All” also removes dangling layers.")
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "tar" }) else { return false }
            app.loadImageTar(at: url)
            return true
        }
    }

    @ViewBuilder
    private func content(viewport: GeometryProxy) -> some View {
        if let error = app.imagesError, app.images.isEmpty {
            ContentUnavailableView {
                Label("Couldn't list images", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Pull an image") { ui.dispatch(.pullImage) }
            }
        } else if groups.isEmpty {
            ContentUnavailableView {
                Label("No images", systemImage: "square.stack.3d.up")
            } description: {
                Text(ui.searchText.isEmpty ? "Pull or build an image to see it here." : "No images match this search.")
            } actions: {
                Button("Pull an image") { ui.dispatch(.pullImage) }
            }
        } else {
            ScrollView {
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: viewport.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { zoomFrontWindow() }
                    LazyVStack(spacing: Tokens.Space.m) {
                        ForEach(groups) { group in
                            let selected = detail?.id == group.id
                            imageCard(group, isExpanded: false)
                                .opacity(selected ? 0 : 1)
                                .allowsHitTesting(detail == nil)
                                .frame(maxWidth: .infinity)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: ImageCardFrameKey.self,
                                            value: [group.id: proxy.frame(in: .named("image-grid"))]
                                        )
                                    }
                                )
                        }
                    }
                    .padding(Tokens.Space.l)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        Task { await app.checkAllImageUpdates(manual: true) }
                    } label: {
                        Label("Check Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, Tokens.Space.l)
                .padding(.bottom, Tokens.Space.l)
            }
        }
    }

    private func imageCard(_ group: LocalImageTagGroup, isExpanded: Bool) -> some View {
        let image = primaryImage(group)
        let style = image.map { app.personalization.imageDefault(for: $0.reference) } ?? nil
        let resolved = style ?? Personalization()
        let status = app.imageUpdateStatus(for: group.primaryReference)
        return ResourceGlassCard(size: .medium,
                                 isExpanded: isExpanded,
                                 fill: resolved.fillBackground ? resolved.color : nil,
                                 fillOpacity: resolved.backgroundOpacity,
                                 gradient: resolved.gradient,
                                 gradientAngle: resolved.gradientAngle,
                                 onTap: { openDetail(group) }) {
            cardHeader(group, image: image, style: resolved, isExpanded: isExpanded)
        } bodyContent: {
            imageDetailBody(group, image: image, status: status)
        } footerLeading: {
            imageFooterInfo(status)
        } footerActions: {
            imageFooterActions(group)
        } widget: {
            updatePanel(status)
        }
        .contextMenu { cardMenu(group) }
    }

    private func cardHeader(_ group: LocalImageTagGroup, image: ContainedCore.ImageResource?,
                            style: Personalization, isExpanded: Bool) -> some View {
        HStack(spacing: Tokens.Space.s) {
            if let image {
                ImageStyleButton(image: image, style: style)
            } else {
                Image(systemName: style.symbol)
                    .foregroundStyle(style.color)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(repositoryName(group.primaryReference))
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text("\(group.references.count) tag\(group.references.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isExpanded {
                GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true) { closeDetail() }
            }
        }
    }

    private func imageFooterInfo(_ status: ImageUpdateStatus) -> some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: updateSymbol(status.state))
                .font(.caption)
                .foregroundStyle(updateTint(status.state))
            Text(updateFooterText(status))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func imageDetailBody(_ group: LocalImageTagGroup, image: ContainedCore.ImageResource?,
                                 status: ImageUpdateStatus) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.m) {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                if let image {
                    detailInfoCard(title: "Image", value: imageSubtitle(image), symbol: "info.circle")
                }
                detailInfoCard(title: "References",
                               value: "\(group.references.count) local tag\(group.references.count == 1 ? "" : "s")",
                               symbol: "tag")
                tagList(group)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            detailUpdateCard(group, status: status)
                .frame(width: 260)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func detailInfoCard(title: String, value: String, symbol: String) -> some View {
        ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func detailUpdateCard(_ group: LocalImageTagGroup, status: ImageUpdateStatus) -> some View {
        ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: updateSymbol(status.state))
                    .foregroundStyle(updateTint(status.state))
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(updateTint(status.state).opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(updateTitle(status))
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(updateDetail(status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if status.state == .updateAvailable {
                    GlassCircleButton(systemName: "arrow.down", help: "Pull Update") {
                        Task { await app.pullImageUpdate(group.primaryReference) }
                    }
                }
            }
        }
    }

    private func tagList(_ group: LocalImageTagGroup) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Tags").font(.headline)
            ScrollView {
                LazyVStack(spacing: Tokens.Space.s) {
                    ForEach(group.references, id: \.self) { reference in
                        tagRow(reference, in: group)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func imageFooterActions(_ group: LocalImageTagGroup) -> some View {
        HStack(spacing: Tokens.Space.m) {
            footerAction("play", help: "Run") { ui.runImage(group.primaryReference); closeDetail() }
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
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint ?? .secondary)
        .help(help)
        .accessibilityLabel(help)
    }

    private func updatePanel(_ status: ImageUpdateStatus) -> some View {
        ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: updateSymbol(status.state))
                    .font(.system(size: 14))
                    .foregroundStyle(updateTint(status.state))
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(updateTint(status.state).opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(updateTitle(status)).font(.callout.weight(.medium)).lineLimit(1)
                    Text(updateDetail(status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func tagRow(_ reference: String, in group: LocalImageTagGroup) -> some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "tag.fill").foregroundStyle(Color.accentColor).frame(width: 18)
            Text(Format.shortImage(reference))
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button { ui.runImage(reference); closeDetail() } label: { Image(systemName: "play") }
                .help("Run")
            Button { copyToPasteboard(reference) } label: { Image(systemName: "doc.on.doc") }
                .help("Copy reference")
            Button { inspect(reference, in: group) } label: { Image(systemName: "doc.text.magnifyingglass") }
                .help("Inspect")
            Button(role: .destructive) { deletingReference = reference } label: { Image(systemName: "trash") }
                .help("Delete tag")
        }
        .buttonStyle(.glass)
        .padding(Tokens.Space.s)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
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

    private func updateTitle(_ status: ImageUpdateStatus) -> String {
        switch status.state {
        case .unknown: return "Not checked"
        case .checking: return "Checking for updates"
        case .current: return "Up to date"
        case .updateAvailable: return "Update available"
        case .error: return "Update check failed"
        }
    }

    private func updateDetail(_ status: ImageUpdateStatus) -> String {
        if let message = status.message { return message }
        if let checkedAt = status.checkedAt {
            return "Checked \(checkedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Compare the local digest with the registry manifest."
    }

    private func updateFooterText(_ status: ImageUpdateStatus) -> String {
        switch status.state {
        case .unknown: return "Not checked"
        case .checking: return "Checking"
        case .current: return "Up to date"
        case .updateAvailable: return "Update available"
        case .error: return "Check failed"
        }
    }

    private func currentGroup(_ group: LocalImageTagGroup) -> LocalImageTagGroup {
        groups.first { $0.id == group.id } ?? group
    }

    private func primaryImage(_ group: LocalImageTagGroup) -> ContainedCore.ImageResource? {
        group.images.first { $0.reference == group.primaryReference } ?? group.images.first
    }

    private func repositoryName(_ reference: String) -> String {
        let parsed = RegistryImageReference.parse(reference)
        if parsed.registry == "registry-1.docker.io", parsed.repository.hasPrefix("library/") {
            return String(parsed.repository.dropFirst("library/".count))
        }
        return parsed.repository
    }

    private func imageSubtitle(_ image: ContainedCore.ImageResource) -> String {
        let runnable = image.variants.filter(\.isRunnable)
        let size = runnable.compactMap(\.size).max() ?? image.variants.compactMap(\.size).max()
        let arches = runnable.map(\.platform.architecture).joined(separator: ", ")
        return [size.map { Format.bytes(UInt64($0)) }, arches.isEmpty ? nil : arches]
            .compactMap { $0 }.joined(separator: "  ·  ")
    }

    private func openDetail(_ group: LocalImageTagGroup) {
        detail = group
        expanded = false
        DispatchQueue.main.async {
            withAnimation(detailSpring) { expanded = true }
        }
    }

    private func closeDetail() {
        withAnimation(detailSpring) { expanded = false } completion: {
            detail = nil
        }
    }

    private func panelSize(in viewport: CGSize) -> CGSize {
        let fitted = MorphGeometry.fittedSize(
            CGSize(width: max(viewport.width * 0.58, 640), height: 560),
            in: viewport,
            margin: Tokens.Space.xxl
        )
        return CGSize(width: max(min(fitted.width, viewport.width - Tokens.Space.xxl * 2), min(360, fitted.width)),
                      height: max(min(fitted.height, viewport.height - Tokens.Space.xxl * 2), min(420, fitted.height)))
    }

    private func panelRect(in viewport: CGSize) -> CGRect {
        MorphGeometry.targetRect(origin: .zero,
                                 proposedSize: panelSize(in: viewport),
                                 container: viewport,
                                 placement: .centered,
                                 margin: Tokens.Space.xxl)
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deletingReference != nil }, set: { if !$0 { deletingReference = nil } })
    }

    private func consumePending() {
        switch ui.pendingAction {
        case .loadImage: ui.pendingAction = nil; load()
        case .pruneImages: ui.pendingAction = nil; pruning = true
        default: break
        }
    }

    private func inspect(_ reference: String, in group: LocalImageTagGroup) {
        inspecting = group.images.first { $0.reference == reference }
    }

    private func delete(_ reference: String) async {
        guard let client = app.client else { return }
        do {
            _ = try await client.deleteImages([reference])
            await app.refreshResource(.images)
            app.flash("Deleted \(Format.shortImage(reference))")
            deletingReference = nil
        } catch let error as CommandError { app.flash(error.userMessage) }
        catch { app.flash(error.localizedDescription) }
    }

    private func prune(all: Bool) async {
        guard let client = app.client else { return }
        do { _ = try await client.pruneImages(all: all); await app.refreshResource(.images) }
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

    private func load() {
        guard let url = chooseTarURL() else { return }
        app.loadImageTar(at: url)
    }

    private func chooseTarURL() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.message = "Choose an image tar archive"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func zoomFrontWindow() {
        (NSApp.keyWindow ?? NSApp.mainWindow)?.zoom(nil)
    }
}

private struct ImageCardFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private extension CGRect {
    var isUsableForImageMorph: Bool {
        width.isFinite && height.isFinite && minX.isFinite && minY.isFinite && width > 1 && height > 1
    }
}
