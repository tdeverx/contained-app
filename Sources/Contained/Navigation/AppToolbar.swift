import SwiftUI
import SwiftData
import AppKit
import ContainedCore

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Three compact glass groups — add menu (leading), search + command palette (center),
/// images + activity (trailing) — stay **constant across pages** (high-level, not per-section).
///
/// Mounted as a top overlay over the **detail column** in `RootView` (never over the sidebar): the
/// band sits in the title-bar region, the rest of the area is hit-transparent until a control opens.
/// The add `+` grows a `MorphingExpander` panel from its slot; the center search field is a single
/// item that expands *in place* into the command palette (one field, no separate panel). Control
/// sizing comes from `Tokens.Toolbar` / `ToolbarControls`.
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.appSafeAreas) private var safeAreas

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?
    @State private var toolbarImageDetail: LocalImageTagGroup?
    @State private var toolbarImageSourceFrame: CGRect?
    @State private var toolbarImageExpanded = false

    private let toolbarImageSpring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding. Sourced from `Tokens.Toolbar` so the band, the safe-area
    /// manager, and the controls all agree.
    static let bandHeight: CGFloat = Tokens.Toolbar.band

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                toolbarRow
                    .frame(height: Tokens.Toolbar.controlHeight)
                    .padding(.top, rowTopInset)   // centered on the traffic-light line
                Spacer(minLength: 0)            // empty + hit-transparent below the band
                    .allowsHitTesting(false)
            }
            // The center search/command-palette is a single element that expands in place; it lives in
            // its own full-area layer so its open state can float over the page with a backdrop.
            ToolbarCommandPalette(insets: morphTargetInsets)
                .zIndex(ui.activeMorph == .palette ? 20 : 5)
            addMorphLayer
                .zIndex(ui.activeMorph == .add ? 30 : 0)
            updatesMorphLayer
                .zIndex(ui.activeMorph == .updates ? 30 : 0)
            activityMorphLayer
                .zIndex(ui.activeMorph == .activity ? 30 : 0)
            templatesMorphLayer
                .zIndex(ui.activeMorph == .templates ? 30 : 0)
            systemMorphLayer
                .zIndex(ui.activeMorph == .system ? 30 : 0)
            toolbarImageDetailLayer
                .zIndex(toolbarImageDetail == nil ? 0 : 50)
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(ToolbarSlotKey.self) { slots = $0 }
    }

    // MARK: Row

    private var toolbarRow: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            leadingZone
            Spacer(minLength: Tokens.Space.m)
            trailingZone
        }
        .padding(.horizontal, Tokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    // The add control is a standalone circle (single action); the trailing images/activity buttons are a
    // grouped capsule.
    private var leadingZone: some View {
        ToolbarIconButton(systemName: "plus", help: "Add") { ui.toggleMorph(.add) }
            .frame(width: Tokens.Toolbar.controlHeight, height: Tokens.Toolbar.controlHeight)
            .opacity(ui.activeMorph == .add ? 0 : 1)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ToolbarSlotKey.self,
                                           value: [.add: proxy.frame(in: .named(Self.space))])
                }
            )
    }

    // The trailing Images + Templates + Activity buttons share one glass capsule (a
    // `ToolbarButtonCluster`); each morph grows out of that single capsule frame, so the group reads
    // as one control.
    private var trailingZone: some View {
        ToolbarButtonCluster {
            ToolbarIconButton(systemName: "shippingbox.fill", help: "Images",
                              showsBackground: false) { ui.toggleMorph(.updates) }
                .opacity(ui.activeMorph == .updates ? 0 : 1)
            ToolbarIconButton(systemName: "square.on.square", help: "Templates",
                              showsBackground: false) { ui.toggleMorph(.templates) }
                .opacity(ui.activeMorph == .templates ? 0 : 1)
            ToolbarIconButton(systemName: "clock.arrow.circlepath", help: "Activity",
                              showsBackground: false) { ui.toggleMorph(.activity) }
                .opacity(ui.activeMorph == .activity ? 0 : 1)
            ToolbarIconButton(systemName: "gearshape.2", help: "System",
                              showsBackground: false) { ui.toggleMorph(.system) }
                .opacity(ui.activeMorph == .system ? 0 : 1)
        }
        .background(clusterSlotReader([.updates, .templates, .activity, .system]))
    }

    // MARK: Add morph layer

    @ViewBuilder
    private var addMorphLayer: some View {
        if ui.activeMorph == .add {
            MorphingExpander(isPresented: addMorphBinding, originFrame: slots[.add] ?? .zero,
                             panelSize: CGSize(width: 440, height: 300),   // initial; flow resizes per page
                             placement: .anchored,
                             targetInsets: morphTargetInsets,
                             onBackdropTap: addSoftDismiss) {
                CreationFlow(start: .menu,
                             onClose: {
                                 addSoftDismiss = nil
                                 ui.activeMorph = nil
                             },
                             onSoftDismissChange: { addSoftDismiss = $0 })
            }
        }
    }

    @ViewBuilder
    private var updatesMorphLayer: some View {
        if ui.activeMorph == .updates {
            MorphingExpander(isPresented: morphBinding(.updates),
                             originFrame: slots[.updates] ?? .zero,
                             panelSize: CGSize(width: 440, height: 300),
                             placement: .anchored,
                             targetInsets: morphTargetInsets) {
                ToolbarUpdatesPanel(onOpenImage: openToolbarImageDetail) {
                    ui.activeMorph = nil
                }
            }
        }
    }

    @ViewBuilder
    private var toolbarImageDetailLayer: some View {
        if let detail = toolbarImageDetail {
            GeometryReader { proxy in
                let bounds = safeBounds(in: proxy.size)
                let current = currentToolbarImageGroup(detail)
                let target = toolbarImageTargetRect(in: bounds)
                let source = usableToolbarImageSource ?? target
                let rect = toolbarImageExpanded ? target : source
                ZStack {
                    Color.clear
                        .globalBackdrop(style: .dim, progress: toolbarImageExpanded ? 1 : 0)
                        .contentShape(Rectangle())
                        .onTapGesture { closeToolbarImageDetail() }

                    ToolbarImageGroupCard(group: current,
                                          isExpanded: true,
                                          onTap: {},
                                          onClose: closeToolbarImageDetail)
                        .frame(width: rect.width, height: rect.height, alignment: .top)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }

    @ViewBuilder
    private var activityMorphLayer: some View {
        if ui.activeMorph == .activity {
            MorphingExpander(isPresented: morphBinding(.activity),
                             originFrame: slots[.activity] ?? .zero,
                             panelSize: CGSize(width: 460, height: 360),
                             placement: .anchored,
                             targetInsets: morphTargetInsets) {
                ToolbarActivityPanel {
                    ui.activeMorph = nil
                }
            }
        }
    }

    @ViewBuilder
    private var templatesMorphLayer: some View {
        if ui.activeMorph == .templates {
            MorphingExpander(isPresented: morphBinding(.templates),
                             originFrame: slots[.templates] ?? .zero,
                             panelSize: CGSize(width: 440, height: 300),
                             placement: .anchored,
                             targetInsets: morphTargetInsets) {
                ToolbarTemplatesPanel {
                    ui.activeMorph = nil
                }
            }
        }
    }

    @ViewBuilder
    private var systemMorphLayer: some View {
        if ui.activeMorph == .system {
            MorphingExpander(isPresented: morphBinding(.system),
                             originFrame: slots[.system] ?? .zero,
                             panelSize: CGSize(width: 580, height: 600),
                             placement: .anchored,
                             targetInsets: morphTargetInsets) {
                ToolbarSystemPanel { ui.activeMorph = nil }
            }
        }
    }

    private var addMorphBinding: Binding<Bool> {
        Binding(get: { ui.activeMorph == .add }, set: {
            if !$0 { addSoftDismiss = nil; ui.activeMorph = nil }
        })
    }

    private func morphBinding(_ morph: UIState.ToolbarMorph) -> Binding<Bool> {
        Binding(get: { ui.activeMorph == morph }, set: {
            if !$0 { ui.activeMorph = nil }
        })
    }

    /// Report one shared frame (the cluster capsule) as the morph origin for several morphs at once,
    /// so both the Images and Activity panels grow out of the same grouped pill.
    private func clusterSlotReader(_ morphs: [UIState.ToolbarMorph]) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(Self.space))
            Color.clear.preference(key: ToolbarSlotKey.self,
                                   value: Dictionary(uniqueKeysWithValues: morphs.map { ($0, frame) }))
        }
    }

    private var morphTargetInsets: EdgeInsets {
        safeAreas.morphInsets(.includingToolbar)
    }

    private var rowTopInset: CGFloat { Tokens.Toolbar.topPadding }

    private var usableToolbarImageSource: CGRect? {
        guard let frame = toolbarImageSourceFrame,
              frame.width.isFinite, frame.height.isFinite,
              frame.minX.isFinite, frame.minY.isFinite,
              frame.width > 1, frame.height > 1
        else { return nil }
        return frame
    }

    private func safeBounds(in size: CGSize) -> CGRect {
        let insets = morphTargetInsets
        return CGRect(x: insets.leading,
                      y: insets.top,
                      width: max(1, size.width - insets.leading - insets.trailing),
                      height: max(1, size.height - insets.top - insets.bottom))
    }

    private func toolbarImageTargetRect(in bounds: CGRect) -> CGRect {
        let proposed = CGSize(width: min(max(bounds.width * 0.72, 560), 760),
                              height: min(max(bounds.height * 0.68, 440), 620))
        return MorphGeometry.targetRect(origin: .zero,
                                        proposedSize: proposed,
                                        bounds: bounds,
                                        placement: .centered,
                                        margin: Tokens.Space.xxl)
    }

    private func currentToolbarImageGroup(_ group: LocalImageTagGroup) -> LocalImageTagGroup {
        LocalImageTagGroup.groups(for: app.images).first { $0.id == group.id } ?? group
    }

    private func openToolbarImageDetail(_ group: LocalImageTagGroup, sourceFrame: CGRect) {
        toolbarImageDetail = group
        toolbarImageSourceFrame = sourceFrame
        toolbarImageExpanded = false
        DispatchQueue.main.async {
            withAnimation(toolbarImageSpring) { toolbarImageExpanded = true }
        }
    }

    private func closeToolbarImageDetail() {
        withAnimation(toolbarImageSpring) { toolbarImageExpanded = false } completion: {
            toolbarImageDetail = nil
            toolbarImageSourceFrame = nil
        }
    }
}

