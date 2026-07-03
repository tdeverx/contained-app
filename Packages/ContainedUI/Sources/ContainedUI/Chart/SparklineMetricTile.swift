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
        .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card, fill: tint, fillOpacity: 0.10)
    }
}
}
