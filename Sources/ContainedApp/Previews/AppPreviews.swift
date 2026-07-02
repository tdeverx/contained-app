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
        var style = Personalization()
        style.nickname = "Preview Web"
        style.icon = "shippingbox.fill"
        style.tint = .azure
        style.fillBackground = true
        style.backgroundOpacity = 0.16
        style.widgets = WidgetConfiguration.defaultWidgets()
        return style
    }
}
