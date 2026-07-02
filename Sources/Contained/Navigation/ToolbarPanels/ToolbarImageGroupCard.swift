import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import SwiftData
import AppKit
import ContainedCore

struct ToolbarImageGroupCard: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    let group: LocalImageTagGroup
    let isExpanded: Bool
    var onTap: () -> Void
    var onClose: () -> Void

    @State private var deletingReference: String?
    @State private var pruning = false
    /// Detailed image operations (inspect / history / tag / push) now grow the image-detail morph into
    /// a sub-page in place — matching the creation flow — instead of opening modal sheets.
    @State private var page: ImageDetailPage = .root
    @State private var tagTarget = ""
    @State private var tagBusy = false

    enum ImageDetailPage: Equatable {
        case root
        case inspect(String)
        case history(String)
        case tag(String)
        case push(String)
    }

    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    var body: some View {
        Group {
            if isExpanded {
                expandedContent
                    .morphPanelSize(size(for: page))
                    .morphPanelPlacement(.anchored)
                    .animation(spring, value: page)
            } else {
                rootCard
            }
        }
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

    @ViewBuilder
    private var expandedContent: some View {
        switch page {
        case .root:               rootCard
        case .inspect(let ref):   inspectPage(ref)
        case .history(let ref):   historyPage(ref)
        case .tag(let source):    tagPage(source)
        case .push(let ref):      pushPage(ref)
        }
    }

    private var rootCard: some View {
        let image = primaryImage(group)
        let status = app.imageUpdateStatus(for: group.primaryReference)
        let resolved = app.imageGroupStyle(for: group)
        return ResourceGlassCard(size: .medium,
                                 isExpanded: isExpanded,
                                 fill: resolved.fillBackground ? resolved.color : nil,
                                 fillOpacity: resolved.backgroundOpacity,
                                 gradient: resolved.gradient,
                                 gradientAngle: resolved.gradientAngle,
                                 blendMode: resolved.backgroundBlendMode,
                                 elevated: false,
                                 onTap: onTap) {
            cardHeader(group, image: image, style: resolved)
        } bodyContent: {
            tagList(group)
        } footerLeading: {
            HStack(spacing: Tokens.ResourceCard.padding) {
                imageFooterTagCount(group)
                imageFooterInfo(status)
            }
        } footerActions: {
            imageFooterActions(group)
        }
        .contextMenu { cardMenu(group) }
    }

    // MARK: Detail sub-pages

    private func size(for page: ImageDetailPage) -> CGSize {
        switch page {
        case .root:    return Tokens.PanelSize.imageDetail
        case .inspect, .history: return Tokens.SheetSize.inspector
        case .tag:     return Tokens.PanelSize.imageTag
        case .push:    return Tokens.SheetSize.console
        }
    }

    private func subPageScaffold<C: View>(symbol: String, title: String, subtitle: String?,
                                          @ViewBuilder content: @escaping () -> C) -> some View {
        ResourceGlassCard(size: .medium,
                          isExpanded: true,
                          showsFooter: false,
                          elevated: false) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: symbol, tint: .accentColor)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                    ResourceCardTitleText(text: title)
                    if let subtitle {
                        ResourceCardMonospacedSubtitleText(text: subtitle)
                    }
                }
            } trailing: {
                GlassButton(singleItem: false) {
                    GlassButtonItem(systemName: "chevron.left", help: "Back") {
                        withAnimation(spring) { page = .root }
                    }
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                }
            }
        } bodyContent: {
            content()
                .padding(Tokens.Space.s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
    }

    private func inspectPage(_ reference: String) -> some View {
        let image = group.images.first { $0.reference == reference } ?? primaryImage(group)
        return subPageScaffold(symbol: "doc.text.magnifyingglass", title: "Inspect",
                               subtitle: Format.shortImage(reference)) {
            if let image {
                InlineJSONView(json: prettyJSON(image))
            } else {
                ContentUnavailableView("Unavailable", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    private func historyPage(_ reference: String) -> some View {
        let image = group.images.first { $0.reference == reference } ?? primaryImage(group)
        let variant = image?.variants.first(where: \.isRunnable) ?? image?.variants.first
        let history = variant?.config?.history ?? []
        return subPageScaffold(symbol: "clock.arrow.circlepath", title: "History",
                               subtitle: Format.shortImage(reference)) {
            if history.isEmpty {
                ContentUnavailableView("No history", systemImage: "clock",
                                       description: Text("This image records no layer history."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                        ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                            LazyVStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                                Text(entry.createdBy ?? entry.comment ?? "—")
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let created = entry.created {
                                    Text(created.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(Tokens.Space.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .subtleTileBackground()
                        }
                    }
                    .padding(Tokens.Space.s)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
        }
    }

    private func tagPage(_ source: String) -> some View {
        subPageScaffold(symbol: "tag", title: "Add tag", subtitle: Format.shortImage(source)) {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.l) {
                PanelSection {
                    PanelField(label: "Source") {
                        Text(Format.shortImage(source)).foregroundStyle(.secondary)
                    }
                    PanelField(label: "New reference") {
                        TextField("", text: $tagTarget, prompt: Text("e.g. myrepo/app:v1"))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { submitTag(source: source) }
                    }
                }
                HStack {
                    Spacer()
                    if tagBusy { ProgressView().controlSize(.small) }
                    Button { submitTag(source: source) } label: { Label("Add Tag", systemImage: "checkmark") }
                        .buttonStyle(.glassProminent)
                        .disabled(tagTarget.trimmingCharacters(in: .whitespaces).isEmpty || tagBusy)
                }
            }
        }
    }

    private func pushPage(_ reference: String) -> some View {
        subPageScaffold(symbol: "arrow.up.circle", title: "Push image",
                        subtitle: Format.shortImage(reference)) {
            if let client = app.client {
                StreamConsole(stream: { client.streamPush(reference) })
            } else {
                ContentUnavailableView("Runtime unavailable", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func submitTag(source: String) {
        guard let client = app.client else { return }
        let target = tagTarget.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        tagBusy = true
        Task {
            do {
                _ = try await client.tagImage(source: source, target: target)
                await app.refreshImagesIfStale(force: true)
                tagBusy = false
                tagTarget = ""
                withAnimation(spring) { page = .root }
            } catch let error as CommandError {
                app.flash(error.userMessage); tagBusy = false
            } catch {
                app.flash(error.localizedDescription); tagBusy = false
            }
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
            VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
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
            if isExpanded {
                footerAction("tag", help: "Add Tag") { withAnimation(spring) { page = .tag(image.reference) } }
                footerAction("arrow.up.circle", help: "Push") { withAnimation(spring) { page = .push(image.reference) } }
            }
            footerAction("arrow.up.doc", help: "Save") { save(image) }
        }
        footerAction("trash", help: "Prune", role: .destructive) { pruning = true }
    }

    private func tagList(_ group: LocalImageTagGroup) -> some View {
        LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text("Tags")
                .font(.headline)
                .padding(.leading, Tokens.Space.xs)
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
                                 blendMode: style.backgroundBlendMode,
                                 elevated: false) {
            ResourceCardHeader {
                ImageStyleButton(reference: reference,
                                 style: style,
                                 target: .imageTag(reference: reference, groupID: group.id))
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                    ResourceCardMonospacedTitleText(text: Format.shortImage(reference))
                    ResourceCardSubtitleText(text: repositoryName(reference))
                }
            } trailing: {
                EmptyView()
            }
        } footerLeading: {
            ResourceCardFooterMini {
                Image(systemName: "tag").font(.caption2)
            } text: {
                ResourceCardMetricText(text: "Local tag")
            }
        } footerActions: {
            footerAction("play", help: "Run") {
                ui.runImage(reference)
                if isExpanded { onClose() }
            }
            footerAction("doc.on.doc", help: "Copy reference") { copyToPasteboard(reference) }
            footerAction("doc.text.magnifyingglass", help: "Inspect") { inspect(reference, in: group) }
            footerAction("trash", help: "Delete tag", role: .destructive) { deletingReference = reference }
        }
        .contextMenu { tagMenu(reference, in: group) }
    }

    /// Right-click actions for a single tag — mirrors the footer buttons so the row is consistent with
    /// the group card (which has its own context menu).
    @ViewBuilder
    private func tagMenu(_ reference: String, in group: LocalImageTagGroup) -> some View {
        Button { ui.runImage(reference); if isExpanded { onClose() } } label: { Label("Run…", systemImage: "play") }
        Button { copyToPasteboard(reference) } label: { Label("Copy reference", systemImage: "doc.on.doc") }
        Button { inspect(reference, in: group) } label: { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
        Divider()
        Button(role: .destructive) { deletingReference = reference } label: { Label("Delete tag", systemImage: "trash") }
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              role: ButtonRole? = nil,
                              action: @escaping () -> Void) -> some View {
        ResourceCardFooterButton(systemName: systemName,
                                 help: help,
                                 tint: tint,
                                 role: role,
                                 action: action)
    }

    @ViewBuilder
    private func cardMenu(_ group: LocalImageTagGroup) -> some View {
        Button { ui.runImage(group.primaryReference) } label: { Label("Run…", systemImage: "play") }
        if let image = primaryImage(group) {
            // Inspect / History / Tag / Push grow the detail morph into a sub-page, so they're offered
            // only from the expanded detail (a collapsed card opens the detail first).
            if isExpanded {
                Button { withAnimation(spring) { page = .tag(image.reference) } } label: { Label("Add Tag…", systemImage: "tag") }
                Button { withAnimation(spring) { page = .push(image.reference) } } label: { Label("Push…", systemImage: "arrow.up.circle") }
                Button { withAnimation(spring) { page = .inspect(image.reference) } } label: { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
                Button { withAnimation(spring) { page = .history(image.reference) } } label: { Label("History", systemImage: "clock.arrow.circlepath") }
            } else {
                Button(action: onTap) { Label("Show Details…", systemImage: "rectangle.expand.vertical") }
            }
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
        withAnimation(spring) { page = .inspect(reference) }
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
