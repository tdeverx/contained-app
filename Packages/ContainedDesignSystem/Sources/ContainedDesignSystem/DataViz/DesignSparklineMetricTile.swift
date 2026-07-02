import SwiftUI

/// A dashboard summary tile: muted label, large value, optional symbol and sparkline.
public struct DesignSparklineMetricTile: View {
    public let label: String
    public let value: String
    public var systemImage: String? = nil
    public var tint: Color = .accentColor
    public var samples: [Double]? = nil
    public var sparklineScale: SparklineScale = .normalized

    public init(label: String,
                value: String,
                systemImage: String? = nil,
                tint: Color = .accentColor,
                samples: [Double]? = nil,
                sparklineScale: SparklineScale = .normalized) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.samples = samples
        self.sparklineScale = sparklineScale
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            HStack(spacing: DesignTokens.Space.s) {
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
                LiveSparkline(samples: samples, color: tint, scale: sparklineScale)
                    .frame(height: 22)
            }
        }
        .padding(DesignTokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.regular, cornerRadius: DesignTokens.Radius.card, fill: tint, fillOpacity: 0.10)
    }
}
