import SwiftUI

/// Package-owned floating selection action bar.
public extension UI.Action {
struct SelectionBar: View {
    public var count: Int
    public var countLabel: (Int) -> String
    public var actions: [UI.Action.Item]

    public init(count: Int,
                countLabel: @escaping (Int) -> String,
                actions: [UI.Action.Item]) {
        self.count = count
        self.countLabel = countLabel
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: UI.Tokens.Space.m) {
            Text(countLabel(count))
                .font(.callout.weight(.medium))
            Divider()
                .frame(height: 16)
            ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                UI.Action.TextButton(title: item.title ?? item.help,
                                     systemName: item.systemName,
                                     help: item.help,
                                     role: item.role,
                                     prominence: .standard,
                                     isEnabled: item.isEnabled,
                                     action: item.action)
            }
        }
        .padding(.horizontal, UI.Tokens.Space.l)
        .padding(.vertical, UI.Tokens.Space.s)
        .materialCapsuleSurface(shadow: false)
    }
}
}
