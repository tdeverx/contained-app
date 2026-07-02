import SwiftUI

public enum StateTone {
    case primary
    case neutral
    case tertiary
    case info
    case accent
    case warning
    case error
    case success

    public var color: Color {
        switch self {
        case .primary: return .primary
        case .neutral: return .secondary
        case .tertiary: return Color.secondary.opacity(0.65)
        case .info: return .blue
        case .accent: return .accentColor
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}

public enum SymbolSize {
    case caption2
    case caption
    case callout
    case body
    case title3
    case title
    case state

    var font: Font {
        switch self {
        case .caption2: return .caption2
        case .caption: return .caption
        case .callout: return .callout
        case .body: return .body
        case .title3: return .title3
        case .title: return .title2
        case .state: return .largeTitle
        }
    }
}

public struct SymbolView: View {
    public var systemName: String
    public var tone: StateTone
    public var tint: Color?
    public var size: SymbolSize
    public var frameWidth: CGFloat?

    public init(systemName: String,
                tone: StateTone = .neutral,
                tint: Color? = nil,
                size: SymbolSize = .callout,
                frameWidth: CGFloat? = nil) {
        self.systemName = systemName
        self.tone = tone
        self.tint = tint
        self.size = size
        self.frameWidth = frameWidth
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(size.font)
            .foregroundStyle(tint ?? tone.color)
            .frame(width: frameWidth)
    }
}

public struct StatusText: View {
    public var text: String
    public var tone: StateTone
    public var style: Font

    public init(_ text: String,
                tone: StateTone = .neutral,
                style: Font = .callout) {
        self.text = text
        self.tone = tone
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(style)
            .foregroundStyle(tone.color)
    }
}

public struct EmptyState: View {
    public var title: String
    public var systemImage: String
    public var description: String?
    public var tone: StateTone
    public var minHeight: CGFloat?
    public var padding: CGFloat

    public init(_ title: String,
                systemImage: String,
                description: String? = nil,
                tone: StateTone = .neutral,
                minHeight: CGFloat? = nil,
                padding: CGFloat = UI.Tokens.Space.xl) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.tone = tone
        self.minHeight = minHeight
        self.padding = padding
    }

    public var body: some View {
        VStack(spacing: UI.Tokens.Space.s) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tone.color)
            Text(title)
                .font(.callout.weight(.medium))
            if let description {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .padding(padding)
    }
}

public struct HeroState<Actions: View>: View {
    public var systemImage: String
    public var title: String
    public var message: String
    @ViewBuilder public var actions: () -> Actions

    public init(systemImage: String,
                title: String,
                message: String,
                @ViewBuilder actions: @escaping () -> Actions) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: UI.Tokens.Space.l) {
            Image(systemName: systemImage)
                .font(.system(size: UI.Tokens.IconSize.appIcon - UI.Tokens.Space.xs))
                .foregroundStyle(.tint)
            Text(title).font(.title2.weight(.semibold))
            Text(message)
                .designSecondaryCallout()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            actions()
        }
        .padding(UI.Tokens.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct LoadingState: View {
    public var title: String
    public var minHeight: CGFloat?
    public var padding: CGFloat

    public init(_ title: String,
                minHeight: CGFloat? = nil,
                padding: CGFloat = UI.Tokens.Space.xl) {
        self.title = title
        self.minHeight = minHeight
        self.padding = padding
    }

    public var body: some View {
        VStack(spacing: UI.Tokens.Space.s) {
            ProgressView()
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: minHeight)
        .padding(padding)
    }
}

public struct ProgressIndicator: View {
    public var controlSize: ControlSize
    public var frameSize: CGFloat?

    public init(controlSize: ControlSize = .small, frameSize: CGFloat? = nil) {
        self.controlSize = controlSize
        self.frameSize = frameSize
    }

    public var body: some View {
        ProgressView()
            .controlSize(controlSize)
            .frame(width: frameSize, height: frameSize)
    }
}

public struct SectionLabel: View {
    public var title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

public struct InlineStatus: View {
    public var title: String
    public var systemImage: String?
    public var isWorking: Bool
    public var tone: StateTone

    public init(_ title: String,
                systemImage: String? = nil,
                isWorking: Bool = false,
                tone: StateTone = .neutral) {
        self.title = title
        self.systemImage = systemImage
        self.isWorking = isWorking
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: UI.Tokens.Toolbar.searchIconGap) {
            if isWorking {
                ProgressView().controlSize(.small)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tone.color)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

public extension View {
    func designSectionLabelStyle() -> some View {
        font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    func designSubheadlineLabelStyle() -> some View {
        font(.subheadline.weight(.semibold))
    }

    func designHeadlineLabelStyle() -> some View {
        font(.headline)
    }

    func designSearchTextStyle() -> some View {
        font(.body.weight(.medium))
    }

    func designTitleLabelStyle() -> some View {
        font(.title3.weight(.semibold))
    }

    func designSecondaryValueStyle() -> some View {
        foregroundStyle(.secondary)
    }

    func designMonospacedCaption() -> some View {
        font(.system(.caption, design: .monospaced))
    }

    func designSecondaryMonospacedCaption() -> some View {
        font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    func designSecondaryMonospacedDigitCaption() -> some View {
        font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    func designSecondaryMonospacedDigitHeadline() -> some View {
        font(.headline.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    func designMonospacedCallout() -> some View {
        font(.system(.callout, design: .monospaced))
    }

    func designSecondaryCaption() -> some View {
        font(.caption)
            .foregroundStyle(.secondary)
    }

    func designSecondaryCallout() -> some View {
        font(.callout)
            .foregroundStyle(.secondary)
    }

    func designTertiaryCaption() -> some View {
        font(.caption)
            .foregroundStyle(.tertiary)
    }

    func designTertiaryCaption2() -> some View {
        font(.caption2)
            .foregroundStyle(.tertiary)
    }

    func designStatusStyle(_ tone: StateTone) -> some View {
        foregroundStyle(tone.color)
    }

    func designStateIconStyle() -> some View {
        font(.largeTitle)
            .foregroundStyle(.secondary)
    }
}
