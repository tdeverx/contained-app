import SwiftUI

struct ExteriorShadow: View {
    var cornerRadius: CGFloat
    var color: Color
    var radius: CGFloat
    var y: CGFloat

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
