import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import SwiftData
import AppKit
import ContainedCore

struct ToolbarActivityPanel: View {
    var onClose: () -> Void

    var body: some View {
        // ActivityContent owns its design scaffold and morph sizing preferences.
        ActivityContent(showClose: true, elevated: false, onClose: onClose)
    }
}

/// The toolbar System panel — service status, volumes, disk usage, and the Prune Center as flat glass
/// cards (the same treatment as the Images/Templates panels). New Volume hands off to the creation
/// flow (closing the panel first).
struct ToolbarSystemPanel: View {
    var onClose: () -> Void

    var body: some View {
        // SystemContent owns its design scaffold and morph sizing preferences.
        SystemContent(elevated: false, onClose: onClose)
    }
}

/// The toolbar Settings panel — the app preferences (Appearance, General, Runtime, Registries,
/// Updates, About) hosted in the morph panel instead of the separate `Settings` window. Sections switch
/// via the header menu inside `SettingsContent` (no `TabView`).
struct ToolbarSettingsPanel: View {
    var onClose: () -> Void

    var body: some View {
        // SettingsContent owns its design scaffold and centered morph placement.
        SettingsContent(onClose: onClose)
    }
}

/// The toolbar Templates panel — saved run configurations as flat glass cards (the same treatment as
/// the Images panel). "Use" prefills the create form; cards can be deleted.
struct ToolbarTemplatesPanel: View {
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.createdAt, order: .reverse) private var saved: [Template]
    var showClose = true
    var onClose: () -> Void

    private var showsHeader: Bool {
        showClose || !ui.toolbarUIEnabled
    }

    private var sortedTemplates: [Template] {
        saved.sorted { lhs, rhs in
            switch ui.templateSort {
            case .newest:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            case .name:
                if lhs.name.localizedCaseInsensitiveCompare(rhs.name) != .orderedSame {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            case .image:
                let lhsImage = lhs.spec?.image ?? ""
                let rhsImage = rhs.spec?.image ?? ""
                if lhsImage.localizedCaseInsensitiveCompare(rhsImage) != .orderedSame {
                    return lhsImage.localizedCaseInsensitiveCompare(rhsImage) == .orderedAscending
                }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var templateSections: [(title: String, templates: [Template])] {
        switch ui.templateGrouping {
        case .none:
            return [("", sortedTemplates)]
        case .image:
            return Dictionary(grouping: sortedTemplates, by: templateImageTitle)
                .map { ($0.key, $0.value) }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        DesignPanelScaffold(width: DesignTokens.PanelSize.templates.width) {
            if showsHeader {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Divider()
                }
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Space.s) {
                if sortedTemplates.isEmpty {
                    emptyCard
                } else {
                    ForEach(Array(templateSections.enumerated()), id: \.offset) { _, section in
                        if ui.templateGrouping != .none {
                            DesignBadgeText(text: section.title, font: .caption.weight(.semibold))
                                .padding(.horizontal, DesignTokens.Space.xs)
                        }
                        ForEach(section.templates) { template in templateCard(template) }
                    }
                }
            }
            .padding(DesignTokens.Space.s)
        }
    }

    private var header: some View {
        PanelHeader(symbol: "bookmark",
                    title: AppText.sectionTemplates,
                    subtitle: AppText.string("template.savedCount", defaultValue: "\(saved.count) saved")) {
            if showClose {
                DesignActionGroup(DesignAction(systemName: "xmark",
                                               help: AppText.close,
                                               isCancel: true,
                                               action: onClose))
            }
        }
    }

    private var emptyCard: some View {
        DesignCard(size: .small,
                     elevated: false,
                     title: AppText.string("template.empty", defaultValue: "No templates"),
                     subtitle: AppText.string("template.empty.subtitle", defaultValue: "Save a container's settings as a template from the create form.")) {
            DesignCardIconChip(symbol: "bookmark",
                                 tint: .secondary,
                                 backgroundOpacity: DesignTokens.DesignCard.iconEmphasisBackgroundOpacity)
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

    private func templateCard(_ template: Template) -> some View {
        DesignCard(size: .medium,
                     elevated: false,
                     onTap: { use(template) },
                     title: template.name,
                     subtitle: Format.shortImage(template.spec?.image ?? "—"),
                     subtitleStyle: .monospaced) {
            DesignCardIconChip(symbol: "bookmark.fill", tint: .accentColor)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            // Chevron affordance: tapping the card hands off to the create morph (parity with the
            // image cards that grow into the morph detail).
            DesignListRowChevron()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            DesignCardFooterMini {
                Image(systemName: "bookmark").font(.caption2)
            } text: {
                DesignCardMetricText(text: "Saved run configuration")
            }
        } footerActions: {
            Button(role: .destructive) { delete(template) } label: {
                DesignCardFooterMini {
                    Image(systemName: "trash").font(.body)
                } text: {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help("Delete")
            .accessibilityLabel(AppText.delete)
            DesignTextActionButton(title: AppText.string("common.use", defaultValue: "Use"),
                                   systemName: "plus.circle",
                                   prominence: .prominent,
                                   controlSize: .small) {
                use(template)
            }
        } widget: {
            EmptyView()
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

    private func templateImageTitle(_ template: Template) -> String {
        let image = template.spec?.image.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return image.isEmpty ? "No image" : Format.shortImage(image)
    }
}

/// The collapsed toolbar search source. It owns the measured `.palette` slot; the expanded command
/// surface is rendered by `MorphingExpander`, so the source can hide while the panel owns the glass.
