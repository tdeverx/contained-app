import SwiftUI

public struct MetricTile: View {
    public var label: String
    public var value: String
    public var caption: String?

    public init(label: String, value: String, caption: String? = nil) {
        self.label = label
        self.value = value
        self.caption = caption
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: UI.Tokens.Space.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: UI.Tokens.Space.xs) {
                Text(value)
                    .font(.title3.weight(.medium))
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, UI.Tokens.Space.m)
        .padding(.vertical, UI.Tokens.Space.s)
        .background(ThemeMaterial.toolbarHoverFill,
                    in: RoundedRectangle(cornerRadius: UI.Tokens.Radius.control,
                                         style: .continuous))
    }
}
