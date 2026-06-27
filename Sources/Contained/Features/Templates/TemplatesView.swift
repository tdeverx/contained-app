import SwiftUI
import SwiftData
import ContainedCore

/// A gallery of the user's saved run templates. "Use" prefills the Create form; saved templates can
/// be deleted. (Built-in starters now live on the creation flow's search page, not here.)
struct TemplatesView: View {
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.createdAt, order: .reverse) private var saved: [Template]

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Tokens.Space.m)]

    var body: some View {
        Group {
            if saved.isEmpty {
                ContentUnavailableView {
                    Label("No saved templates", systemImage: "bookmark")
                } description: {
                    Text("Save a container's settings as a template from the create form to reuse them here.")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.l) {
                        section("Saved") {
                            ForEach(saved) { template in
                                card(name: template.name, symbol: "bookmark.fill",
                                     subtitle: Format.shortImage(template.spec?.image ?? "—"),
                                     onUse: { if let spec = template.spec { ui.useTemplate(spec) } },
                                     onDelete: { modelContext.delete(template); try? modelContext.save() })
                            }
                        }
                    }
                    .padding(Tokens.Space.l)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: Tokens.Space.m) { content() }
        }
    }

    private func card(name: String, symbol: String, subtitle: String,
                      onUse: @escaping () -> Void, onDelete: (() -> Void)?) -> some View {
        ResourceGlassCard(size: .medium, onTap: onUse) {
            HStack(spacing: Tokens.Space.m) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text(subtitle).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let onDelete {
                    Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
        } footerLeading: {
            Text("Saved run configuration").font(.caption).foregroundStyle(.secondary)
        } footerActions: {
            Button("Use") { onUse() }.buttonStyle(.glassProminent).controlSize(.small)
        }
        .contextMenu {
            Button { onUse() } label: { Label("Use", systemImage: "plus.circle") }
            if let onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
        }
    }
}
