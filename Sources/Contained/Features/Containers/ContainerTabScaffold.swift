import SwiftUI

/// Shared body scaffolding for expanded container-card pages.
/// Keeps tab content at the same 8pt inset as the rest of the panel surfaces.
struct ContainerTabScaffold<Content: View>: View {
    var axes: Axis.Set = .vertical
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(axes) {
            content()
                .padding(Tokens.Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
    }
}

/// Shared scaffolding for container tabs that have fixed controls above a content body.
struct ContainerToolTabScaffold<Chrome: View, Content: View>: View {
    @ViewBuilder var chrome: () -> Chrome
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            chrome()
                .padding(Tokens.Space.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// A flat section surface inside expanded container-card tabs.
struct ContainerTabSection<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.leading, Tokens.Space.xs)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                content()
            }
            .padding(Tokens.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
