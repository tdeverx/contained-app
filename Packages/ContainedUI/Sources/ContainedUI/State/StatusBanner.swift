import SwiftUI

/// Package-owned transient banner chrome.
public extension UI.State {
struct Banner: View {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .padding(.horizontal, UI.Tokens.Space.l)
            .padding(.vertical, UI.Tokens.Space.s)
            .materialCapsuleSurface(shadow: false)
    }
}
}

#Preview("Status Banner") {
    UI.State.Banner("Image pull completed")
        .padding(UI.Tokens.Space.xl)
}
