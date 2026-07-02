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
    /// Detailed image pages grow the image-detail morph in place, matching container cards: tags are
    /// the default body page, while history/tag/push reuse the same card shell.
    @State private var page: ImageDetailPage = .tags
    @State private var tagTarget = ""
    @State private var tagBusy = false
    @State private var confirmingPushReference: String?
    @State private var pushStartedReference: String?

    enum ImageDetailPage: Hashable {
        case tags
        case history(String)
        case tag(String)
        case push(String)
    }

    private enum PushAction {
        case push
        case openRegistries
        case tag
        case none
    }

    private struct PushState {
        var title: String
        var message: String
        var detail: String?
        var symbol: String
        var tint: Color
        var action: PushAction
    }

    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    var body: some View {
        Group {
            if isExpanded {
                rootCard
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
        .confirmationDialog("Push \(Format.shortImage(confirmingPushReference ?? ""))?",
                            isPresented: pushConfirmationBinding,
                            presenting: confirmingPushReference) { reference in
            Button("Push", role: .none) {
                pushStartedReference = reference
            }
        } message: { reference in
            Text("This publishes \(Format.shortImage(reference)) to its registry. The registry may still reject the push if your account cannot write to that repository.")
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
            imageBody(group)
        } footerLeading: {
            imageFooterTagCount(group)
            imageFooterInfo(status)
        } footerActions: {
            imageFooterActions(group)
        }
        .contextMenu { cardMenu(group) }
    }

    // MARK: Detail sub-pages

    @ViewBuilder
    private func imageBody(_ group: LocalImageTagGroup) -> some View {
        if !isExpanded {
            tagList(group)
        } else {
            switch page {
            case .tags:
                tagList(group)
            case .history(let ref):
                historyPage(ref)
            case .tag(let source):
                tagPage(source)
            case .push(let ref):
                pushPage(ref)
            }
        }
    }

    private func historyPage(_ reference: String) -> some View {
        let image = group.images.first { $0.reference == reference } ?? primaryImage(group)
        let variant = image?.variants.first(where: \.isRunnable) ?? image?.variants.first
        let history = variant?.config?.history ?? []
        return imagePageBody(title: "History", subtitle: Format.shortImage(reference)) {
            if history.isEmpty {
                ContentUnavailableView("No history", systemImage: "clock",
                                       description: Text("This image records no layer history."))
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ResourceCardInsetSection {
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
                }
            }
        }
    }

    private func tagPage(_ source: String) -> some View {
        imagePageBody(title: "Add tag", subtitle: Format.shortImage(source)) {
            ResourceCardInsetSection {
                PanelField(label: "Source") {
                    Text(Format.shortImage(source)).foregroundStyle(.secondary)
                }
                PanelField(label: "New reference") {
                    TextField("", text: $tagTarget, prompt: Text("e.g. ghcr.io/me/app:v1"))
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

    private func pushPage(_ reference: String) -> some View {
        imagePageBody(title: "Push image", subtitle: Format.shortImage(reference)) {
            if pushStartedReference == reference, let client = app.client {
                StreamConsole(stream: { client.streamPush(reference) })
                    .frame(minHeight: 260)
            } else {
                pushReadiness(reference)
            }
        }
        .task { await app.refreshRegistries() }
    }

    private func imagePageBody<C: View>(title: String, subtitle: String?,
                                        @ViewBuilder content: @escaping () -> C) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                    ResourceCardTitleText(text: title)
                    if let subtitle {
                        ResourceCardMonospacedSubtitleText(text: subtitle)
                    }
                }
                .padding(.horizontal, Tokens.Space.s)
                content()
            }
            .padding(Tokens.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private func pushReadiness(_ reference: String) -> some View {
        let readiness = pushState(for: reference)
        return ResourceCardInsetSection {
            HStack(alignment: .top, spacing: Tokens.Space.s) {
                Image(systemName: readiness.symbol)
                    .font(.title3)
                    .foregroundStyle(readiness.tint)
                    .frame(width: Tokens.IconSize.rowIconColumn)
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(readiness.title)
                        .font(.headline)
                    Text(readiness.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if let detail = readiness.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: Tokens.Space.s)
            }
            HStack {
                Spacer()
                switch readiness.action {
                case .push:
                    Button {
                        confirmingPushReference = reference
                    } label: {
                        Label("Push", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(app.client == nil)
                case .openRegistries:
                    Button {
                        onClose()
                        ui.openSettings(to: .registries)
                    } label: {
                        Label("Open Registries", systemImage: "key")
                    }
                case .tag:
                    Button {
                        withAnimation(spring) { page = .tag(reference) }
                    } label: {
                        Label("Add Tag", systemImage: "tag")
                    }
                case .none:
                    EmptyView()
                }
            }
        }
    }

    private func pushState(for reference: String) -> PushState {
        guard app.client != nil else {
            return PushState(title: "Runtime unavailable",
                             message: "Start the container service before pushing images.",
                             detail: nil,
                             symbol: "exclamationmark.triangle",
                             tint: .orange,
                             action: .none)
        }

        let parsed = RegistryImageReference.parse(reference)
        let registry = displayRegistry(parsed.registry)

        guard !parsed.isDigestReference else {
            return PushState(title: "Tag required",
                             message: "Digest references cannot be pushed directly.",
                             detail: "Add a writable tag such as ghcr.io/me/app:v1, then push that tag.",
                             symbol: "tag",
                             tint: .orange,
                             action: .tag)
        }

        if normalizedRegistryHost(parsed.registry) == "docker.io",
           parsed.repository.hasPrefix("library/") {
            return PushState(title: "Writable namespace required",
                             message: "This tag points at Docker Hub's library namespace.",
                             detail: "Add a tag under a namespace you control before pushing.",
                             symbol: "tag",
                             tint: .orange,
                             action: .tag)
        }

        guard let login = matchingRegistryLogin(for: parsed.registry) else {
            return PushState(title: "Registry sign-in required",
                             message: "Sign in to \(registry) before pushing this image.",
                             detail: "Contained checks for a saved container registry login before starting a push.",
                             symbol: "key",
                             tint: .orange,
                             action: .openRegistries)
        }

        return PushState(title: "Ready to push",
                         message: "Signed in to \(registry)\(login.username.map { " as \($0)" } ?? "").",
                         detail: "The registry will still enforce write permission for \(parsed.repository).",
                         symbol: "checkmark.circle.fill",
                         tint: .green,
                         action: .push)
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
                withAnimation(spring) { page = .tags }
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
            ResourceCardHeaderTextBlock {
                ResourceCardTitleText(text: repositoryTitle(group.primaryReference))
            } subtitle: {
                ResourceCardSubtitleText(text: repositoryOwner(group.primaryReference))
            }
        } trailing: {
            imagePageControls(controlsReveal: isExpanded ? 1 : 0)
        }
    }

    private func imagePageControls(controlsReveal: Double) -> some View {
        ResourceCardPageControls(items: imagePageControlItems,
                                 selection: page,
                                 tint: resolvedImageTint,
                                 controlsReveal: controlsReveal,
                                 onSelect: selectPage,
                                 onClose: onClose)
    }

    private var imagePageControlItems: [ResourceCardPageControlItem<ImageDetailPage>] {
        let reference = primaryImage(group)?.reference ?? group.primaryReference
        return [
            ResourceCardPageControlItem(id: .tags,
                                        title: "Tags",
                                        systemImage: "tag"),
            ResourceCardPageControlItem(id: .history(reference),
                                        title: "History",
                                        systemImage: "clock.arrow.circlepath"),
            ResourceCardPageControlItem(id: .tag(reference),
                                        title: "Add Tag",
                                        systemImage: "plus.circle"),
            ResourceCardPageControlItem(id: .push(reference),
                                        title: "Push",
                                        systemImage: "arrow.up.circle")
        ]
    }

    private var resolvedImageTint: Color {
        app.imageGroupStyle(for: group).color
    }

    private func selectPage(_ item: ImageDetailPage) {
        guard page != item else { return }
        if case .push = item {} else {
            pushStartedReference = nil
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            page = item
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
                ResourceCardHeaderTextBlock {
                    ResourceCardMonospacedTitleText(text: Format.shortImage(reference))
                } subtitle: {
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
            // History / Tag / Push grow the detail morph into a sub-page, so they're offered only
            // from the expanded detail (a collapsed card opens the detail first).
            if isExpanded {
                Button { withAnimation(spring) { page = .tag(image.reference) } } label: { Label("Add Tag…", systemImage: "tag") }
                Button { withAnimation(spring) { page = .push(image.reference) } } label: { Label("Push…", systemImage: "arrow.up.circle") }
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

    private var pushConfirmationBinding: Binding<Bool> {
        Binding(get: { confirmingPushReference != nil },
                set: { if !$0 { confirmingPushReference = nil } })
    }

    private func matchingRegistryLogin(for registry: String) -> RegistryLogin? {
        let normalized = normalizedRegistryHost(registry)
        return app.registries.first { normalizedRegistryHost($0.host) == normalized }
    }

    private func normalizedRegistryHost(_ host: String) -> String {
        var value = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let url = URL(string: value), let urlHost = url.host {
            value = urlHost
        }
        value = value
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        value = String(value.split(separator: "/").first ?? Substring(value))
        switch value {
        case "registry-1.docker.io", "index.docker.io", "docker.io":
            return "docker.io"
        default:
            return value
        }
    }

    private func displayRegistry(_ registry: String) -> String {
        normalizedRegistryHost(registry) == "docker.io" ? "docker.io" : registry
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
