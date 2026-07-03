import SwiftUI

public extension UI.Control {
struct SearchField: View {
    @Binding public var text: String
    public var prompt: String
    public var clearLabel: String
    public var isSearching: Bool
    public var onSubmit: () -> Void

    public init(text: Binding<String>,
                prompt: String,
                clearLabel: String,
                isSearching: Bool = false,
                onSubmit: @escaping () -> Void = {}) {
        self._text = text
        self.prompt = prompt
        self.clearLabel = clearLabel
        self.isSearching = isSearching
        self.onSubmit = onSubmit
    }

    public var body: some View {
        UI.Control.InputCluster {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .onSubmit(onSubmit)
            if isSearching {
                ProgressView().controlSize(.small)
            } else if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(clearLabel)
                .accessibilityLabel(clearLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
}
