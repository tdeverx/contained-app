import SwiftUI
import AppKit
import ContainedCore

/// One result row in the command palette. Renders a different card layout per `PaletteItem.visual`
/// (plain action, container, image group/tag, volume, network), with selection highlighting.
struct PaletteResultCard: View {
    @Environment(AppModel.self) private var app
    let item: PaletteItem
    let selected: Bool
    var action: () -> Void

    var body: some View {
        switch item.visual {
        case .plain:
            plainCard
        case .container(let snapshot):
            containerCard(snapshot)
        case .imageGroup(let group):
            imageGroupCard(group)
        case .imageTag(let reference, let groupID):
            imageTagCard(reference, groupID: groupID)
        case .volume(let volume):
            resourceCard(symbol: "externaldrive",
                         title: volume.name,
                         subtitle: "Volume",
                         footer: "Use in a new run")
        case .network(let network):
            resourceCard(symbol: "network",
                         title: network.name,
                         subtitle: network.isBuiltin ? "Built-in network" : "Network",
                         footer: "Run a container on this network")
        case .tint(let tint):
            tintCard(tint)
        }
    }

    private var plainCard: some View {
        ResourceGlassCard(size: .small,
                          isSelected: selected,
                          fill: nil,
                          fillOpacity: selected ? 0.10 : 0.18,
                          elevated: false,
                          onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: item.icon, tint: item.tint, backgroundOpacity: selected ? 0.24 : 0.16)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardTitleText(text: item.title)
                        ResourceBadgeText(text: item.kind.rawValue,
                                          font: .caption2.weight(.semibold),
                                          foreground: selected ? .accentColor : .secondary)
                    }
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        ResourceCardSubtitleText(text: subtitle)
                    }
                }
            } trailing: {
                accessory
            }
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func containerCard(_ snapshot: ContainerSnapshot) -> some View {
        let style = app.containerStyle(for: snapshot)
        let name = style.displayName(fallback: snapshot.id)
        return ResourceGlassCard(size: .small,
                                 isSelected: selected,
                                 fill: style.fillBackground ? style.color : nil,
                                 fillOpacity: selected ? 0.14 : style.backgroundOpacity,
                                 gradient: style.gradient,
                                 gradientAngle: style.gradientAngle,
                                 elevated: false,
                                 onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: style.symbol, tint: style.color, backgroundOpacity: selected ? 0.24 : 0.16)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardTitleText(text: name)
                        ResourceBadgeText(text: snapshot.state.rawValue.capitalized,
                                          font: .caption2.weight(.semibold),
                                          foreground: snapshot.state == .running ? .green : .secondary)
                    }
                    ResourceCardMonospacedSubtitleText(text: Format.shortImage(snapshot.image))
                }
            } trailing: {
                accessory
            }
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func imageGroupCard(_ group: LocalImageTagGroup) -> some View {
        let style = app.imageGroupStyle(for: group)
        let status = app.imageUpdateStatus(for: group.primaryReference)
        return ResourceGlassCard(size: .small,
                                 isSelected: selected,
                                 fill: style.fillBackground ? style.color : nil,
                                 fillOpacity: selected ? 0.14 : style.backgroundOpacity,
                                 gradient: style.gradient,
                                 gradientAngle: style.gradientAngle,
                                 elevated: false,
                                 onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: style.symbol, tint: style.color, backgroundOpacity: selected ? 0.24 : 0.16)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardTitleText(text: repositoryTitle(group.primaryReference))
                        ResourceBadgeText(text: "\(group.references.count) tag\(group.references.count == 1 ? "" : "s")",
                                          font: .caption2.weight(.semibold))
                    }
                    ResourceCardMonospacedSubtitleText(text: Format.shortImage(group.primaryReference))
                    ResourceCardSubtitleText(text: imageUpdateText(status))
                }
            } trailing: {
                accessory
            }
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func imageTagCard(_ reference: String, groupID: String) -> some View {
        let style = app.imageGroupStyle(forID: groupID)
        return ResourceGlassCard(size: .small,
                                 isSelected: selected,
                                 fill: style.fillBackground ? style.color : nil,
                                 fillOpacity: selected ? 0.14 : style.backgroundOpacity,
                                 gradient: style.gradient,
                                 gradientAngle: style.gradientAngle,
                                 elevated: false,
                                 onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: "tag", tint: style.color, backgroundOpacity: selected ? 0.24 : 0.16)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardMonospacedTitleText(text: Format.shortImage(reference))
                        ResourceBadgeText(text: "Tag", font: .caption2.weight(.semibold))
                    }
                    ResourceCardSubtitleText(text: repositoryTitle(reference))
                }
            } trailing: {
                accessory
            }
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func resourceCard(symbol: String, title: String, subtitle: String, footer: String) -> some View {
        ResourceGlassCard(size: .small,
                          isSelected: selected,
                          fill: nil,
                          fillOpacity: selected ? 0.12 : 0.18,
                          elevated: false,
                          onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: symbol, tint: item.tint, backgroundOpacity: selected ? 0.24 : 0.16)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardTitleText(text: title)
                        ResourceBadgeText(text: subtitle, font: .caption2.weight(.semibold))
                    }
                    ResourceCardSubtitleText(text: footer)
                }
            } trailing: {
                accessory
            }
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func tintCard(_ tint: AppTint) -> some View {
        ResourceGlassCard(size: .small,
                          isSelected: selected,
                          fill: tint.color,
                          fillOpacity: selected ? 0.18 : 0.10,
                          elevated: false,
                          onTap: action) {
            ResourceCardHeader {
                ZStack {
                    Circle().fill(tint.color)
                    if tint.followsAppAccent {
                        Image(systemName: "link")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardTitleText(text: tint.displayName)
                        ResourceBadgeText(text: app.settings.accentTint == tint ? "Current" : "Tint",
                                          font: .caption2.weight(.semibold),
                                          foreground: app.settings.accentTint == tint ? .accentColor : .secondary)
                    }
                    ResourceCardSubtitleText(text: item.title)
                }
            } trailing: {
                accessory
            }
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var accessory: some View {
        switch item.accessory {
        case .run:
            if selected {
                Image(systemName: "return")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            } else {
                GlassListRowChevron()
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            }
        case .toggle(let isOn, let set):
            Toggle("", isOn: Binding {
                isOn()
            } set: { newValue in
                set(newValue)
            })
                .labelsHidden()
                .toggleStyle(.switch)
        case .disabled(let reason):
            Text(reason)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func repositoryTitle(_ reference: String) -> String {
        let parsed = RegistryImageReference.parse(reference)
        return parsed.repository.split(separator: "/").map(String.init).last ?? parsed.repository
    }

    private func imageUpdateText(_ status: ImageUpdateStatus) -> String {
        switch status.state {
        case .unknown: return "Not checked"
        case .checking: return "Checking for updates"
        case .current: return "Up to date"
        case .updateAvailable: return "Update available"
        case .error: return "Update check failed"
        }
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
