import SwiftUI

public struct DesignStatusDot: View {
    public var color: Color
    public var size: CGFloat

    public init(color: Color, size: CGFloat = DesignTokens.IconSize.statusDot) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

public struct DesignStatusBadge: View {
    public var text: String
    public var tint: Color
    public var font: Font

    public init(text: String,
                tint: Color,
                font: Font = .caption.weight(.medium)) {
        self.text = text
        self.tint = tint
        self.font = font
    }

    public var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(tint)
            .padding(.horizontal, DesignTokens.Badge.horizontalPadding)
            .padding(.vertical, DesignTokens.Badge.verticalPadding)
            .background(tint.opacity(DesignTokens.Badge.statusOpacity), in: Capsule())
    }
}

public struct DesignKeyCap: View {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.Keyboard.keyHorizontalPadding)
            .padding(.vertical, DesignTokens.Keyboard.keyVerticalPadding)
            .background(.quaternary,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.keyCap,
                                             style: .continuous))
    }
}

public struct DesignKeyboardHint: View {
    public var key: String
    public var label: String

    public init(_ key: String, _ label: String) {
        self.key = key
        self.label = label
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Space.xs) {
            DesignKeyCap(key)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

public struct DesignScopeChipLabel: View {
    public var symbol: String
    public var title: String

    public init(symbol: String, title: String) {
        self.symbol = symbol
        self.title = title
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Space.xs) {
            Image(systemName: symbol)
                .font(.caption2)
            Text(title)
                .font(.caption.weight(.semibold))
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, DesignTokens.Space.s)
        .padding(.vertical, DesignTokens.Badge.scopeVerticalPadding)
        .background(Color.accentColor.opacity(DesignTokens.Badge.accentOpacity),
                    in: Capsule(style: .continuous))
        .foregroundStyle(Color.accentColor)
    }
}

public struct DesignTintSwatch: View {
    public var color: Color
    public var followsAccent: Bool

    public init(color: Color, followsAccent: Bool = false) {
        self.color = color
        self.followsAccent = followsAccent
    }

    public var body: some View {
        ZStack {
            Circle().fill(color)
            if followsAccent {
                Image(systemName: "link")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: DesignTokens.IconSize.chip, height: DesignTokens.IconSize.chip)
    }
}

public struct DesignMetricTile: View {
    public var label: String
    public var value: String
    public var caption: String?

    public init(label: String, value: String, caption: String? = nil) {
        self.label = label
        self.value = value
        self.caption = caption
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.xs) {
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
        .padding(.horizontal, DesignTokens.Space.m)
        .padding(.vertical, DesignTokens.Space.s)
        .background(DesignMaterial.toolbarHoverFill,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.control,
                                         style: .continuous))
    }
}

/// A package-owned content surface for empty states and grouped panel content.
public struct DesignContentSurface<Content: View>: View {
    public var elevated: Bool
    public var minHeight: CGFloat?
    public var alignment: Alignment
    public var padding: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(elevated: Bool = false,
                minHeight: CGFloat? = nil,
                alignment: Alignment = .center,
                padding: CGFloat = DesignTokens.Space.s,
                @ViewBuilder content: @escaping () -> Content) {
        self.elevated = elevated
        self.minHeight = minHeight
        self.alignment = alignment
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .glassSurface(.regular, cornerRadius: DesignTokens.Radius.card, shadow: elevated)
    }
}

/// A package-owned surface for compact inline controls such as search fields and text editors.
public struct DesignInputSurface<Content: View>: View {
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var minHeight: CGFloat?
    @ViewBuilder public var content: () -> Content

    public init(horizontalPadding: CGFloat = DesignTokens.Space.m,
                verticalPadding: CGFloat = DesignTokens.Space.s,
                minHeight: CGFloat? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.minHeight = minHeight
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .glassSurface(.thin, cornerRadius: DesignTokens.Radius.control)
    }
}

public extension View {
    @ViewBuilder
    func designCardSelectionOverlay(when isSelected: Bool) -> some View {
        overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .fill(DesignMaterial.toolbarHoverFill)
                    .allowsHitTesting(false)
            }
        }
    }

    func terminalSurfaceChrome() -> some View {
        padding(DesignTokens.Space.s)
            .background(.black.opacity(DesignTokens.Terminal.surfaceOpacity),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.card,
                                             style: .continuous))
            .padding(DesignTokens.Space.s)
    }

    func subtleTileBackground() -> some View {
        background(.quaternary.opacity(DesignTokens.InlineControl.subtleTileOpacity),
                   in: RoundedRectangle(cornerRadius: DesignTokens.Radius.control,
                                        style: .continuous))
    }

    func toolbarControlContentShape() -> some View {
        contentShape(Capsule(style: .continuous))
    }
}
