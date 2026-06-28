import SwiftUI
import SwiftData
import AppKit
import ContainedCore

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Search stays in the top-right titlebar band; the add/images/templates/activity cluster and
/// system status control float in a bottom toolbar area.
///
/// Mounted as a top overlay over the **detail column** in `RootView` (never over the sidebar): the
/// band sits in the title-bar region, the rest of the area is hit-transparent until a control opens.
/// The add `+`, search field, and bottom toolbar controls all grow through the same
/// `MorphingExpander` shell from their measured toolbar slots. Control sizing and source radius come
/// from `Tokens.Toolbar` / `ToolbarControls`.
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.appSafeAreas) private var safeAreas

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?
    @State private var toolbarImageDetail: LocalImageTagGroup?
    @State private var toolbarImageSourceFrame: CGRect?
    @State private var toolbarImageDetailPresented = false
    @State private var toolbarImageCloseRequestToken = 0

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding. Sourced from `Tokens.Toolbar` so the band, the safe-area
    /// manager, and the controls all agree.
    static let bandHeight: CGFloat = Tokens.Toolbar.band

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                topToolbarRow
                    .frame(height: Tokens.Toolbar.controlHeight)
                    .padding(.top, rowTopInset)   // centered on the traffic-light line
                Spacer(minLength: 0)
                    .allowsHitTesting(false)
                bottomToolbarRow
                    .frame(height: Tokens.Toolbar.controlHeight)
                    .padding(.bottom, bottomRowInset)
            }
            addMorphLayer
                .zIndex(ui.activeMorph == .add ? 30 : 0)
            paletteMorphLayer
                .zIndex(ui.activeMorph == .palette ? 30 : 0)
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

    // MARK: Top Row

    private var topToolbarRow: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            Spacer(minLength: Tokens.Space.m)
            searchZone
        }
        // Leading inset clears the window traffic lights now that the toolbar spans the full window.
        .padding(.leading, Tokens.Toolbar.leadingInset)
        .padding(.trailing, Tokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    private var searchZone: some View {
        ToolbarSearchSource()
            .frame(width: Tokens.Toolbar.searchMaxWidth, height: Tokens.Toolbar.controlHeight)
            .opacity(ui.activeMorph == .palette ? 0 : 1)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ToolbarSlotKey.self,
                                           value: [.palette: proxy.frame(in: .named(Self.space))])
                }
            )
    }

    @ViewBuilder
    private var paletteMorphLayer: some View {
        if ui.activeMorph == .palette {
            MorphingExpander(isPresented: paletteMorphBinding,
                             originFrame: slots[.palette] ?? .zero,
                             target: toolbarMorphTarget(size: CGSize(width: 560, height: 480)),
                             closeRequestToken: ui.morphCloseRequestToken) {
                ToolbarCommandPalette { ui.requestMorphClose(.palette) }
            }
        }
    }

    // MARK: Bottom Row

    private var bottomToolbarRow: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            systemStatusButton
            Spacer(minLength: Tokens.Space.m)
            bottomActionGroup
        }
        .padding(.horizontal, Tokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    private var systemStatusButton: some View {
        GlassButton(singleItem: true) {
            GlassButtonItem(help: "System \(app.serviceLabel)", action: {
                ui.toggleMorph(.system)
            }) {
                HStack(spacing: Tokens.Toolbar.searchIconGap) {
                    Image(systemName: systemStatusIcon)
                        .foregroundStyle(systemStatusColor)
                        .frame(width: Tokens.Toolbar.buttonItemHeight - Tokens.Toolbar.iconInnerPadding * 2)
                    Text(app.serviceLabel)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, Tokens.Toolbar.iconInnerPadding * 2)
                }
            }
        }
        .opacity(ui.activeMorph == .system ? 0 : 1)
        .background(singleSlotReader(.system))
    }

    private var bottomActionGroup: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            GlassButton {
                GlassButtonItem(systemName: "plus", help: "Add") { ui.toggleMorph(.add) }
                GlassButtonItem(systemName: "shippingbox", help: "Images") { ui.toggleMorph(.updates) }
                GlassButtonItem(systemName: "bookmark", help: "Templates") { ui.toggleMorph(.templates) }
                GlassButtonItem(systemName: "bell", help: "Activity") { ui.toggleMorph(.activity) }
            }
            .opacity(isBottomGroupMorphActive ? 0 : 1)
            .background(clusterSlotReader([.add, .updates, .templates, .activity]))
        }
    }

    // MARK: Add morph layer

    @ViewBuilder
    private var addMorphLayer: some View {
        if ui.activeMorph == .add {
            MorphingExpander(isPresented: addMorphBinding, originFrame: slots[.add] ?? .zero,
                             target: toolbarMorphTarget(size: CGSize(width: 440, height: 300)),
                             closeRequestToken: ui.morphCloseRequestToken,
                             onBackdropTap: addSoftDismiss) {
                CreationFlow(start: .menu,
                             onClose: {
                                 addSoftDismiss = nil
                                 ui.requestMorphClose(.add)
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
                             target: toolbarMorphTarget(size: CGSize(width: 440, height: 300)),
                             closeRequestToken: ui.morphCloseRequestToken) {
                ToolbarUpdatesPanel(onOpenImage: openToolbarImageDetail) {
                    ui.requestMorphClose(.updates)
                }
            }
        }
    }

    @ViewBuilder
    private var toolbarImageDetailLayer: some View {
        if let detail = toolbarImageDetail, toolbarImageDetailPresented {
            MorphingExpander(isPresented: toolbarImageDetailBinding,
                             originFrame: usableToolbarImageSource ?? .zero,
                             target: .anchored(size: toolbarImageDetailSize,
                                               safeArea: toolbarMorphSafeArea,
                                               margin: 0),
                             closeRequestToken: toolbarImageCloseRequestToken) {
                ToolbarImageGroupCard(group: currentToolbarImageGroup(detail),
                                      isExpanded: true,
                                      onTap: {},
                                      onClose: closeToolbarImageDetail)
            }
        }
    }

    @ViewBuilder
    private var activityMorphLayer: some View {
        if ui.activeMorph == .activity {
            MorphingExpander(isPresented: morphBinding(.activity),
                             originFrame: slots[.activity] ?? .zero,
                             target: toolbarMorphTarget(size: CGSize(width: 460, height: 360)),
                             closeRequestToken: ui.morphCloseRequestToken) {
                ToolbarActivityPanel {
                    ui.requestMorphClose(.activity)
                }
            }
        }
    }

    @ViewBuilder
    private var templatesMorphLayer: some View {
        if ui.activeMorph == .templates {
            MorphingExpander(isPresented: morphBinding(.templates),
                             originFrame: slots[.templates] ?? .zero,
                             target: toolbarMorphTarget(size: CGSize(width: 440, height: 300)),
                             closeRequestToken: ui.morphCloseRequestToken) {
                ToolbarTemplatesPanel {
                    ui.requestMorphClose(.templates)
                }
            }
        }
    }

    @ViewBuilder
    private var systemMorphLayer: some View {
        if ui.activeMorph == .system {
            MorphingExpander(isPresented: morphBinding(.system),
                             originFrame: slots[.system] ?? .zero,
                             target: toolbarMorphTarget(size: CGSize(width: 580, height: 600)),
                             closeRequestToken: ui.morphCloseRequestToken) {
                ToolbarSystemPanel { ui.requestMorphClose(.system) }
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

    private var paletteMorphBinding: Binding<Bool> {
        Binding(get: { ui.activeMorph == .palette }, set: {
            if !$0 {
                ui.searchText = ""
                ui.activeMorph = nil
            }
        })
    }

    private var toolbarImageDetailBinding: Binding<Bool> {
        Binding(get: { toolbarImageDetailPresented }, set: {
            guard !$0 else {
                toolbarImageDetailPresented = true
                return
            }
            toolbarImageDetailPresented = false
            toolbarImageDetail = nil
            toolbarImageSourceFrame = nil
        })
    }

    /// Report one shared frame (the cluster capsule) as the morph origin for several morphs at once.
    private func clusterSlotReader(_ morphs: [UIState.ToolbarMorph]) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(Self.space))
            Color.clear.preference(key: ToolbarSlotKey.self,
                                   value: Dictionary(uniqueKeysWithValues: morphs.map { ($0, frame) }))
        }
    }

    private func singleSlotReader(_ morph: UIState.ToolbarMorph) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ToolbarSlotKey.self,
                                   value: [morph: proxy.frame(in: .named(Self.space))])
        }
    }

    private var toolbarMorphSafeArea: AppSafeAreaPolicy {
        .toolbarChrome
    }

    private func toolbarMorphTarget(size: CGSize,
                                    placement: MorphPanelPlacement = .anchored) -> AppMorphTarget {
        switch placement {
        case .anchored:
            .anchored(size: size, safeArea: toolbarMorphSafeArea, margin: 0)
        case .centered:
            .centered(size: size, safeArea: toolbarMorphSafeArea, margin: 0)
        case .topCentered:
            .topCentered(safeArea: toolbarMorphSafeArea, margin: 0) { _ in size }
        }
    }

    private var rowTopInset: CGFloat { Tokens.Toolbar.topPadding }

    private var bottomRowInset: CGFloat {
        max(Tokens.Toolbar.outerPadding, safeAreas.system.bottom + Tokens.Toolbar.outerPadding)
    }

    private var systemStatusColor: Color {
        switch app.serviceLabel {
        case "Running":
            .green
        case "Checking…":
            .blue
        case "Stopped":
            .orange
        default:
            .red
        }
    }

    private var systemStatusIcon: String {
        switch app.serviceLabel {
        case "Running":
            "circle.fill"
        case "Checking…":
            "arrow.triangle.2.circlepath"
        case "Stopped":
            "pause.circle.fill"
        default:
            "exclamationmark.triangle.fill"
        }
    }

    private var isBottomGroupMorphActive: Bool {
        switch ui.activeMorph {
        case .add, .updates, .templates, .activity:
            true
        case .palette, .system, nil:
            false
        }
    }

    private var usableToolbarImageSource: CGRect? {
        guard let frame = toolbarImageSourceFrame,
              frame.width.isFinite, frame.height.isFinite,
              frame.minX.isFinite, frame.minY.isFinite,
              frame.width > 1, frame.height > 1
        else { return nil }
        return frame
    }

    private var toolbarImageDetailSize: CGSize {
        CGSize(width: 560, height: 520)
    }

    private func currentToolbarImageGroup(_ group: LocalImageTagGroup) -> LocalImageTagGroup {
        LocalImageTagGroup.groups(for: app.images).first { $0.id == group.id } ?? group
    }

    private func openToolbarImageDetail(_ group: LocalImageTagGroup, sourceFrame: CGRect) {
        toolbarImageDetail = group
        toolbarImageSourceFrame = sourceFrame
        toolbarImageDetailPresented = true
    }

    private func closeToolbarImageDetail() {
        toolbarImageCloseRequestToken &+= 1
    }
}

