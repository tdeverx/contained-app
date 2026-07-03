import SwiftUI
import ContainedUX
import ContainedUI
import SwiftData
import AppKit
import ContainedCore

struct ToolbarImageGroupCard: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    let group: Core.Image.LocalTagGroup
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
        var tone: UI.State.Tone
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
        return UI.Card.Scaffold(size: .medium,
                            isExpanded: isExpanded,
                            fill: resolved.fillBackground ? resolved.color : nil,
                            fillOpacity: resolved.backgroundOpacity,
                            gradient: resolved.gradient,
                            gradientAngle: resolved.gradientAngle,
                            blendMode: resolved.backgroundBlendMode,
                            elevated: false,
                            onTap: onTap,
                            title: repositoryTitle(group.primaryReference),
                            subtitle: repositoryOwner(group.primaryReference),
                            pages: imagePages) {
            if let image {
                ImageStyleButton(reference: image.reference,
                                 style: resolved,
                                 target: .imageGroup(id: group.id, reference: group.primaryReference))
            } else {
                imageChip(resolved)
            }
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            imageBody(group)
        } footerLeading: {
            imageFooterTagCount(group)
            imageFooterInfo(status)
        } footerActions: {
            imageFooterActions(group)
        } widget: {
            EmptyView()
        }
        .contextMenu { cardMenu(group) }
    }

    // MARK: Detail sub-pages

    @ViewBuilder
    private func imageBody(_ group: Core.Image.LocalTagGroup) -> some View {
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
        return imagePageBody(title: AppText.string("image.history", defaultValue: "History"), subtitle: Format.shortImage(reference)) {
            if history.isEmpty {
                UI.State.Empty(AppText.string("image.history.empty", defaultValue: "No history"),
                                 systemImage: "clock",
                                 description: AppText.string("image.history.empty.description", defaultValue: "This image records no layer history."),
                                 minHeight: 220)
            } else {
                UI.Card.InsetSection {
                    UI.List.Stack {
                        ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.xxs) {
                                Text(entry.createdBy ?? entry.comment ?? "—")
                                    .designMonospacedCaption()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let created = entry.created {
                                    Text(created.formatted(date: .abbreviated, time: .shortened))
                                        .designSecondaryCaption()
                                }
                            }
                            .padding(UI.Layout.Spacing.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .subtleTileBackground()
                        }
                    }
                }
            }
        }
    }

    private func tagPage(_ source: String) -> some View {
        imagePageBody(title: AppText.addTag, subtitle: Format.shortImage(source)) {
            UI.Card.InsetSection {
                UI.Panel.Field(label: AppText.string("image.tag.source", defaultValue: "Source")) {
                    Text(Format.shortImage(source)).designSecondaryValueStyle()
                }
                UI.Panel.Field(label: AppText.string("image.tag.newReference", defaultValue: "New reference")) {
                    TextField("", text: $tagTarget, prompt: Text("e.g. ghcr.io/me/app:v1"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submitTag(source: source) }
                }
            }
            HStack {
                Spacer()
                if tagBusy { UI.State.ProgressIndicator() }
                UI.Action.TextButton(title: AppText.addTag,
                                       systemName: "checkmark",
                                       prominence: .prominent,
                                       isEnabled: !tagTarget.trimmingCharacters(in: .whitespaces).isEmpty && !tagBusy) {
                    submitTag(source: source)
                }
            }
        }
    }

    private func pushPage(_ reference: String) -> some View {
        imagePageBody(title: AppText.string("image.pushImage", defaultValue: "Push image"), subtitle: Format.shortImage(reference)) {
            if pushStartedReference == reference, let client = app.client {
                UI.Console.Stream(stream: { client.streamPush(reference) },
                              workingLabel: AppText.working,
                              completedLabel: AppText.completed,
                              lineCountLabel: AppText.lineCount,
                              copyLogHelp: AppText.copyLog,
                              failureLabel: AppErrorPresentation.message)
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
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                VStack(alignment: .leading, spacing: UI.Card.Spacing.compactText) {
                    UI.Card.TitleText(text: title)
                    if let subtitle {
                        UI.Card.MonospacedSubtitleText(text: subtitle)
                    }
                }
                .padding(.horizontal, UI.Layout.Spacing.s)
                content()
            }
            .padding(UI.Layout.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private func pushReadiness(_ reference: String) -> some View {
        let readiness = pushState(for: reference)
        return UI.Card.InsetSection {
            HStack(alignment: .top, spacing: UI.Layout.Spacing.s) {
                UI.Symbol.Image(systemName: readiness.symbol,
                             tone: readiness.tone,
                             size: .title3,
                             frameWidth: UI.Control.Size.rowIconColumn)
                VStack(alignment: .leading, spacing: UI.Layout.Spacing.xs) {
                    Text(readiness.title)
                        .designHeadlineLabelStyle()
                    Text(readiness.message)
                        .designSecondaryCallout()
                    if let detail = readiness.detail {
                        Text(detail)
                            .designSecondaryCaption()
                    }
                }
                Spacer(minLength: UI.Layout.Spacing.s)
            }
            HStack {
                Spacer()
                switch readiness.action {
                case .push:
                    UI.Action.TextButton(title: AppText.push,
                                           systemName: "arrow.up.circle",
                                           prominence: .prominent,
                                           isEnabled: app.client != nil) {
                        confirmingPushReference = reference
                    }
                case .openRegistries:
                    UI.Action.TextButton(title: AppText.string("registry.openRegistries", defaultValue: "Open Registries"),
                                           systemName: "key") {
                        onClose()
                        ui.openSettings(to: .registries)
                    }
                case .tag:
                    UI.Action.TextButton(title: AppText.addTag,
                                           systemName: "tag") {
                        withAnimation(spring) { page = .tag(reference) }
                    }
                case .none:
                    EmptyView()
                }
            }
        }
    }

    private func pushState(for reference: String) -> PushState {
        guard app.client != nil else {
            return PushState(title: AppText.string("image.push.runtimeUnavailable", defaultValue: "Runtime unavailable"),
                             message: AppText.string("image.push.runtimeUnavailable.message", defaultValue: "Start the container service before pushing images."),
                             detail: nil,
                             symbol: "exclamationmark.triangle",
                             tone: .warning,
                             action: .none)
        }

        let parsed = Core.Registry.ImageReference.parse(reference)
        let registry = displayRegistry(parsed.registry)

        guard !parsed.isDigestReference else {
            return PushState(title: AppText.string("image.push.tagRequired", defaultValue: "Tag required"),
                             message: AppText.string("image.push.tagRequired.message", defaultValue: "Digest references cannot be pushed directly."),
                             detail: AppText.string("image.push.tagRequired.detail", defaultValue: "Add a writable tag such as ghcr.io/me/app:v1, then push that tag."),
                             symbol: "tag",
                             tone: .warning,
                             action: .tag)
        }

        if normalizedRegistryHost(parsed.registry) == "docker.io",
           parsed.repository.hasPrefix("library/") {
            return PushState(title: AppText.string("image.push.namespaceRequired", defaultValue: "Writable namespace required"),
                             message: AppText.string("image.push.namespaceRequired.message", defaultValue: "This tag points at Docker Hub's library namespace."),
                             detail: AppText.string("image.push.namespaceRequired.detail", defaultValue: "Add a tag under a namespace you control before pushing."),
                             symbol: "tag",
                             tone: .warning,
                             action: .tag)
        }

        guard let login = matchingRegistryLogin(for: parsed.registry) else {
            return PushState(title: AppText.string("image.push.signInRequired", defaultValue: "Registry sign-in required"),
                             message: AppText.string("image.push.signInRequired.message", defaultValue: "Sign in to \(registry) before pushing this image."),
                             detail: AppText.string("image.push.signInRequired.detail", defaultValue: "Contained checks for a saved container registry login before starting a push."),
                             symbol: "key",
                             tone: .warning,
                             action: .openRegistries)
        }

        return PushState(title: AppText.string("image.push.ready", defaultValue: "Ready to push"),
                         message: AppText.string("image.push.ready.message", defaultValue: "Signed in to \(registry)\(login.username.map { " as \($0)" } ?? "")."),
                         detail: AppText.string("image.push.ready.detail", defaultValue: "The registry will still enforce write permission for \(parsed.repository)."),
                         symbol: "checkmark.circle.fill",
                         tone: .success,
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
                await app.refreshImagesIfNeeded(force: true)
                tagBusy = false
                tagTarget = ""
                withAnimation(spring) { page = .tags }
            } catch let error as Core.Command.Error {
                app.flash(error.appDisplayMessage); tagBusy = false
            } catch {
                app.flash(error.appDisplayMessage); tagBusy = false
            }
        }
    }

    private var imagePageControlItems: [UI.Card.Page<ImageDetailPage>] {
        let reference = primaryImage(group)?.reference ?? group.primaryReference
        return [
            UI.Card.Page(id: .tags,
                                        title: AppText.string("image.tags", defaultValue: "Tags"),
                                        systemImage: "tag"),
            UI.Card.Page(id: .history(reference),
                                        title: AppText.string("image.history", defaultValue: "History"),
                                        systemImage: "clock.arrow.circlepath"),
            UI.Card.Page(id: .tag(reference),
                                        title: AppText.addTag,
                                        systemImage: "plus.circle"),
            UI.Card.Page(id: .push(reference),
                                        title: AppText.push,
                                        systemImage: "arrow.up.circle")
        ]
    }

    private var imagePages: UI.Card.Pages<ImageDetailPage> {
        UI.Card.Pages(items: imagePageControlItems,
                          selection: page,
                          tint: resolvedImageTint,
                          controlsReveal: isExpanded ? 1 : 0,
                          closeLabel: AppText.close,
                          onSelect: selectPage,
                          onClose: onClose)
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

    private func imageFooterInfo(_ status: Core.Image.UpdateStatus) -> some View {
        UI.Card.FooterMini {
            UI.Symbol.Image(systemName: updateSymbol(status.state),
                         tone: updateTone(status.state),
                         size: .caption)
        } text: {
            UI.Card.SubtitleText(text: updateFooterText(status))
        }
    }

    private func imageFooterTagCount(_ group: Core.Image.LocalTagGroup) -> some View {
        UI.Card.FooterMini {
            UI.Symbol.Image(systemName: "tag", size: .caption)
        } text: {
            UI.Card.MetricText(text: "\(group.references.count)")
        }
    }

    @ViewBuilder
    private func imageFooterActions(_ group: Core.Image.LocalTagGroup) -> some View {
        footerAction("play", help: AppText.run) {
            ui.runImage(group.primaryReference)
            if isExpanded { onClose() }
        }
        footerAction("arrow.triangle.2.circlepath", help: AppText.checkForUpdates) {
            Task { await app.checkImageUpdate(group.primaryReference) }
        }
        if app.imageUpdateStatus(for: group.primaryReference).state == .updateAvailable {
            footerAction("arrow.down.circle", help: AppText.pullUpdate, tint: .orange) {
                Task { await app.pullImageUpdate(group.primaryReference) }
            }
        }
        if let image = primaryImage(group) {
            footerAction("arrow.up.doc", help: AppText.save) { save(image) }
        }
        footerAction("trash", help: AppText.prune, role: .destructive) { pruning = true }
    }

    private func tagList(_ group: Core.Image.LocalTagGroup) -> some View {
        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
            Text("Tags")
                .designHeadlineLabelStyle()
                .padding(.leading, UI.Layout.Spacing.xs)
            ScrollView(.vertical) {
                LazyVStack(spacing: UI.Layout.Spacing.s) {
                    ForEach(group.references, id: \.self) { reference in
                        tagRow(reference, in: group)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(UI.Layout.Spacing.s)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }

    private func tagRow(_ reference: String, in group: Core.Image.LocalTagGroup) -> some View {
        let style = app.imageStyle(for: reference)
        return UI.Card.Scaffold(size: .medium,
                            fill: style.fillBackground ? style.color : nil,
                            fillOpacity: style.backgroundOpacity,
                            gradient: style.gradient,
                            gradientAngle: style.gradientAngle,
                            blendMode: style.backgroundBlendMode,
                            elevated: false,
                            title: Format.shortImage(reference),
                            subtitle: repositoryName(reference),
                            titleStyle: .monospaced) {
            ImageStyleButton(reference: reference,
                             style: style,
                             target: .imageTag(reference: reference, groupID: group.id))
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            UI.Card.FooterMini {
                UI.Symbol.Image(systemName: "tag", size: .caption2)
            } text: {
                UI.Card.MetricText(text: "Local tag")
            }
        } footerActions: {
            footerAction("play", help: AppText.run) {
                ui.runImage(reference)
                if isExpanded { onClose() }
            }
            footerAction("doc.on.doc", help: AppText.copyReference) { copyToPasteboard(reference) }
            footerAction("trash", help: AppText.deleteTag, role: .destructive) { deletingReference = reference }
        } widget: {
            EmptyView()
        }
        .contextMenu { tagMenu(reference, in: group) }
    }

    /// Right-click actions for a single tag — mirrors the footer buttons so the row is consistent with
    /// the group card (which has its own context menu).
    @ViewBuilder
    private func tagMenu(_ reference: String, in group: Core.Image.LocalTagGroup) -> some View {
        Button { ui.runImage(reference); if isExpanded { onClose() } } label: { Label("Run…", systemImage: "play") }
        Button { copyToPasteboard(reference) } label: { Label("Copy reference", systemImage: "doc.on.doc") }
        Divider()
        Button(role: .destructive) { deletingReference = reference } label: { Label("Delete tag", systemImage: "trash") }
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              role: ButtonRole? = nil,
                              action: @escaping () -> Void) -> some View {
        UI.Card.FooterButton(systemName: systemName,
                                 help: help,
                                 tint: tint,
                                 role: role,
                                 action: action)
    }

    @ViewBuilder
    private func cardMenu(_ group: Core.Image.LocalTagGroup) -> some View {
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
        UI.Card.IconChip(symbol: style.symbol, tint: style.color)
    }

    private func updateSymbol(_ state: Core.Image.UpdateState) -> String {
        switch state {
        case .unknown: return "questionmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .current: return "checkmark.circle.fill"
        case .updateAvailable: return "arrow.down.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func updateTone(_ state: Core.Image.UpdateState) -> UI.State.Tone {
        switch state {
        case .current: return .success
        case .updateAvailable, .error: return .warning
        case .checking: return .info
        case .unknown: return .neutral
        }
    }

    private func repositoryName(_ reference: String) -> String {
        let parsed = Core.Registry.ImageReference.parse(reference)
        if parsed.registry == "registry-1.docker.io", parsed.repository.hasPrefix("library/") {
            return String(parsed.repository.dropFirst("library/".count))
        }
        return parsed.repository
    }

    private func repositoryTitle(_ reference: String) -> String {
        let parsed = Core.Registry.ImageReference.parse(reference)
        return parsed.repository.split(separator: "/").map(String.init).last ?? parsed.repository
    }

    private func repositoryOwner(_ reference: String) -> String {
        let parsed = Core.Registry.ImageReference.parse(reference)
        let parts = parsed.repository.split(separator: "/").map(String.init)
        if parts.count > 1 {
            return parts.dropLast().joined(separator: "/")
        }
        return parsed.registry == "registry-1.docker.io" ? "docker.io" : parsed.registry
    }

    private func updateFooterText(_ status: Core.Image.UpdateStatus) -> String {
        switch status.state {
        case .unknown: return "Not checked"
        case .checking: return "Checking"
        case .current: return "Up to date"
        case .updateAvailable: return "Updates available"
        case .error: return "Check failed"
        }
    }

    private func primaryImage(_ group: Core.Image.LocalTagGroup) -> Core.Image.Resource? {
        group.images.first { $0.reference == group.primaryReference } ?? group.images.first
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deletingReference != nil }, set: { if !$0 { deletingReference = nil } })
    }

    private var pushConfirmationBinding: Binding<Bool> {
        Binding(get: { confirmingPushReference != nil },
                set: { if !$0 { confirmingPushReference = nil } })
    }

    private func matchingRegistryLogin(for registry: String) -> Core.Registry.Login? {
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
            await app.refreshImagesIfNeeded(force: true)
            app.flash(AppText.deletedImage(Format.shortImage(reference)))
            deletingReference = nil
        } catch let error as Core.Command.Error { app.flash(error.appDisplayMessage) }
        catch { app.flash(error.appDisplayMessage) }
    }

    private func prune(all: Bool) async {
        guard let client = app.client else { return }
        do { _ = try await client.pruneImages(all: all); await app.refreshImagesIfNeeded(force: true) }
        catch let error as Core.Command.Error { app.flash(error.appDisplayMessage) }
        catch { app.flash(error.appDisplayMessage) }
    }

    private func save(_ image: Core.Image.Resource) {
        guard let client = app.client else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.nameFieldStringValue = Format.shortImage(image.reference).replacingOccurrences(of: ":", with: "_") + ".tar"
        panel.message = AppText.saveImageTarArchive(Format.shortImage(image.reference))
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            if let error = await app.captured({ _ = try await client.saveImages([image.reference], to: url.path) }) {
                app.flash(error)
            } else {
                app.flash(AppText.savedFile(url.lastPathComponent))
            }
        }
    }

}
