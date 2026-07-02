import SwiftUI

public struct GlassOptionTile: View {
    public static let defaultHeight: CGFloat = 100

    public let symbol: String
    public let title: String
    public var subtitle: String?
    public var enabled: Bool
    public var height: CGFloat
    public var matchedID: String?
    public var matchedNamespace: Namespace.ID?
    public var action: () -> Void

    public init(symbol: String,
                title: String,
                subtitle: String? = nil,
                enabled: Bool = true,
                height: CGFloat = Self.defaultHeight,
                matchedID: String? = nil,
                matchedNamespace: Namespace.ID? = nil,
                action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.enabled = enabled
        self.height = height
        self.matchedID = matchedID
        self.matchedNamespace = matchedNamespace
        self.action = action
    }

    public var body: some View {
        Button {
            guard enabled else { return }
            action()
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24, alignment: .leading)

                Spacer(minLength: DesignTokens.Space.s)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(enabled ? .primary : .secondary)
                        .lineLimit(1)

                    Text(subtitle ?? " ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .opacity(subtitle == nil ? 0 : 1)
                        .accessibilityHidden(subtitle == nil)
                }
            }
            .padding(DesignTokens.Space.m)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            .glassOptionTileSurface(cornerRadius: DesignTokens.Radius.card, interactive: enabled)
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
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

    func glassOptionTileSurface(cornerRadius: CGFloat, interactive: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
    }
}
