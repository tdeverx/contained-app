import SwiftUI
import ContainedCore
import ContainedDesignSystem
import ContainedPreviewSupport

#Preview("Container Card") {
    ContainerCard(snapshot: PreviewSamples.webContainer,
                  style: .previewContainer,
                  density: .large,
                  stats: PreviewSamples.stats,
                  histories: [.cpu: PreviewSamples.sparklineBuffer],
                  isBusy: false,
                  isExpanded: true,
                  onTap: {},
                  onStart: {},
                  onStop: {},
                  onRestart: {},
                  onDelete: {})
        .padding(DesignTokens.Space.xl)
        .frame(width: 520)
        .environment(\.cardMaterial, .glassRegular)
        .environment(\.buttonMaterial, .glassClear)
}

#Preview("General Settings") {
    GeneralTab(settings: SettingsStore())
        .padding(DesignTokens.Space.xl)
        .frame(width: 560)
        .environment(AppModel())
        .environment(\.buttonMaterial, .glassClear)
        .environment(\.cardMaterial, .glassRegular)
}

private extension PreviewSamples {
    static var sparklineBuffer: SampleBuffer {
        var buffer = SampleBuffer()
        for value in sparklineValues {
            buffer.append(value)
        }
        return buffer
    }
}

private extension Personalization {
    static var previewContainer: Personalization {
        let sample = PreviewSamples.cardStyle
        var style = Personalization()
        style.nickname = PreviewSamples.webContainer.displayName
        style.icon = sample.symbol
        style.tint = DesignTint.parse(sample.tintName)
        style.fillBackground = sample.fillsBackground
        style.backgroundOpacity = sample.backgroundOpacity
        style.gradient = sample.usesGradient
        style.widgets = PreviewSamples.widgetConfigs.map(WidgetConfiguration.preview)
        return style
    }
}

private extension WidgetConfiguration {
    static func preview(_ descriptor: PreviewWidgetDescriptor) -> WidgetConfiguration {
        WidgetConfiguration(
            metric: descriptor.metric,
            secondaryMetric: descriptor.secondaryMetric,
            tint: descriptor.tintName.map(DesignTint.parse),
            icon: descriptor.icon,
            style: GraphStyle(rawValue: descriptor.style) ?? .area,
            showText: descriptor.showsText
        )
    }
}
