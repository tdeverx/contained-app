import SwiftUI

struct ExteriorShadow: View {
    var cornerRadius: CGFloat
    var color: Color
    var radius: CGFloat
    var y: CGFloat

    init(cornerRadius: CGFloat, color: Color, radius: CGFloat, y: CGFloat) {
        self.cornerRadius = cornerRadius
        self.color = color
        self.radius = radius
        self.y = y
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape
                .fill(color)
                .blur(radius: radius)
                .offset(y: y)
            shape
                .fill(.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}