private struct ToolbarUpdatesPanel: View {
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
        .padding(Tokens.Space.m)
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

private struct ToolbarActivityPanel: View {
    var onClose: () -> Void

    var body: some View {
        ActivityContent(showClose: true, elevated: false, onClose: onClose)
            .morphPanelSize(CGSize(width: 560, height: 520))
            .morphPanelPlacement(.anchored)
    }
}

/// The toolbar System panel — service status, volumes, disk usage, and the Prune Center as flat glass
/// cards (the same treatment as the Images/Templates panels). New Volume hands off to the creation
/// flow (closing the panel first).
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
        ResourceCardHeader {
            GlassButtonItem(systemName: "bookmark", help: "Templates", isLabel: true)
        } content: {
            VStack(alignment: .leading, spacing: 1) {
                Text("Templates").font(.headline)
                Text("\(saved.count) saved").font(.caption).foregroundStyle(.secondary)
            }
        } trailing: {
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
            }
        }
        .padding(Tokens.Space.m)
    }

    private var emptyCard: some View {
        ResourceGlassCard(size: .small, elevated: false) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: "bookmark", tint: .secondary, backgroundOpacity: 0.22)
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: "No templates")
                    ResourceCardSubtitleText(text: "Save a container's settings as a template from the create form.")
                }
            } trailing: {
                EmptyView()
            }
        }
    }

    private func templateCard(_ template: Template) -> some View {
        ResourceGlassCard(size: .medium, elevated: false, onTap: { use(template) }) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: "bookmark.fill", tint: .accentColor)
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: template.name)
                    ResourceCardMonospacedSubtitleText(text: Format.shortImage(template.spec?.image ?? "—"))
                }
            } trailing: {
                EmptyView()
            }
        } footerLeading: {
            ResourceCardSubtitleText(text: "Saved run configuration")
        } footerActions: {
            Button(role: .destructive) { delete(template) } label: {
                ResourceCardFooterMini {
                    Image(systemName: "trash").font(.body)
                } text: {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help("Delete")
            .accessibilityLabel("Delete")
            Button("Use") { use(template) }.buttonStyle(.glassProminent).controlSize(.small)
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

/// The collapsed toolbar search source. It owns the measured `.palette` slot; the expanded command
/// surface is rendered by `MorphingExpander`, so the source can hide while the panel owns the glass.
private struct ToolbarSearchSource: View {
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var ui = ui
        return GlassButton(singleItem: true) {
            GlassButtonInputItem {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)
                TextField("Search this page, or ⌘K for commands", text: $ui.searchText)
                    .textFieldStyle(.plain)
                    .font(.body).fontWeight(.medium)
                    .focused($focused)
                    .onSubmit { ui.activeMorph = .palette }
                if !ui.searchText.isEmpty {
                    Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Clear search")
                        .accessibilityLabel("Clear search")
                } else {
                    Text("⌘K")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Capsule(style: .continuous))
        .simultaneousGesture(TapGesture().onEnded { focused = true })
        .onChange(of: ui.searchText) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.pageResultCount) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.searchFocusToken) { _, _ in focused = true }
        .onChange(of: ui.activeMorph) { _, morph in
            if morph != nil { focused = false }
        }
        .onExitCommand { focused = false }
        .onKeyPress(.escape) {
            focused = false
            return .handled
        }
    }

    private func escalateIfEmpty() {
        guard ui.activeMorph == nil else { return }
        let query = ui.searchText.trimmingCharacters(in: .whitespaces)
        if query.count >= 2, ui.pageResultCount == 0 {
            ui.activeMorph = .palette
        }
    }
}

/// The expanded command palette content hosted inside `MorphingExpander`.
private struct ToolbarCommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool
    var onClose: () -> Void

    private var isOpen: Bool { ui.activeMorph == .palette }
    private var items: [PaletteItem] { PaletteItem.filtered(ui.searchText, app: app, ui: ui) }

    var body: some View {
        VStack(spacing: 0) {
            fieldRow
                .frame(height: Tokens.Toolbar.searchOpenHeaderHeight)
            Divider().opacity(0.5)
            resultsList
        }
        .morphPanelSize(CGSize(width: 560, height: 480))
        .morphPanelPlacement(.anchored)
        .onAppear {
            ui.paletteIndex = 0
            focused = true
        }
    }

    private var fieldRow: some View {
        @Bindable var ui = ui
        return HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: "magnifyingglass")
                .font(.body)                       // scales with the field text (Dynamic Type), like the buttons
                .foregroundStyle(.secondary)
            TextField("Search or run a command…", text: $ui.searchText)
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
                Text("esc").font(.caption2).fontWeight(.medium).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
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
        runSelected()
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
        onClose()
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
