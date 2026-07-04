import SwiftUI

public extension UI.Form {
struct Grouped<Content: View>: View {
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
}

