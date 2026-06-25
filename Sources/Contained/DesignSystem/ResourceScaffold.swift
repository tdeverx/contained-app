import SwiftUI

/// Shared chrome for the resource list pages (Images/Volumes/Networks). A soft-edged scroll of
/// glass rows with a consistent empty state.
struct ResourceScaffold<Row: View>: View {
    let isEmpty: Bool
    let emptyTitle: String
    let emptySymbol: String
    var emptyMessage: String = ""
    @ViewBuilder var rows: () -> Row

    var body: some View {
        if isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: emptySymbol)
            } description: { if !emptyMessage.isEmpty { Text(emptyMessage) } }
        } else {
            ScrollView {
                LazyVStack(spacing: Tokens.Space.s) {
                    rows()
                }
                .padding(Tokens.Space.l)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }
}