private struct ToolbarUpdatesPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var onOpenImage: (LocalImageTagGroup, CGRect) -> Void
    var onClose: () -> Void

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
        .morphPanelSize(CGSize(width: 520, height: 520))
        .morphPanelPlacement(.anchored)
        .task { await app.refreshImagesIfStale(force: true) }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Images").font(.headline)
                Text("\(imageGroups.count) local · \(updateCount) update\(updateCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GlassCircleButton(systemName: "square.and.arrow.down", help: "Load Image Tar") {
                ui.dispatch(.loadImage)
                onClose()
            }
            GlassCircleButton(systemName: "arrow.triangle.2.circlepath", help: "Check for Updates") {
                Task { await app.runImageUpdateSweepNow() }
            }
            GlassCircleButton(systemName: "trash", help: "Prune Images") {
                ui.dispatch(.pruneImages)
                onClose()
            }
            GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
        }
        .padding(Tokens.Space.m)
    }

    private var emptyCard: some View {
        ResourceGlassCard(size: .small, elevated: false) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("No images").font(.callout.weight(.medium))
                    Text("Pull or build an image to see it here").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func imageRow(_ group: LocalImageTagGroup) -> some View {
        GeometryReader { proxy in
            ToolbarImageGroupCard(group: group,
                                  isExpanded: false,
                                  onTap: {
                                      onOpenImage(group, proxy.frame(in: .named(AppToolbar.space)))
                                  },
                                  onClose: {})
        }
        .frame(height: ResourceCardSize.medium.height)
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

private struct ToolbarImageGroupCard: View {
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
            imageFooterInfo(status)
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
        HStack(spacing: Tokens.Space.s) {
            if let image {
                ImageStyleButton(reference: image.reference,
                                 style: style,
                                 target: .imageGroup(id: group.id, reference: group.primaryReference))
            } else {
                imageChip(style)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(repositoryName(group.primaryReference))
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text("\(group.references.count) tag\(group.references.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isExpanded {
                GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
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

    private func imageFooterActions(_ group: LocalImageTagGroup) -> some View {
        HStack(spacing: Tokens.Space.m) {
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
            .frame(height: tagListHeight(for: group))
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }

    private func tagListHeight(for group: LocalImageTagGroup) -> CGFloat {
        let rows = CGFloat(max(group.references.count, 1))
        let content = rows * ResourceCardSize.medium.height + max(0, rows - 1) * Tokens.Space.s
        return min(content + Tokens.Space.s * 2, 360)
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
                    Text(Format.shortImage(reference))
                        .font(.system(.callout, design: .monospaced).weight(.medium))
                        .lineLimit(1)
                    Text(repositoryName(reference))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        } footerLeading: {
            Text("Local tag")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footerActions: {
            HStack(spacing: Tokens.Space.m) {
                footerAction("play", help: "Run") {
                    ui.runImage(reference)
                    if isExpanded { onClose() }
                }
                footerAction("doc.on.doc", help: "Copy reference") { copyToPasteboard(reference) }
                footerAction("doc.text.magnifyingglass", help: "Inspect") { inspect(reference, in: group) }
                footerAction("trash", help: "Delete tag", tint: .red) { deletingReference = reference }
            }
        }
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).font(.body)
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
        Image(systemName: style.symbol)
            .font(.title3)
            .foregroundStyle(style.color)
            .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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

    private func updateFooterText(_ status: ImageUpdateStatus) -> String {
        switch status.state {
        case .unknown: return "Not checked"
        case .checking: return "Checking"
        case .current: return "Up to date"
        case .updateAvailable: return "Update available"
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

private struct ToolbarActivityPanel: View {
    var onClose: () -> Void

    var body: some View {
        ActivityContent(showClose: true, elevated: false, onClose: onClose)
            .morphPanelSize(CGSize(width: 560, height: 520))
        .morphPanelPlacement(.anchored)
    }
}

/// The toolbar System panel — service status, volumes, disk usage, and the Prune Center as flat glass
/// cards (the same treatment as the Images/Templates panels). Header-less by design: it dismisses on
/// backdrop tap or Escape. New Volume hands off to the creation flow (closing the panel first).
private struct ToolbarSystemPanel: View {
    var onClose: () -> Void

    var body: some View {
        SystemContent(elevated: false, onClose: onClose)
            .morphPanelSize(CGSize(width: 580, height: 600))
            .morphPanelPlacement(.anchored)
    }
}

/// The toolbar Templates panel — saved run configurations as flat glass cards (the same treatment as
/// the Images panel). "Use" prefills the create form; cards can be deleted.
private struct ToolbarTemplatesPanel: View {
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.createdAt, order: .reverse) private var saved: [Template]
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                    if saved.isEmpty {
                        emptyCard
                    } else {
                        ForEach(saved) { template in templateCard(template) }
                    }
                }
                .padding(Tokens.Space.m)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .morphPanelSize(CGSize(width: 460, height: 480))
        .morphPanelPlacement(.anchored)
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Templates").font(.headline)
                Text("\(saved.count) saved").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
        }
        .padding(Tokens.Space.m)
    }

    private var emptyCard: some View {
        ResourceGlassCard(size: .small, elevated: false) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "bookmark")
                    .foregroundStyle(.secondary)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("No templates").font(.callout.weight(.medium))
                    Text("Save a container's settings as a template from the create form.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func templateCard(_ template: Template) -> some View {
        ResourceGlassCard(size: .medium, elevated: false, onTap: { use(template) }) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "bookmark.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name).font(.callout.weight(.medium)).lineLimit(1)
                    Text(Format.shortImage(template.spec?.image ?? "—"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        } footerLeading: {
            Text("Saved run configuration").font(.caption).foregroundStyle(.secondary)
        } footerActions: {
            HStack(spacing: Tokens.Space.m) {
                Button(role: .destructive) { delete(template) } label: { Image(systemName: "trash").font(.body) }
                    .buttonStyle(.plain).foregroundStyle(.red).help("Delete").accessibilityLabel("Delete")
                Button("Use") { use(template) }.buttonStyle(.glassProminent).controlSize(.small)
            }
        }
        .contextMenu {
            Button { use(template) } label: { Label("Use", systemImage: "plus.circle") }
            Divider()
            Button(role: .destructive) { delete(template) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func use(_ template: Template) {
        guard let spec = template.spec else { return }
        onClose()
        ui.useTemplate(spec)
    }

    private func delete(_ template: Template) {
        modelContext.delete(template)
        try? modelContext.save()
    }
}

/// The toolbar's center element: a single search field that filters the current page live
/// (`ui.searchText`) and **expands in place** into the full command palette (it doesn't hide behind a
/// separate panel — the same field stays as the header, the results list drops below it). Opens on ⌘K,
/// on submit, or automatically when an in-page search comes up empty.
private struct ToolbarCommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.modalMaterial) private var modalMaterial
    @FocusState private var focused: Bool
    let insets: EdgeInsets

    private var isOpen: Bool { ui.activeMorph == .palette }
    private var items: [PaletteItem] { PaletteItem.filtered(ui.searchText, app: app, ui: ui) }
    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    /// Visual open state, animated explicitly off `isOpen` so the grow plays for every trigger
    /// (⌘K, submit, escalation) — implicit `.animation(value:)` wasn't firing for the size change.
    @State private var expanded = false

    private let collapsedWidth: CGFloat = Tokens.Toolbar.searchMaxWidth
    private let openWidth: CGFloat = 560
    private let openHeightCap: CGFloat = 480
    private var topInset: CGFloat { Tokens.Toolbar.topPadding }

    var body: some View {
        GeometryReader { geo in
            let openHeight = max(Tokens.Toolbar.controlHeight,
                                 min(openHeightCap, geo.size.height - topInset - insets.bottom))
            ZStack(alignment: .top) {
                if expanded {
                    Rectangle()
                        .fill(.black.opacity(0.28))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                        .transition(.opacity)
                }
                panel(openHeight: openHeight)
                    .frame(maxWidth: .infinity, alignment: .top)   // centered in the detail area
            }
        }
        .onChange(of: ui.searchText) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.pageResultCount) { _, _ in escalateIfEmpty() }
        .onChange(of: isOpen) { _, open in
            if open { ui.paletteIndex = 0 }
            focused = open
            withAnimation(spring) { expanded = open }
        }
        // ⌘S focuses the page-search field (without opening the palette).
        .onChange(of: ui.searchFocusToken) { _, _ in focused = true }
    }

    private func panel(openHeight: CGFloat) -> some View {
        // Drive visuals off `expanded` (animated), keeping the list mounted but faded + clipped when
        // collapsed so the height interpolates smoothly instead of the content popping in/out.
        let radius = expanded ? Tokens.Radius.sheet : Tokens.Toolbar.controlHeight / 2
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return VStack(spacing: 0) {
            fieldRow
                .frame(height: expanded ? Tokens.Toolbar.searchOpenHeaderHeight : Tokens.Toolbar.controlHeight)
            Divider().opacity(expanded ? 0.5 : 0)
            resultsList.opacity(expanded ? 1 : 0)
        }
        .frame(width: expanded ? openWidth : collapsedWidth,
               height: expanded ? openHeight : Tokens.Toolbar.controlHeight,
               alignment: .top)
        // Expanded, this reproduces `floatingPanelMaterial` exactly (ExteriorShadow .24/24/12 →
        // VisualEffectBackground in the chosen modal material → white .18 stroke), so the search palette
        // and the add-button morph render on the *same* surface and read as one gesture. Collapsed, it's
        // an interactive-glass capsule like the toolbar buttons.
        .background {
            if expanded {
                ExteriorShadow(cornerRadius: radius, color: .black.opacity(0.24), radius: 24, y: 12)
            }
        }
        .background {
            if expanded {
                VisualEffectBackground(material: modalMaterial.nsMaterial, blendingMode: .withinWindow)
                    .clipShape(shape)
            } else {
                Color.clear.glassEffect(.regular.interactive(), in: shape)
            }
        }
        .clipShape(shape)
        .overlay { if expanded { shape.strokeBorder(.white.opacity(0.18), lineWidth: 1) } }
        .padding(.top, topInset)
    }

    private var fieldRow: some View {
        @Bindable var ui = ui
        return HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: "magnifyingglass")
                .font(.body)                       // scales with the field text (Dynamic Type), like the buttons
                .foregroundStyle(.secondary)
            TextField(isOpen ? "Search or run a command…" : "Search this page, or ⌘K for commands",
                      text: $ui.searchText)
                .textFieldStyle(.plain)
                .font(.body).fontWeight(.medium)   // 13pt medium on macOS, Dynamic-Type scalable
                .focused($focused)
                .onSubmit { onSubmit() }
                .onKeyPress(.downArrow) { guard isOpen else { return .ignored }; move(1); return .handled }
                .onKeyPress(.upArrow) { guard isOpen else { return .ignored }; move(-1); return .handled }
                .onKeyPress(.escape) { guard isOpen else { return .ignored }; close(); return .handled }
            if !ui.searchText.isEmpty {
                Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Clear search").accessibilityLabel("Clear search")
            } else {
                Text(isOpen ? "esc" : "⌘K").font(.caption2).fontWeight(.medium).foregroundStyle(.tertiary)
            }
        }
        // Roomier horizontal inset once expanded so the field breathes inside the larger panel.
        .padding(.horizontal, expanded ? Tokens.Space.l : Tokens.Toolbar.searchInnerPadding)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == ui.paletteIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { run(item) }
                    }
                }
                .padding(.horizontal, Tokens.Space.m)   // roomier results gutter, matched to the open field
                .padding(.vertical, Tokens.Space.s)
            }
            .onChange(of: ui.paletteIndex) { _, new in proxy.scrollTo(new, anchor: .center) }
        }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: item.icon).foregroundStyle(item.tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if selected { Image(systemName: "return").font(.caption).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Behavior

    private func onSubmit() {
        if isOpen { runSelected() } else { ui.toggleMorph(.palette) }
    }

    /// Escalate an in-page search into the palette when a query (≥2 chars) finds nothing on a page that
    /// reports a count. Guards on `activeMorph == nil` so it only escalates once.
    private func escalateIfEmpty() {
        guard ui.activeMorph == nil else { return }
        let q = ui.searchText.trimmingCharacters(in: .whitespaces)
        if q.count >= 2, ui.pageResultCount == 0 { ui.activeMorph = .palette }
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        ui.paletteIndex = min(max(0, ui.paletteIndex + delta), items.count - 1)
    }

    private func runSelected() {
        guard items.indices.contains(ui.paletteIndex) else { return }
        run(items[ui.paletteIndex])
    }

    private func run(_ item: PaletteItem) {
        close()
        item.action()
    }

    private func close() {
        ui.activeMorph = nil
        ui.searchText = ""
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
private struct ToolbarSlotKey: PreferenceKey {
    static let defaultValue: [UIState.ToolbarMorph: CGRect] = [:]
    static func reduce(value: inout [UIState.ToolbarMorph: CGRect],
                       nextValue: () -> [UIState.ToolbarMorph: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
