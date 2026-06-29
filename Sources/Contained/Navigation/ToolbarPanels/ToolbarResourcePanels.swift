import SwiftUI
import SwiftData
import AppKit
import ContainedCore

struct ToolbarActivityPanel: View {
    var onClose: () -> Void

    var body: some View {
        // Size + placement are reported by the MorphPanelScaffold inside ActivityContent (it hugs its
        // content height), so no fixed morphPanelSize here.
        ActivityContent(showClose: true, elevated: false, onClose: onClose)
    }
}

/// The toolbar System panel — service status, volumes, disk usage, and the Prune Center as flat glass
/// cards (the same treatment as the Images/Templates panels). New Volume hands off to the creation
/// flow (closing the panel first).
struct ToolbarSystemPanel: View {
    var onClose: () -> Void

    var body: some View {
        // Size + placement are reported by the MorphPanelScaffold inside SystemContent (it hugs its
        // content height), so no fixed morphPanelSize here.
        SystemContent(elevated: false, onClose: onClose)
    }
}

/// The toolbar Settings panel — the app preferences (Appearance, General, Runtime, Registries,
/// Updates, About) hosted in the morph panel instead of the separate `Settings` window. Sections switch
/// via the header menu inside `SettingsContent` (no `TabView`).
struct ToolbarSettingsPanel: View {
    var onClose: () -> Void

    var body: some View {
        // Size + placement are reported by the MorphPanelScaffold inside SettingsContent (it hugs its
        // content height and centers), so no fixed morphPanelSize here.
        SettingsContent(onClose: onClose)
    }
}

/// The toolbar Templates panel — saved run configurations as flat glass cards (the same treatment as
/// the Images panel). "Use" prefills the create form; cards can be deleted.
struct ToolbarTemplatesPanel: View {
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.createdAt, order: .reverse) private var saved: [Template]
    var onClose: () -> Void

    var body: some View {
        MorphPanelScaffold(width: Tokens.PanelSize.templates.width) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                if saved.isEmpty {
                    emptyCard
                } else {
                    ForEach(saved) { template in templateCard(template) }
                }
            }
            .padding(Tokens.Space.s)
        }
    }

    private var header: some View {
        PanelHeader(symbol: "bookmark",
                    title: "Templates",
                    subtitle: "\(saved.count) saved") {
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
            }
        }
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
                // Chevron affordance: tapping the card hands off to the create morph (parity with the
                // image cards that grow into the morph detail).
                GlassListRowChevron()
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
