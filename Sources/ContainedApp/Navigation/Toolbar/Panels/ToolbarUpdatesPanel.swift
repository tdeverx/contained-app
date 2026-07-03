import SwiftUI
import ContainedUX
import ContainedUI
import SwiftData
import ContainedCore

struct ToolbarUpdatesPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var showClose = true
    var coordinateSpaceName = AppToolbar.space
    var hiddenImageGroupID: Core.Image.LocalTagGroup.ID?
    var onOpenImage: (Core.Image.LocalTagGroup, CGRect) -> Void
    var onClose: () -> Void
    @State private var imageFrames: [Core.Image.LocalTagGroup.ID: CGRect] = [:]

    private var imageGroups: [Core.Image.LocalTagGroup] {
        sortedImageGroups(app.localImageGroups().filter(matchesFilter))
    }

    private var imageSections: [(title: String, groups: [Core.Image.LocalTagGroup])] {
        switch ui.imageGrouping {
        case .none:
            return [("", imageGroups)]
        case .registry:
            return Dictionary(grouping: imageGroups, by: registryTitle)
                .map { ($0.key, sortedImageGroups($0.value)) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .status:
            return Dictionary(grouping: imageGroups, by: statusTitle)
                .map { ($0.key, sortedImageGroups($0.value)) }
                .sorted { lhs, rhs in statusRank(lhs.title) < statusRank(rhs.title) }
        }
    }

    private var updateCount: Int {
        app.localImageGroups().filter {
            app.imageUpdateStatus(for: $0.primaryReference).state == .updateAvailable
        }.count
    }

    private var showsHeader: Bool {
        showClose || !ui.toolbarUIEnabled
    }

    var body: some View {
        UI.Panel.Scaffold(width: UI.Panel.Size.images.width) {
            if showsHeader {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider()
                }
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                if imageGroups.isEmpty {
                    emptyCard
                } else {
                    ForEach(Array(imageSections.enumerated()), id: \.offset) { _, section in
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
        .task { await app.refreshImagesIfNeeded() }
    }

    private var header: some View {
        UI.Panel.Header(symbol: "square.stack.3d.up",
                    title: AppText.sectionImages,
                    subtitle: AppText.string("image.updates.subtitle", defaultValue: "\(imageGroups.count) local · \(updateCount) update\(updateCount == 1 ? "" : "s")")) {
            UI.Action.Group(imageHeaderActions)
        }
    }

    private var imageHeaderActions: [UI.Action.Item] {
        var actions = [
            UI.Action.Item(systemName: "square.and.arrow.down", help: AppText.loadImageTar) {
                    ui.dispatch(.loadImage)
                    onClose()
            },
            UI.Action.Item(systemName: "arrow.triangle.2.circlepath", help: AppText.checkForUpdates) {
                    Task { await app.runImageUpdateSweepNow() }
            },
            UI.Action.Item(systemName: "trash", help: AppText.pruneImages, role: .destructive) {
                    ui.dispatch(.pruneImages)
                    onClose()
            }
        ]
        if showClose {
            actions.append(UI.Action.Item(systemName: "xmark", help: AppText.close, isCancel: true, action: onClose))
        }
        return actions
    }

    private var emptyCard: some View {
        UI.Card.Scaffold(size: .small,
                     elevated: false,
                     title: AppText.string("image.empty", defaultValue: "No images"),
                     subtitle: AppText.string("image.empty.subtitle", defaultValue: "Pull or build an image to see it here")) {
            UI.Card.IconChip(symbol: "checkmark.circle.fill", tint: .green)
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

    private func imageRank(_ group: Core.Image.LocalTagGroup) -> Int {
        switch app.imageUpdateStatus(for: group.primaryReference).state {
        case .updateAvailable: return 0
        case .error: return 1
        case .checking: return 2
        case .unknown: return 3
        case .current: return 4
        }
    }

    private func sortedImageGroups(_ groups: [Core.Image.LocalTagGroup]) -> [Core.Image.LocalTagGroup] {
        groups.sorted { lhs, rhs in
            switch ui.imageSort {
            case .status:
                let lhsRank = imageRank(lhs)
                let rhsRank = imageRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
            case .tags:
                if lhs.references.count != rhs.references.count { return lhs.references.count > rhs.references.count }
            case .name:
                break
            }
            return lhs.primaryReference.localizedCaseInsensitiveCompare(rhs.primaryReference) == .orderedAscending
        }
    }

    private func matchesFilter(_ group: Core.Image.LocalTagGroup) -> Bool {
        switch ui.imageFilter {
        case .all:
            return true
        case .updates:
            return app.imageUpdateStatus(for: group.primaryReference).state == .updateAvailable
        case .errors:
            return app.imageUpdateStatus(for: group.primaryReference).state == .error
        }
    }

    private func registryTitle(_ group: Core.Image.LocalTagGroup) -> String {
        let parsed = Core.Registry.ImageReference.parse(group.primaryReference)
        return parsed.registry == "registry-1.docker.io" ? "docker.io" : parsed.registry
    }

    private func statusTitle(_ group: Core.Image.LocalTagGroup) -> String {
        switch app.imageUpdateStatus(for: group.primaryReference).state {
        case .updateAvailable: return "Updates available"
        case .error: return "Errors"
        case .checking: return "Checking"
        case .unknown: return "Unknown"
        case .current: return "Current"
        }
    }

    private func statusRank(_ title: String) -> Int {
        switch title {
        case "Updates available": return 0
        case "Errors": return 1
        case "Checking": return 2
        case "Unknown": return 3
        default: return 4
        }
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
