import SwiftUI
import ContainedDesignSystem

/// Shared body scaffolding for expanded container-card pages.
/// Keeps tab content at the same 8pt inset as the rest of the panel surfaces.
struct ContainerTabScaffold<Content: View>: View {
    var axes: Axis.Set = .vertical
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(axes) {
            LazyVStack(alignment: .leading, spacing: 0) {
                content()
                    .padding(DesignTokens.Space.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                .padding(DesignTokens.Space.s)
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
        DesignCardInsetSection(title: title) {
            content()
        }
    }
}
