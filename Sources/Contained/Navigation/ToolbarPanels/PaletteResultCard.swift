import SwiftUI
import ContainedDesignSystem
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
                          fillOpacity: selected ? Tokens.ResourceCard.selectedSubtleFillOpacity : Tokens.ResourceCard.plainFillOpacity,
                          elevated: false,
                          onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: item.icon,
                                     tint: item.tint,
                                     backgroundOpacity: selected
                                         ? Tokens.ResourceCard.iconSelectedBackgroundOpacity
                                         : Tokens.ResourceCard.iconBackgroundOpacity)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
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
        let cardSize: ResourceCardSize = snapshot.state == .running ? .large : .medium
        return ResourceGlassCard(size: cardSize,
                                 isSelected: selected,
                                 fill: style.fillBackground ? style.color : nil,
                                 fillOpacity: selected ? Tokens.ResourceCard.selectedPersonalizedFillOpacity : style.backgroundOpacity,
                                 gradient: style.gradient,
                                 gradientAngle: style.gradientAngle,
                                 blendMode: style.backgroundBlendMode,
                                 elevated: false,
                                 onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: style.symbol,
                                     tint: style.color,
                                     backgroundOpacity: selected
                                         ? Tokens.ResourceCard.iconSelectedBackgroundOpacity
                                         : Tokens.ResourceCard.iconBackgroundOpacity)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardTitleText(text: name)
                        ResourceBadgeText(text: snapshot.state.rawValue.capitalized,
                                          font: .caption2.weight(.semibold),
                                          foreground: snapshot.state == .running ? .green : .secondary)
                    }
                    ResourceCardMonospacedSubtitleText(text: Format.shortImage(snapshot.image))
                }
            } trailing: {
                EmptyView()
            }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            containerStatus(snapshot)
        } footerActions: {
            accessory
        } widget: {
            if snapshot.state == .running {
                containerPaletteWidget(snapshot)
                    .padding(.horizontal, Tokens.ResourceCard.padding)
                    .padding(.bottom, Tokens.ResourceCard.padding)
            }
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func imageGroupCard(_ group: LocalImageTagGroup) -> some View {
        ToolbarImageGroupCard(group: group, isExpanded: false, onTap: action, onClose: {})
            .designCardSelectionOverlay(when: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func imageTagCard(_ reference: String, groupID: String) -> some View {
        let style = app.imageGroupStyle(forID: groupID)
        return ResourceGlassCard(size: .medium,
                                 isSelected: selected,
                                 fill: style.fillBackground ? style.color : nil,
                                 fillOpacity: selected ? Tokens.ResourceCard.selectedPersonalizedFillOpacity : style.backgroundOpacity,
                                 gradient: style.gradient,
                                 gradientAngle: style.gradientAngle,
                                 blendMode: style.backgroundBlendMode,
                                 elevated: false,
                                 onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: "tag",
                                     tint: style.color,
                                     backgroundOpacity: selected
                                         ? Tokens.ResourceCard.iconSelectedBackgroundOpacity
                                         : Tokens.ResourceCard.iconBackgroundOpacity)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
                    HStack(spacing: Tokens.Space.s) {
                        ResourceCardMonospacedTitleText(text: Format.shortImage(reference))
                        ResourceBadgeText(text: "Tag", font: .caption2.weight(.semibold))
                    }
                    ResourceCardSubtitleText(text: repositoryTitle(reference))
                }
            } trailing: {
                EmptyView()
            }
        } footerLeading: {
            ResourceCardFooterMini {
                Image(systemName: style.symbol)
                    .font(.caption2)
                    .foregroundStyle(style.color)
            } text: {
                ResourceCardMetricText(text: "Image")
                    .foregroundStyle(.secondary)
            }
        } footerActions: {
            accessory
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func resourceCard(symbol: String, title: String, subtitle: String, footer: String) -> some View {
        ResourceGlassCard(size: .small,
                          isSelected: selected,
                          fill: nil,
                          fillOpacity: selected ? Tokens.ResourceCard.selectedResourceFillOpacity : Tokens.ResourceCard.plainFillOpacity,
                          elevated: false,
                          onTap: action) {
            ResourceCardHeader {
                ResourceCardIconChip(symbol: symbol,
                                     tint: item.tint,
                                     backgroundOpacity: selected
                                         ? Tokens.ResourceCard.iconSelectedBackgroundOpacity
                                         : Tokens.ResourceCard.iconBackgroundOpacity)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
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
                          fillOpacity: selected ? Tokens.ResourceCard.selectedTintFillOpacity : Tokens.ResourceCard.selectedSubtleFillOpacity,
                          elevated: false,
                          onTap: action) {
            ResourceCardHeader {
                DesignTintSwatch(color: tint.color, followsAppAccent: tint.followsAppAccent)
            } content: {
                VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
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

    private func containerPaletteWidget(_ snapshot: ContainerSnapshot) -> some View {
        HStack(spacing: Tokens.ResourceCard.padding) {
            ResourceCardFooterMini {
                Image(systemName: "clock").font(.caption2)
            } text: {
                ResourceCardMetricText(text: Format.uptime(since: snapshot.startedDate))
            }
            ResourceCardFooterMini {
                Image(systemName: "network").font(.caption2)
            } text: {
                ResourceCardMetricText(text: "\(snapshot.status.networks.count)")
            }
            ResourceCardFooterMini {
                Image(systemName: "shippingbox").font(.caption2)
            } text: {
                ResourceCardMetricText(text: Format.shortImage(snapshot.image))
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func containerStatus(_ snapshot: ContainerSnapshot) -> some View {
        ResourceCardFooterMini {
            Image(systemName: snapshot.state == .running ? "circle.fill" : "circle")
                .font(.caption2)
                .foregroundStyle(snapshot.state == .running ? .green : .secondary)
        } text: {
            ResourceCardMetricText(text: snapshot.state.rawValue.capitalized)
                .foregroundStyle(.secondary)
        }
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
