import SwiftUI
import ContainedUI
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
                         subtitle: AppText.string("palette.volume", defaultValue: "Volume"),
                         footer: AppText.string("palette.volume.footer", defaultValue: "Use in a new run"))
        case .network(let network):
            designCard(symbol: "network",
                         title: network.name,
                         subtitle: network.isBuiltin
                             ? AppText.string("palette.network.builtIn", defaultValue: "Built-in network")
                             : AppText.string("palette.network", defaultValue: "Network"),
                         footer: AppText.string("palette.network.footer", defaultValue: "Run a container on this network"))
        case .tint(let tint):
            tintCard(tint)
        }
    }

    private var plainCard: some View {
        UI.Card.Scaffold(size: .small,
                     isSelected: selected,
                     fill: nil,
                     fillOpacity: selected ? UI.Card.Metric.selectedSubtleFillOpacity : UI.Card.Metric.plainFillOpacity,
                     elevated: false,
                     onTap: action,
                     title: item.title,
                     subtitle: item.subtitle) {
            UI.Card.IconChip(symbol: item.icon,
                                 tint: item.tint,
                                 backgroundOpacity: selected
                                     ? UI.Card.Metric.iconSelectedBackgroundOpacity
                                     : UI.Card.Metric.iconBackgroundOpacity)
        } titleAccessory: {
            UI.Badge.Text(text: item.kind.localizedTitle,
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

    private func containerCard(_ snapshot: Core.Container.Snapshot) -> some View {
        let style = app.containerStyle(for: snapshot)
        let name = style.displayName(fallback: snapshot.id)
        let cardSize: UI.Card.Size = snapshot.state == .running ? .large : .medium
        return UI.Card.Scaffold(size: cardSize,
                            isSelected: selected,
                            fill: style.fillBackground ? style.color : nil,
                            fillOpacity: selected ? UI.Card.Metric.selectedPersonalizedFillOpacity : style.backgroundOpacity,
                            gradient: style.gradient,
                            gradientAngle: style.gradientAngle,
                            blendMode: style.backgroundBlendMode,
                            elevated: false,
                            onTap: action,
                            title: name,
                            subtitle: Format.shortImage(snapshot.image),
                            subtitleStyle: .monospaced) {
            UI.Card.IconChip(symbol: style.symbol,
                                 tint: style.color,
                                 backgroundOpacity: selected
                                     ? UI.Card.Metric.iconSelectedBackgroundOpacity
                                     : UI.Card.Metric.iconBackgroundOpacity)
        } titleAccessory: {
            UI.Badge.Text(text: snapshot.state.rawValue.capitalized,
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

    private func imageGroupCard(_ group: Core.Image.LocalTagGroup) -> some View {
        ToolbarImageGroupCard(group: group, isExpanded: false, onTap: action, onClose: {})
            .designCardSelectionOverlay(when: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func imageTagCard(_ reference: String, groupID: String) -> some View {
        let style = app.imageGroupStyle(forID: groupID)
        return UI.Card.Scaffold(size: .medium,
                            isSelected: selected,
                            fill: style.fillBackground ? style.color : nil,
                            fillOpacity: selected ? UI.Card.Metric.selectedPersonalizedFillOpacity : style.backgroundOpacity,
                            gradient: style.gradient,
                            gradientAngle: style.gradientAngle,
                            blendMode: style.backgroundBlendMode,
                            elevated: false,
                            onTap: action,
                            title: Format.shortImage(reference),
                            subtitle: repositoryTitle(reference),
                            titleStyle: .monospaced) {
            UI.Card.IconChip(symbol: "tag",
                                 tint: style.color,
                                 backgroundOpacity: selected
                                     ? UI.Card.Metric.iconSelectedBackgroundOpacity
                                     : UI.Card.Metric.iconBackgroundOpacity)
        } titleAccessory: {
            UI.Badge.Text(text: "Tag", font: .caption2.weight(.semibold))
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            UI.Card.FooterMini {
                UI.Symbol.Image(systemName: style.symbol,
                             tint: style.color,
                             size: .caption2)
            } text: {
                UI.Card.MetricText(text: "Image")
                    .designSecondaryValueStyle()
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
        UI.Card.Scaffold(size: .small,
                     isSelected: selected,
                     fill: nil,
                     fillOpacity: selected ? UI.Card.Metric.selectedResourceFillOpacity : UI.Card.Metric.plainFillOpacity,
                     elevated: false,
                     onTap: action,
                     title: title,
                     subtitle: footer) {
            UI.Card.IconChip(symbol: symbol,
                                 tint: item.tint,
                                 backgroundOpacity: selected
                                     ? UI.Card.Metric.iconSelectedBackgroundOpacity
                                     : UI.Card.Metric.iconBackgroundOpacity)
        } titleAccessory: {
            UI.Badge.Text(text: subtitle, font: .caption2.weight(.semibold))
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

    private func tintCard(_ tint: UI.Theme.Tint) -> some View {
        UI.Card.Scaffold(size: .small,
                     isSelected: selected,
                     fill: tint.color,
                     fillOpacity: selected ? UI.Card.Metric.selectedTintFillOpacity : UI.Card.Metric.selectedSubtleFillOpacity,
                     elevated: false,
                     onTap: action,
                     title: tint.localizedDisplayName,
                     subtitle: item.title) {
            UI.Control.TintSwatch(color: tint.color, followsAccent: tint.followsAccent)
        } titleAccessory: {
            UI.Badge.Text(text: app.settings.accentTint == tint ? AppText.current : AppText.tint,
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

    private func containerPaletteWidget(_ snapshot: Core.Container.Snapshot) -> some View {
        UI.Card.WidgetGroup {
            UI.Card.FooterMini {
                UI.Symbol.Image(systemName: "clock", size: .caption2)
            } text: {
                UI.Card.MetricText(text: Format.uptime(since: snapshot.startedDate))
            }
            UI.Card.FooterMini {
                UI.Symbol.Image(systemName: "network", size: .caption2)
            } text: {
                UI.Card.MetricText(text: "\(snapshot.status.networks.count)")
            }
            UI.Card.FooterMini {
                UI.Symbol.Image(systemName: "shippingbox", size: .caption2)
            } text: {
                UI.Card.MetricText(text: Format.shortImage(snapshot.image))
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch item.accessory {
        case .run:
            if selected {
                UI.Symbol.Image(systemName: "return",
                             tone: .tertiary,
                             size: .caption)
                    .frame(width: UI.Control.Size.chip, height: UI.Control.Size.chip)
            } else {
                UI.List.RowChevron()
                    .frame(width: UI.Control.Size.chip, height: UI.Control.Size.chip)
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
                .designTertiaryCaption()
        }
    }

    private func repositoryTitle(_ reference: String) -> String {
        let parsed = Core.Registry.ImageReference.parse(reference)
        return parsed.repository.split(separator: "/").map(String.init).last ?? parsed.repository
    }

    private func imageUpdateText(_ status: Core.Image.UpdateStatus) -> String {
        switch status.state {
        case .unknown: return "Not checked"
        case .checking: return "Checking for updates"
        case .current: return "Up to date"
        case .updateAvailable: return "Update available"
        case .error: return "Update check failed"
        }
    }

    private func containerStatus(_ snapshot: Core.Container.Snapshot) -> some View {
        UI.Card.FooterMini {
            UI.Symbol.Image(systemName: snapshot.state == .running ? "circle.fill" : "circle",
                         tone: snapshot.state == .running ? .success : .neutral,
                         size: .caption2)
        } text: {
            UI.Card.MetricText(text: snapshot.state.rawValue.capitalized)
                .designSecondaryValueStyle()
        }
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
