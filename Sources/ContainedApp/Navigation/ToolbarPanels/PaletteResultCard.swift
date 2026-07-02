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
            designCard(symbol: "externaldrive",
                         title: volume.name,
                         subtitle: "Volume",
                         footer: "Use in a new run")
        case .network(let network):
            designCard(symbol: "network",
                         title: network.name,
                         subtitle: network.isBuiltin ? "Built-in network" : "Network",
                         footer: "Run a container on this network")
        case .tint(let tint):
            tintCard(tint)
        }
    }

    private var plainCard: some View {
        DesignCard(size: .small,
                     isSelected: selected,
                     fill: nil,
                     fillOpacity: selected ? DesignTokens.DesignCard.selectedSubtleFillOpacity : DesignTokens.DesignCard.plainFillOpacity,
                     elevated: false,
                     onTap: action,
                     title: item.title,
                     subtitle: item.subtitle) {
            DesignCardIconChip(symbol: item.icon,
                                 tint: item.tint,
                                 backgroundOpacity: selected
                                     ? DesignTokens.DesignCard.iconSelectedBackgroundOpacity
                                     : DesignTokens.DesignCard.iconBackgroundOpacity)
        } titleAccessory: {
            DesignBadgeText(text: item.kind.rawValue,
                              font: .caption2.weight(.semibold),
                              foreground: selected ? .accentColor : .secondary)
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            accessory
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func containerCard(_ snapshot: ContainerSnapshot) -> some View {
        let style = app.containerStyle(for: snapshot)
        let name = style.displayName(fallback: snapshot.id)
        let cardSize: DesignCardSize = snapshot.state == .running ? .large : .medium
        return DesignCard(size: cardSize,
                            isSelected: selected,
                            fill: style.fillBackground ? style.color : nil,
                            fillOpacity: selected ? DesignTokens.DesignCard.selectedPersonalizedFillOpacity : style.backgroundOpacity,
                            gradient: style.gradient,
                            gradientAngle: style.gradientAngle,
                            blendMode: style.backgroundBlendMode,
                            elevated: false,
                            onTap: action,
                            title: name,
                            subtitle: Format.shortImage(snapshot.image),
                            subtitleStyle: .monospaced) {
            DesignCardIconChip(symbol: style.symbol,
                                 tint: style.color,
                                 backgroundOpacity: selected
                                     ? DesignTokens.DesignCard.iconSelectedBackgroundOpacity
                                     : DesignTokens.DesignCard.iconBackgroundOpacity)
        } titleAccessory: {
            DesignBadgeText(text: snapshot.state.rawValue.capitalized,
                              font: .caption2.weight(.semibold),
                              foreground: snapshot.state == .running ? .green : .secondary)
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            containerStatus(snapshot)
        } footerActions: {
            accessory
        } widget: {
            if snapshot.state == .running {
                containerPaletteWidget(snapshot)
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
        return DesignCard(size: .medium,
                            isSelected: selected,
                            fill: style.fillBackground ? style.color : nil,
                            fillOpacity: selected ? DesignTokens.DesignCard.selectedPersonalizedFillOpacity : style.backgroundOpacity,
                            gradient: style.gradient,
                            gradientAngle: style.gradientAngle,
                            blendMode: style.backgroundBlendMode,
                            elevated: false,
                            onTap: action,
                            title: Format.shortImage(reference),
                            subtitle: repositoryTitle(reference),
                            titleStyle: .monospaced) {
            DesignCardIconChip(symbol: "tag",
                                 tint: style.color,
                                 backgroundOpacity: selected
                                     ? DesignTokens.DesignCard.iconSelectedBackgroundOpacity
                                     : DesignTokens.DesignCard.iconBackgroundOpacity)
        } titleAccessory: {
            DesignBadgeText(text: "Tag", font: .caption2.weight(.semibold))
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            DesignCardFooterMini {
                Image(systemName: style.symbol)
                    .font(.caption2)
                    .foregroundStyle(style.color)
            } text: {
                DesignCardMetricText(text: "Image")
                    .foregroundStyle(.secondary)
            }
        } footerActions: {
            accessory
        } widget: {
            EmptyView()
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func designCard(symbol: String, title: String, subtitle: String, footer: String) -> some View {
        DesignCard(size: .small,
                     isSelected: selected,
                     fill: nil,
                     fillOpacity: selected ? DesignTokens.DesignCard.selectedResourceFillOpacity : DesignTokens.DesignCard.plainFillOpacity,
                     elevated: false,
                     onTap: action,
                     title: title,
                     subtitle: footer) {
            DesignCardIconChip(symbol: symbol,
                                 tint: item.tint,
                                 backgroundOpacity: selected
                                     ? DesignTokens.DesignCard.iconSelectedBackgroundOpacity
                                     : DesignTokens.DesignCard.iconBackgroundOpacity)
        } titleAccessory: {
            DesignBadgeText(text: subtitle, font: .caption2.weight(.semibold))
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            accessory
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func tintCard(_ tint: DesignTint) -> some View {
        DesignCard(size: .small,
                     isSelected: selected,
                     fill: tint.color,
                     fillOpacity: selected ? DesignTokens.DesignCard.selectedTintFillOpacity : DesignTokens.DesignCard.selectedSubtleFillOpacity,
                     elevated: false,
                     onTap: action,
                     title: tint.localizedDisplayName,
                     subtitle: item.title) {
            DesignTintSwatch(color: tint.color, followsAccent: tint.followsAccent)
        } titleAccessory: {
            DesignBadgeText(text: app.settings.accentTint == tint ? AppText.current : AppText.tint,
                              font: .caption2.weight(.semibold),
                              foreground: app.settings.accentTint == tint ? .accentColor : .secondary)
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            accessory
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
        .selectionFill()
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func containerPaletteWidget(_ snapshot: ContainerSnapshot) -> some View {
        DesignCardWidgetGroup {
            DesignCardFooterMini {
                Image(systemName: "clock").font(.caption2)
            } text: {
                DesignCardMetricText(text: Format.uptime(since: snapshot.startedDate))
            }
            DesignCardFooterMini {
                Image(systemName: "network").font(.caption2)
            } text: {
                DesignCardMetricText(text: "\(snapshot.status.networks.count)")
            }
            DesignCardFooterMini {
                Image(systemName: "shippingbox").font(.caption2)
            } text: {
                DesignCardMetricText(text: Format.shortImage(snapshot.image))
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch item.accessory {
        case .run:
            if selected {
                Image(systemName: "return")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: DesignTokens.IconSize.chip, height: DesignTokens.IconSize.chip)
            } else {
                DesignListRowChevron()
                    .frame(width: DesignTokens.IconSize.chip, height: DesignTokens.IconSize.chip)
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
        DesignCardFooterMini {
            Image(systemName: snapshot.state == .running ? "circle.fill" : "circle")
                .font(.caption2)
                .foregroundStyle(snapshot.state == .running ? .green : .secondary)
        } text: {
            DesignCardMetricText(text: snapshot.state.rawValue.capitalized)
                .foregroundStyle(.secondary)
        }
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
