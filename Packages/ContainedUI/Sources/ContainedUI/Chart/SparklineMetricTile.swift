import SwiftUI

/// A dashboard summary tile: muted label, large value, optional symbol and sparkline.
public extension UI.Chart {
struct MetricTile: View {
    public let label: String
    public let value: String
    public var systemImage: String? = nil
    public var tint: Color = .accentColor
    public var samples: [Double]? = nil
    public var sparklineScale: UI.Chart.Scale = .normalized

    @Environment(\.cardMaterial) private var cardMaterial

    public init(label: String,
                value: String,
                systemImage: String? = nil,
                tint: Color = .accentColor,
                samples: [Double]? = nil,
                sparklineScale: UI.Chart.Scale = .normalized) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.samples = samples
        self.sparklineScale = sparklineScale
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: UI.Tokens.Space.s) {
            HStack(spacing: UI.Tokens.Space.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.medium))
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.title.weight(.semibold))
                .contentTransition(.numericText())
            if let samples {
                UI.Chart.Sparkline(samples: samples, color: tint, scale: sparklineScale)
                    .frame(height: 22)
            }
        }
        .padding(UI.Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .designCardMaterial(cardMaterial,
                            cornerRadius: UI.Tokens.Radius.card,
                            shadow: false,
                            fill: nil,
                            fillOpacity: 0,
                            gradient: false,
                            gradientAngle: 0,
                            blendMode: .normal)
    }
}
}

#Preview("Chart Metric Tile") {
    HStack(spacing: UI.Tokens.Space.m) {
        UI.Chart.MetricTile(label: "CPU",
                            value: "62%",
                            systemImage: "cpu",
                            tint: .accentColor,
                            samples: [0.2, 0.35, 0.32, 0.62, 0.58],
                            sparklineScale: .fraction)
        UI.Chart.MetricTile(label: "Network",
                            value: "186 KB/s",
                            systemImage: "network",
                            tint: .teal,
                            samples: [40, 82, 70, 126, 110])
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 520)
}
