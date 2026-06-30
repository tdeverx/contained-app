import SwiftUI
import SwiftData
import AppKit
import ContainedCore

struct ToolbarUpdatesPanel: View {
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
        MorphPanelScaffold(width: Tokens.PanelSize.images.width) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                if imageGroups.isEmpty {
                    emptyCard
                } else {
                    ForEach(imageGroups) { group in
                        imageRow(group)
                    }
                }
            }
            .padding(Tokens.Space.s)
        }
        .task { await app.refreshImagesIfStale(force: true) }
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
                GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
            }
        }
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

