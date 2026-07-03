import SwiftUI

public extension UI.List {
struct Stack<Content: View>: View {
    public var spacing: CGFloat
    public var padding: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(spacing: CGFloat = UI.Tokens.Space.s,
                padding: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(padding)
    }
}

struct Section<Content: View>: View {
    public var title: String
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(_ title: String,
                spacing: CGFloat = UI.Tokens.Space.s,
                @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: spacing) {
            UI.State.SectionLabel(title)
            content()
        }
    }
}

struct MetadataRow<Accessory: View>: View {
    public var systemImage: String
    public var title: String
    public var subtitle: String?
    public var isMonospaced: Bool
    public var tint: Color
    public var action: (() -> Void)?
    @ViewBuilder public var accessory: () -> Accessory

    public init(systemImage: String,
                title: String,
                subtitle: String? = nil,
                isMonospaced: Bool = false,
                tint: Color = .secondary,
                action: (() -> Void)? = nil,
                @ViewBuilder accessory: @escaping () -> Accessory) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.isMonospaced = isMonospaced
        self.tint = tint
        self.action = action
        self.accessory = accessory
    }

    public var body: some View {
        SharedIconTextRow(systemImage: systemImage,
                          tint: tint,
                          subtitle: subtitle,
                          action: action) {
            Text(title)
                .font(isMonospaced ? .system(.callout, design: .monospaced) : .callout)
                .lineLimit(1)
        } accessory: {
            accessory()
        }
    }
}
}

#Preview("List Controls") {
    UI.List.Stack {
        UI.List.Section("Runtime") {
            UI.List.MetadataBadgeRow(systemImage: "shippingbox",
                                     title: "preview-web",
                                     badge: "running",
                                     subtitle: "docker.io/library/nginx:latest",
                                     tint: .accentColor) {
                UI.List.RowChevron()
            }
            UI.List.MetadataRow(systemImage: "externaldrive",
                                title: "preview-data",
                                subtitle: "/Users/preview/.contained") {
                UI.Badge.Text(text: "10 GB")
            }
            UI.List.KeyValueRow(label: "Runtime", value: "Apple container")
            UI.List.CompactInfoRow("Image", value: "nginx:latest")
        }
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 460)
}

public extension UI.List.MetadataRow where Accessory == EmptyView {
    init(systemImage: String,
         title: String,
         subtitle: String? = nil,
         isMonospaced: Bool = false,
         tint: Color = .secondary,
         action: (() -> Void)? = nil) {
        self.init(systemImage: systemImage,
                  title: title,
                  subtitle: subtitle,
                  isMonospaced: isMonospaced,
                  tint: tint,
                  action: action) {
            EmptyView()
        }
    }
}

public extension UI.List {
struct MetadataBadgeRow<Accessory: View>: View {
    public var systemImage: String
    public var title: String
    public var badge: String?
    public var subtitle: String?
    public var isMonospaced: Bool
    public var tint: Color
    @ViewBuilder public var accessory: () -> Accessory

    public init(systemImage: String,
                title: String,
                badge: String? = nil,
                subtitle: String? = nil,
                isMonospaced: Bool = false,
                tint: Color = .secondary,
                @ViewBuilder accessory: @escaping () -> Accessory) {
        self.systemImage = systemImage
        self.title = title
        self.badge = badge
        self.subtitle = subtitle
        self.isMonospaced = isMonospaced
        self.tint = tint
        self.accessory = accessory
    }

    public var body: some View {
        SharedIconTextRow(systemImage: systemImage,
                          tint: tint,
                          subtitle: subtitle) {
            HStack(spacing: UI.Tokens.Space.xs) {
                Text(title)
                    .font(isMonospaced ? .system(.callout, design: .monospaced) : .callout)
                    .lineLimit(1)
                if let badge {
                    UI.Badge.Text(text: badge)
                }
            }
        } accessory: {
            accessory()
        }
    }
}

struct KeyValueRow: View {
    public var label: String
    public var value: String
    public var valueMonospaced: Bool
    public var selectsValue: Bool

    public init(label: String,
                value: String,
                valueMonospaced: Bool = true,
                selectsValue: Bool = false) {
        self.label = label
        self.value = value
        self.valueMonospaced = valueMonospaced
        self.selectsValue = selectsValue
    }

    public var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .designSecondaryCallout()
            Spacer(minLength: UI.Tokens.Space.m)
            valueText
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    @ViewBuilder
    private var valueText: some View {
        let text = Text(value)
        if valueMonospaced {
            if selectsValue {
                text.font(.system(.body, design: .monospaced)).textSelection(.enabled)
            } else {
                text.font(.system(.body, design: .monospaced))
            }
        } else if selectsValue {
            text.textSelection(.enabled)
        } else {
            text
        }
    }
}

struct CompactInfoRow: View {
    public var title: String
    public var value: String
    public var titleWidth: CGFloat

    public init(_ title: String,
                value: String,
                titleWidth: CGFloat = UI.Tokens.MenuBar.titleWidth) {
        self.title = title
        self.value = value
        self.titleWidth = titleWidth
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: UI.Tokens.Card.padding) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: titleWidth, alignment: .leading)
            Text(value)
                .font(.caption)
            Spacer(minLength: 0)
        }
    }
}
}
