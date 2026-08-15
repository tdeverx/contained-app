import SwiftUI

/// A package-owned content surface for empty states and grouped panel content.
public extension UI.Surface {
enum ContentMaterial {
    case standard
    /// Uses the same configurable material renderer as image and container cards.
    case card
}

struct Content<ContentView: View>: View {
    public var elevated: Bool
    public var material: UI.Surface.ContentMaterial
    public var minHeight: CGFloat?
    public var alignment: Alignment
    public var padding: CGFloat
    @ViewBuilder public var content: () -> ContentView

    @Environment(\.cardMaterial) private var cardMaterial

    public init(elevated: Bool = false,
                material: UI.Surface.ContentMaterial = .standard,
                minHeight: CGFloat? = nil,
                alignment: Alignment = .center,
                padding: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder content: @escaping () -> ContentView) {
        self.elevated = elevated
        self.material = material
        self.minHeight = minHeight
        self.alignment = alignment
        self.padding = padding
        self.content = content
    }

    @ViewBuilder public var body: some View {
        switch material {
        case .standard:
            surfaceContent
                .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card, shadow: elevated)
        case .card:
            surfaceContent
                .designCardMaterial(cardMaterial,
                                    cornerRadius: UI.Tokens.Radius.card,
                                    shadow: elevated,
                                    fill: nil,
                                    fillOpacity: 0,
                                    gradient: false,
                                    gradientAngle: 0,
                                    blendMode: .normal)
        }
    }

    private var surfaceContent: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
    }
}

/// A settings-style section heading outside a content surface. This keeps hierarchy consistent
/// with panel sections while allowing callers to choose the standard or configurable card material.
struct Section<HeaderAccessory: View, ContentView: View>: View {
    public var header: String
    public var elevated: Bool
    public var material: UI.Surface.ContentMaterial
    public var padding: CGFloat
    @ViewBuilder public var headerAccessory: () -> HeaderAccessory
    @ViewBuilder public var content: () -> ContentView

    public init(header: String,
                elevated: Bool = false,
                material: UI.Surface.ContentMaterial = .standard,
                padding: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder headerAccessory: @escaping () -> HeaderAccessory,
                @ViewBuilder content: @escaping () -> ContentView) {
        self.header = header
        self.elevated = elevated
        self.material = material
        self.padding = padding
        self.headerAccessory = headerAccessory
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: UI.Tokens.Space.s) {
            HStack(spacing: UI.Tokens.Space.s) {
                Text(header)
                    .font(.headline)
                Spacer(minLength: UI.Tokens.Space.s)
                headerAccessory()
            }
            .padding(.horizontal, UI.Tokens.Space.xs)

            UI.Surface.Content(elevated: elevated,
                               material: material,
                               alignment: .topLeading,
                               padding: padding) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
}

#Preview("Content Surface") {
    UI.Surface.Content(elevated: true, minHeight: 140) {
        UI.State.Empty("No results",
                       systemImage: "magnifyingglass",
                       description: "Try another search term.")
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 420)
}
