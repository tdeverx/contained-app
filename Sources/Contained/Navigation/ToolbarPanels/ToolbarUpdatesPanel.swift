import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import SwiftData
import AppKit
import ContainedCore

struct ToolbarUpdatesPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var showClose = true
    var coordinateSpaceName = AppToolbar.space
    var hiddenImageGroupID: LocalImageTagGroup.ID?
    var onOpenImage: (LocalImageTagGroup, CGRect) -> Void
    var onClose: () -> Void
    @State private var imageFrames: [LocalImageTagGroup.ID: CGRect] = [:]

    private var imageGroups: [LocalImageTagGroup] {
        sortedImageGroups(app.localImageGroups().filter(matchesFilter))
    }

    private var imageSections: [(title: String, groups: [LocalImageTagGroup])] {
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
        MorphPanelScaffold(width: Tokens.PanelSize.images.width) {
            if showsHeader {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider()
                }
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                if imageGroups.isEmpty {
                    emptyCard
                } else {
                    ForEach(Array(imageSections.enumerated()), id: \.offset) { _, section in
                        if ui.imageGrouping != .none {
                            ResourceBadgeText(text: section.title, font: .caption.weight(.semibold))
                                .padding(.horizontal, Tokens.Space.xs)
                        }
                        ForEach(section.groups) { group in
                            imageRow(group)
                        }
                    }
                }
            }
            .padding(Tokens.Space.s)
        }
        .task { await app.refreshImagesIfStale() }
    }

    private var header: some View {
        PanelHeader(symbol: "square.stack.3d.up",
                    title: "Images",
                    subtitle: "\(imageGroups.count) local · \(updateCount) update\(updateCount == 1 ? "" : "s")") {
            GlassButton {
                GlassButtonItem(systemName: "square.and.arrow.down", help: "Load Image Tar") {
                    ui.dispatch(.loadImage)
                    onClose()
                }
                GlassButtonItem(systemName: "arrow.triangle.2.circlepath", help: "Check for Updates") {
                    Task { await app.runImageUpdateSweepNow() }
                }
                GlassButtonItem(systemName: "trash", role: .destructive, help: "Prune Images") {
                    ui.dispatch(.pruneImages)
                    onClose()
                }
                if showClose {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                }
            }
        }
    }

    private var emptyCard: some View {
        ResourceCard(size: .small,
                     elevated: false,
                     title: "No images",
                     subtitle: "Pull or build an image to see it here") {
            ResourceCardIconChip(symbol: "checkmark.circle.fill", tint: .green)
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

    private func imageRow(_ group: LocalImageTagGroup) -> some View {
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

    private func updateImageFrame(_ frame: CGRect, for id: LocalImageTagGroup.ID) {
        guard imageFrames[id]?.isClose(to: frame) != true else { return }
        imageFrames[id] = frame
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

    private func sortedImageGroups(_ groups: [LocalImageTagGroup]) -> [LocalImageTagGroup] {
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

    private func matchesFilter(_ group: LocalImageTagGroup) -> Bool {
        switch ui.imageFilter {
        case .all:
            return true
        case .updates:
            return app.imageUpdateStatus(for: group.primaryReference).state == .updateAvailable
        case .errors:
            return app.imageUpdateStatus(for: group.primaryReference).state == .error
        }
    }

    private func registryTitle(_ group: LocalImageTagGroup) -> String {
        let parsed = RegistryImageReference.parse(group.primaryReference)
        return parsed.registry == "registry-1.docker.io" ? "docker.io" : parsed.registry
    }

    private func statusTitle(_ group: LocalImageTagGroup) -> String {
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
