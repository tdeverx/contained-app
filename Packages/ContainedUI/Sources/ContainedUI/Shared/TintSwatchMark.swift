import SwiftUI

struct SharedTintSwatchMark: View {
    var color: Color
    var markerSystemName: String?
    var markerForeground: Color
    var selected: Bool?
    var size: CGFloat
    var fillSize: CGFloat
    var ringSize: CGFloat

    init(color: Color,
         markerSystemName: String? = nil,
         markerForeground: Color = .white,
         selected: Bool? = nil,
         size: CGFloat = 26,
         fillSize: CGFloat = 22,
         ringSize: CGFloat = 24) {
        self.color = color
        self.markerSystemName = markerSystemName
        self.markerForeground = markerForeground
        self.selected = selected
        self.size = size
        self.fillSize = fillSize
        self.ringSize = ringSize
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: fillSize, height: fillSize)
            if let markerSystemName {
                Image(systemName: markerSystemName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(markerForeground)
            }
            if let selected {
                Circle()
                    .strokeBorder(selected ? Color.primary : Color.secondary.opacity(0.35),
                                  lineWidth: selected ? 2 : 1)
                    .frame(width: ringSize, height: ringSize)
            }
        }
        .frame(width: size, height: size)
    }
}
