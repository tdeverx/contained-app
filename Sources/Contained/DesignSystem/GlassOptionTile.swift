import SwiftUI

struct GlassOptionTile: View {
    static let defaultHeight: CGFloat = 100

    let symbol: String
    let title: String
    var subtitle: String? = nil
    var enabled = true
    var height: CGFloat = Self.defaultHeight
    var matchedID: String?
    var matchedNamespace: Namespace.ID?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24, alignment: .leading)

                Spacer(minLength: Tokens.Space.s)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle ?? " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .opacity(subtitle == nil ? 0 : 1)
                        .accessibilityHidden(subtitle == nil)
                }
            }
            .padding(Tokens.Space.m)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            .glassOptionTileSurface(cornerRadius: Tokens.Radius.card)
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .optionalMatchedGeometry(id: matchedID, namespace: matchedNamespace)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

private struct OptionalMatchedGeometry: ViewModifier {
    var id: String?
    var namespace: Namespace.ID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let id, let namespace {
            content.matchedGeometryEffect(id: id, in: namespace, properties: .frame)
        } else {
            content
        }
    }
}

private extension View {
    func optionalMatchedGeometry(id: String?, namespace: Namespace.ID?) -> some View {
        modifier(OptionalMatchedGeometry(id: id, namespace: namespace))
    }

    func glassOptionTileSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .glassEffect(.regular.interactive(), in: shape)
    }
}
