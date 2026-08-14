import SwiftUI
import ContainedUX
import ContainedUI
import SwiftData
import ContainedCore

struct ToolbarUpdatesPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var coordinateSpaceName = AppToolbar.space
    var hiddenImageGroupID: Core.Image.LocalTagGroup.ID?
    var onOpenImage: (Core.Image.LocalTagGroup, CGRect) -> Void
    var onClose: () -> Void
    @State private var imageFrames: [Core.Image.LocalTagGroup.ID: CGRect] = [:]
    @State private var settledUpdateStates: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState] = [:]
    @State private var page: ImagePage?

    enum ImagePage: String, CaseIterable, Identifiable {
        case updates = "Updates"
        case images = "Images"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .updates: return AppText.string("image.page.updates", defaultValue: "Updates")
            case .images: return AppText.sectionImages
            }
        }

        var systemImage: String {
            switch self {
            case .updates: return "arrow.down.circle"
            case .images: return "square.stack.3d.up"
            }
        }

        static func defaultPage(updateCount: Int) -> Self {
            updateCount > 0 ? .updates : .images
        }
    }

    private struct Projection {
        var activePage: ImagePage
        var liveUpdateStates: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState]
        var updateCount: Int
        var groups: [Core.Image.LocalTagGroup]
        var sections: [(title: String, groups: [Core.Image.LocalTagGroup])]

        var isCheckingForUpdates: Bool {
            liveUpdateStates.values.contains(.checking)
        }
    }

    var body: some View {
        let projection = makeProjection()
        UI.Panel.Scaffold(width: UI.Panel.Size.images.width) {
            VStack(alignment: .leading, spacing: 0) {
                header(projection)
                Divider()
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                if projection.groups.isEmpty {
                    emptyCard(for: projection.activePage)
                } else {
                    ForEach(Array(projection.sections.enumerated()), id: \.offset) { _, section in
                        if ui.imageGrouping != .none {
                            UI.Badge.Text(text: section.title, font: .caption.weight(.semibold))
                                .padding(.horizontal, UI.Layout.Spacing.xs)
                        }
                        ForEach(section.groups) { group in
                            imageRow(group)
                        }
                    }
                }
            }
            .padding(UI.Layout.Spacing.s)
        }
        .onAppear {
            rememberSettledUpdateStates(projection.liveUpdateStates)
        }
        .onChange(of: projection.liveUpdateStates) { _, states in
            rememberSettledUpdateStates(states)
        }
        .task { await app.refreshImagesIfNeeded() }
    }

    private func header(_ projection: Projection) -> some View {
        UI.Panel.Header(symbol: projection.activePage.systemImage,
                    title: AppText.sectionImages,
                    subtitle: headerSubtitle(for: projection)) {
            HStack(spacing: UI.Toolbar.Spacing.groupSpacing) {
                UI.Action.Group(checkForUpdatesAction(isChecking: projection.isCheckingForUpdates))
                if projection.activePage == .images {
                    UI.Action.Cluster {
                        imageFilterMenu
                        UI.Action.Items(imagePageActions)
                    }
                }
                UI.Action.Group(navigationActions(activePage: projection.activePage))
            }
        }
    }

    private func headerSubtitle(for projection: Projection) -> String {
        switch projection.activePage {
        case .updates:
            return AppText.string("image.page.updates.subtitle",
                                  defaultValue: "\(projection.updateCount) update\(projection.updateCount == 1 ? "" : "s") available")
        case .images:
            return AppText.string("image.updates.subtitle",
                                  defaultValue: "\(projection.groups.count) local · \(projection.updateCount) update\(projection.updateCount == 1 ? "" : "s")")
        }
    }

    private var imageFilterMenu: some View {
        @Bindable var ui = ui
        return Menu {
            Picker(AppText.string("toolbar.groupBy", defaultValue: "Group by"), selection: $ui.imageGrouping) {
                ForEach(ImageGrouping.allCases) { grouping in
                    Label(grouping.title, systemImage: grouping.symbol).tag(grouping)
                }
            }
            .pickerStyle(.inline)
            Picker(AppText.string("toolbar.sortBy", defaultValue: "Sort by"), selection: $ui.imageSort) {
                ForEach(ImageSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.symbol).tag(sort)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker(AppText.string("activity.filter", defaultValue: "Filter"), selection: $ui.imageFilter) {
                ForEach(ImageFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol).tag(filter)
                }
            }
            .pickerStyle(.inline)
        } label: {
            UI.Action.MenuLabel(systemName: ui.imageFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill",
                                help: AppText.string("toolbar.imageFilters", defaultValue: "Image filters"))
        }
        .buttonStyle(.plain)
    }

    private func checkForUpdatesAction(isChecking: Bool) -> UI.Action.Item {
        UI.Action.Item(systemName: "arrow.triangle.2.circlepath",
                       help: AppText.runImageUpdateCheckNow,
                       isEnabled: !isChecking) {
            Task { await app.runImageUpdateSweepNow() }
        }
    }

    private var imagePageActions: [UI.Action.Item] {
        [
            UI.Action.Item(systemName: "square.and.arrow.down", help: AppText.loadImageTar) {
                    ui.dispatch(.loadImage)
                    onClose()
            },
            UI.Action.Item(systemName: "trash", help: AppText.pruneImages, role: .destructive) {
                    ui.dispatch(.pruneImages)
                    onClose()
            }
        ]
    }

    private func navigationActions(activePage: ImagePage) -> [UI.Action.Item] {
        var actions = ImagePage.allCases.map { item in
            UI.Action.Item(systemName: item.systemImage,
                           help: item.title,
                           tint: activePage == item ? .accentColor : nil) {
                page = item
            }
        }
        actions.append(UI.Action.Item(systemName: "xmark",
                                     help: AppText.close,
                                     isCancel: true,
                                     action: onClose))
        return actions
    }

    private func emptyCard(for page: ImagePage) -> some View {
        UI.Card.Scaffold(size: .small,
                     elevated: false,
                     title: emptyTitle(for: page),
                     subtitle: emptySubtitle(for: page)) {
            UI.Card.IconChip(symbol: page == .updates ? "checkmark.circle.fill" : "square.stack.3d.up",
                             tint: page == .updates ? .green : .secondary)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
    }

    private func emptyTitle(for page: ImagePage) -> String {
        switch page {
        case .updates: return AppText.string("image.updates.empty", defaultValue: "No image updates")
        case .images: return AppText.string("image.empty", defaultValue: "No images")
        }
    }

    private func emptySubtitle(for page: ImagePage) -> String {
        switch page {
        case .updates:
            return AppText.string("image.updates.empty.subtitle", defaultValue: "Your local images are up to date")
        case .images:
            return AppText.string("image.empty.subtitle", defaultValue: "Pull or build an image to see it here")
        }
    }

    private func imageRow(_ group: Core.Image.LocalTagGroup) -> some View {
        ToolbarImageGroupCard(group: group,
                              isExpanded: false,
                              onTap: {
                                  onOpenImage(group, imageFrames[group.id] ?? .zero)
                              },
                              onClose: {})
            .opacity(hiddenImageGroupID == group.id ? 0 : 1)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateImageFrame(proxy.frame(in: .named(coordinateSpaceName)), for: group.id)
                        }
                        .onChange(of: proxy.frame(in: .named(coordinateSpaceName))) { _, frame in
                            updateImageFrame(frame, for: group.id)
                        }
                }
            }
    }

    private func updateImageFrame(_ frame: CGRect, for id: Core.Image.LocalTagGroup.ID) {
        guard imageFrames[id]?.isClose(to: frame) != true else { return }
        imageFrames[id] = frame
    }

    private func imageRank(_ group: Core.Image.LocalTagGroup,
                           states: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState]) -> Int {
        switch states[group.id] ?? .unknown {
        case .updateAvailable: return 0
        case .error: return 1
        case .checking, .unknown: return 2
        case .current: return 3
        }
    }

    private func sortedImageGroups(
        _ groups: [Core.Image.LocalTagGroup],
        states: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState]
    ) -> [Core.Image.LocalTagGroup] {
        groups.sorted { lhs, rhs in
            switch ui.imageSort {
            case .status:
                let lhsRank = imageRank(lhs, states: states)
                let rhsRank = imageRank(rhs, states: states)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
            case .tags:
                if lhs.references.count != rhs.references.count { return lhs.references.count > rhs.references.count }
            case .name:
                break
            }
            return lhs.primaryReference.localizedCaseInsensitiveCompare(rhs.primaryReference) == .orderedAscending
        }
    }

    private func matchesFilter(
        _ group: Core.Image.LocalTagGroup,
        states: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState]
    ) -> Bool {
        switch ui.imageFilter {
        case .all:
            return true
        case .updates:
            return states[group.id] == .updateAvailable
        case .errors:
            return states[group.id] == .error
        }
    }

    private func registryTitle(_ group: Core.Image.LocalTagGroup) -> String {
        let parsed = Core.Registry.ImageReference.parse(group.primaryReference)
        return parsed.registry == "registry-1.docker.io" ? "docker.io" : parsed.registry
    }

    private func statusTitle(
        _ group: Core.Image.LocalTagGroup,
        states: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState]
    ) -> String {
        switch states[group.id] ?? .unknown {
        case .updateAvailable: return "Updates available"
        case .error: return "Errors"
        case .checking, .unknown: return "Unknown"
        case .current: return "Current"
        }
    }

    private func statusRank(_ title: String) -> Int {
        switch title {
        case "Updates available": return 0
        case "Errors": return 1
        case "Unknown": return 2
        default: return 3
        }
    }

    private func makeProjection() -> Projection {
        let allGroups = app.localImageGroups()
        let liveStates = allGroups.reduce(into: [:]) { states, group in
            states[group.id] = app.imageUpdateStatus(for: group).state
        }
        let effectiveStates = liveStates.mapValues { state in
            state == .checking ? nil : state
        }
        .reduce(into: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState]()) { states, entry in
            states[entry.key] = entry.value ?? settledUpdateStates[entry.key] ?? .unknown
        }
        let updateCount = effectiveStates.values.count(where: { $0 == .updateAvailable })
        let activePage = page ?? .defaultPage(updateCount: updateCount)
        let visibleGroups = allGroups.filter { group in
            switch activePage {
            case .updates:
                return effectiveStates[group.id] == .updateAvailable
            case .images:
                return matchesFilter(group, states: effectiveStates)
            }
        }
        let groups = sortedImageGroups(visibleGroups, states: effectiveStates)
        let sections: [(title: String, groups: [Core.Image.LocalTagGroup])]
        switch ui.imageGrouping {
        case .none:
            sections = [("", groups)]
        case .registry:
            sections = Dictionary(grouping: groups, by: registryTitle)
                .map { ($0.key, sortedImageGroups($0.value, states: effectiveStates)) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .status:
            sections = Dictionary(grouping: groups) { statusTitle($0, states: effectiveStates) }
                .map { ($0.key, sortedImageGroups($0.value, states: effectiveStates)) }
                .sorted { lhs, rhs in statusRank(lhs.title) < statusRank(rhs.title) }
        }
        return Projection(activePage: activePage,
                          liveUpdateStates: liveStates,
                          updateCount: updateCount,
                          groups: groups,
                          sections: sections)
    }

    private func rememberSettledUpdateStates(
        _ states: [Core.Image.LocalTagGroup.ID: Core.Image.UpdateState]
    ) {
        var settled = settledUpdateStates.filter { states[$0.key] != nil }
        for (id, state) in states where state != .checking {
            settled[id] = state
        }
        guard settled != settledUpdateStates else { return }
        settledUpdateStates = settled
    }

}

private extension CGRect {
    func isClose(to other: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(minX - other.minX) <= tolerance &&
        abs(minY - other.minY) <= tolerance &&
        abs(width - other.width) <= tolerance &&
        abs(height - other.height) <= tolerance
    }
}
