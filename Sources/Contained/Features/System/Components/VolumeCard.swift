import SwiftUI
import ContainedCore

struct VolumeCard: View {
    @Environment(AppModel.self) private var app
    let volume: VolumeResource
    var elevated = true
    var onInspect: () -> Void
    var onDelete: () -> Void

    @State private var localMetric: GraphMetric?

    private static let metrics: [GraphMetric] = [.diskRead, .diskWrite]
    private var style: Personalization { app.volumeStyle(for: volume.name) }
    private var activeWidget: WidgetConfiguration {
        style.widgets.first { $0.enabled } ?? style.widget(at: 0)
    }
    private var metric: GraphMetric {
        let stored = Self.metrics.contains(style.graphMetric) ? style.graphMetric : .diskRead
        return localMetric ?? stored
    }
    private var comparisonMetric: GraphMetric? {
        return style.graphStyle.resolvedSecondaryMetric(primary: metric,
                                                        requested: activeWidget.secondaryMetric,
                                                        options: Self.metrics)
    }
    private var graphColor: Color { activeWidget.tint?.color ?? style.color }
    private var samples: [Double] { app.volumeIOHistory(for: volume.name, metric: metric) }
    private var comparisonSamples: [Double] {
        comparisonMetric.map { app.volumeIOHistory(for: volume.name, metric: $0) } ?? []
    }

    private var subtitle: String {
        let config = volume.configuration
        let parts = [config.sizeInBytes.map { Format.bytes($0) }, config.format, config.source].compactMap { $0 }
        return parts.isEmpty ? "Local volume" : parts.joined(separator: "  ·  ")
    }

    var body: some View {
        ResourceGlassCard(size: .large,
                          fill: style.fillBackground ? style.color : nil,
                          fillOpacity: style.backgroundOpacity,
                          gradient: style.gradient,
                          gradientAngle: style.gradientAngle,
                          blendMode: style.backgroundBlendMode,
                          elevated: elevated) {
            ResourceCardHeader {
                CardStyleButton(style: style, target: .volume(name: volume.name), help: "Customize volume")
            } content: {
                VStack(alignment: .leading, spacing: 1) {
                    ResourceCardTitleText(text: style.nickname.isEmpty ? volume.name : style.nickname)
                    ResourceCardSubtitleText(text: subtitle)
                }
            } trailing: {
                EmptyView()
            }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            ForEach(Self.metrics) { chip($0) }
        } footerActions: {
            action("doc.text.magnifyingglass", help: "Inspect", action: onInspect)
            action("doc.on.doc", help: "Copy name") { copyToPasteboard(volume.name) }
            action("trash", help: "Delete", tint: .red, action: onDelete)
        } widget: {
            LiveSparkline(samples: samples,
                          comparisonSamples: comparisonSamples,
                          color: graphColor,
                          lineWidth: activeWidget.lineWidth,
                          style: style.graphStyle,
                          areaUsesGradient: activeWidget.areaUsesGradient,
                          interpolation: activeWidget.interpolation,
                          pointSize: activeWidget.pointSize,
                          barWidth: activeWidget.barWidth)
                .frame(height: 58)
        }
        .contextMenu { menu }
    }

    /// A tappable read/write chip showing the current rate; selecting it switches the plotted metric.
    private func chip(_ which: GraphMetric) -> some View {
        let active = metric == which
        let rate = app.volumeIORate(for: volume.name, metric: which)
        return Button { localMetric = which } label: {
            ResourceCardFooterMini {
                Image(systemName: which.systemImage).font(.caption2)
            } text: {
                ResourceCardMetricText(text: Format.compactRate(rate))
            }
            .foregroundStyle(active ? AnyShapeStyle(style.color) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .help(which == .diskRead ? "Read" : "Write")
        .accessibilityLabel(which == .diskRead ? "Read" : "Write")
    }

    private func action(_ systemName: String, help: String, tint: Color? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ResourceCardFooterMini {
                Image(systemName: systemName).font(.body)
            } text: {
                EmptyView()
            }
        }
            .buttonStyle(.plain)
            .foregroundStyle(tint ?? .secondary)
            .help(help)
            .accessibilityLabel(help)
    }

    @ViewBuilder
    private var menu: some View {
        Button(action: onInspect) { Label("Inspect", systemImage: "doc.text.magnifyingglass") }
        Button { copyToPasteboard(volume.name) } label: { Label("Copy name", systemImage: "doc.on.doc") }
        Divider()
        Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
    }
}

/// Viewer for `container system logs` — last 500 lines, with an optional live follow.
