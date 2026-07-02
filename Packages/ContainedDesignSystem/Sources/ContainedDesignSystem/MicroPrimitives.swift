import SwiftUI

public struct DesignStatusDot: View {
    public var color: Color
    public var size: CGFloat

    public init(color: Color, size: CGFloat = Tokens.IconSize.statusDot) {
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
            .padding(.horizontal, Tokens.Badge.horizontalPadding)
            .padding(.vertical, Tokens.Badge.verticalPadding)
            .background(tint.opacity(Tokens.Badge.statusOpacity), in: Capsule())
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
            .padding(.horizontal, Tokens.Keyboard.keyHorizontalPadding)
            .padding(.vertical, Tokens.Keyboard.keyVerticalPadding)
            .background(.quaternary,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.keyCap,
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
        HStack(spacing: Tokens.Space.xs) {
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
        HStack(spacing: Tokens.Space.xs) {
            Image(systemName: symbol)
                .font(.caption2)
            Text(title)
                .font(.caption.weight(.semibold))
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, Tokens.Space.s)
        .padding(.vertical, Tokens.Badge.scopeVerticalPadding)
        .background(Color.accentColor.opacity(Tokens.Badge.accentOpacity),
                    in: Capsule(style: .continuous))
        .foregroundStyle(Color.accentColor)
    }
}

public struct DesignTintSwatch: View {
    public var color: Color
    public var followsAppAccent: Bool

    public init(color: Color, followsAppAccent: Bool = false) {
        self.color = color
        self.followsAppAccent = followsAppAccent
    }

    public var body: some View {
        ZStack {
            Circle().fill(color)
            if followsAppAccent {
                Image(systemName: "link")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
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
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
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
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .background(AppMaterial.toolbarHoverFill,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.control,
                                         style: .continuous))
    }
}

public extension View {
    @ViewBuilder
    func designCardSelectionOverlay(when isSelected: Bool) -> some View {
        overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .fill(AppMaterial.toolbarHoverFill)
                    .allowsHitTesting(false)
            }
        }
    }

    func terminalSurfaceChrome() -> some View {
        padding(Tokens.Space.s)
            .background(.black.opacity(Tokens.Terminal.surfaceOpacity),
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.card,
                                             style: .continuous))
            .padding(Tokens.Space.s)
    }

    func subtleTileBackground() -> some View {
        background(.quaternary.opacity(Tokens.InlineControl.subtleTileOpacity),
                   in: RoundedRectangle(cornerRadius: Tokens.Radius.control,
                                        style: .continuous))
    }

    func toolbarControlContentShape() -> some View {
        contentShape(Capsule(style: .continuous))
    }
}
