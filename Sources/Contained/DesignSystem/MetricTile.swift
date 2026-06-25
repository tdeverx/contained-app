import SwiftUI

/// A dashboard summary tile: muted label, large value, optional symbol and sparkline.
struct MetricTile: View {
    let label: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .accentColor
    var samples: [Double]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.system(size: 24, weight: .semibold))
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
