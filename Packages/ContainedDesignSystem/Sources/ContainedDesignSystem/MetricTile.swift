import SwiftUI

/// A dashboard summary tile: muted label, large value, optional symbol and sparkline.
public struct MetricTile: View {
    public let label: String
    public let value: String
    public var systemImage: String? = nil
    public var tint: Color = .accentColor
    public var samples: [Double]? = nil

    public init(label: String,
                value: String,
                systemImage: String? = nil,
                tint: Color = .accentColor,
                samples: [Double]? = nil) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.samples = samples
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.s) {
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
                LiveSparkline(samples: samples, color: tint)
                    .frame(height: 22)
            }
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card, fill: tint, fillOpacity: 0.10)
    }
}
