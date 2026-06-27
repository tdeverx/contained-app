import SwiftUI
import SwiftData
import ContainedCore

/// A gallery of run templates: built-in starters plus the user's saved recipes. "Use" prefills the
/// Create form; saved templates can be deleted.
struct TemplatesView: View {
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Template.createdAt, order: .reverse) private var saved: [Template]

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Tokens.Space.m)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                section("Starters") {
                    ForEach(BuiltinTemplate.all, id: \.name) { item in
                        card(name: item.name, symbol: item.symbol, subtitle: Format.shortImage(item.spec.image),
                             onUse: { ui.useTemplate(item.spec) }, onDelete: nil)
                    }
                }
                if !saved.isEmpty {
                    section("Saved") {
                        ForEach(saved) { template in
                            card(name: template.name, symbol: "bookmark.fill",
                                 subtitle: Format.shortImage(template.spec?.image ?? "—"),
                                 onUse: { if let spec = template.spec { ui.useTemplate(spec) } },
                                 onDelete: { modelContext.delete(template); try? modelContext.save() })
                        }
                    }
                }
            }
            .padding(Tokens.Space.l)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: Tokens.Space.m) { content() }
        }
    }

    private func card(name: String, symbol: String, subtitle: String,
                      onUse: @escaping () -> Void, onDelete: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack {
                Image(systemName: symbol).font(.title2).foregroundStyle(Color.accentColor)
                Spacer()
                if let onDelete {
                    Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            Text(name).font(.headline)
            Text(subtitle).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            Button("Use") { onUse() }.buttonStyle(.glassProminent).controlSize(.small)
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card)
        .contextMenu {
            Button { onUse() } label: { Label("Use", systemImage: "plus.circle") }
            if let onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            }
        }
    }
}
