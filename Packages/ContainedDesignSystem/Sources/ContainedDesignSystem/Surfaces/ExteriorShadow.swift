import SwiftUI

public struct ExteriorShadow: View {
    public var cornerRadius: CGFloat
    public var color: Color
    public var radius: CGFloat
    public var y: CGFloat

    public init(cornerRadius: CGFloat, color: Color, radius: CGFloat, y: CGFloat) {
        self.cornerRadius = cornerRadius
        self.color = color
        self.radius = radius
        self.y = y
    }

    public var body: some View {
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
