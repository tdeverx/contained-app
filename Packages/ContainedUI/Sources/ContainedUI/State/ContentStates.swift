import SwiftUI

public extension UI.State {
enum Tone {
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
}

public extension UI.Symbol {
enum Size {
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

struct Image: View {
    public var systemName: String
    public var tone: UI.State.Tone
    public var tint: Color?
    public var size: UI.Symbol.Size
    public var frameWidth: CGFloat?

    public init(systemName: String,
                tone: UI.State.Tone = .neutral,
                tint: Color? = nil,
                size: UI.Symbol.Size = .callout,
                frameWidth: CGFloat? = nil) {
        self.systemName = systemName
        self.tone = tone
        self.tint = tint
        self.size = size
        self.frameWidth = frameWidth
    }

    public var body: some View {
        SwiftUI.Image(systemName: systemName)
            .font(size.font)
            .foregroundStyle(tint ?? tone.color)
            .frame(width: frameWidth)
    }
}
}

public extension UI.State {
struct StatusText: View {
    public var text: String
    public var tone: UI.State.Tone
    public var style: Font

    public init(_ text: String,
                tone: UI.State.Tone = .neutral,
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

struct Empty: View {
    public var title: String
    public var systemImage: String
    public var description: String?
    public var tone: UI.State.Tone
    public var minHeight: CGFloat?
    public var padding: CGFloat

    public init(_ title: String,
                systemImage: String,
                description: String? = nil,
                tone: UI.State.Tone = .neutral,
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
        CenteredStateLayout(spacing: UI.Tokens.Space.s,
                            padding: padding,
                            minHeight: minHeight,
                            fillsHeight: false) {
            SwiftUI.Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tone.color)
        } content: {
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
    }
}

struct Hero<Actions: View>: View {
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
        CenteredStateLayout(spacing: UI.Tokens.Space.l,
                            padding: UI.Tokens.Space.xxl,
                            minHeight: nil,
                            fillsHeight: true) {
            SwiftUI.Image(systemName: systemImage)
                .font(.system(size: UI.Tokens.IconSize.appIcon - UI.Tokens.Space.xs))
                .foregroundStyle(.tint)
        } content: {
            Text(title).font(.title2.weight(.semibold))
            Text(message)
                .designSecondaryCallout()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        } actions: {
            actions()
        }
    }
}

struct Loading: View {
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
        CenteredStateLayout(spacing: UI.Tokens.Space.s,
                            padding: padding,
                            minHeight: minHeight,
                            fillsHeight: true) {
            ProgressView()
        } content: {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CenteredStateLayout<Graphic: View, Content: View, Actions: View>: View {
    var spacing: CGFloat
    var padding: CGFloat
    var minHeight: CGFloat?
    var fillsHeight: Bool
    @ViewBuilder var graphic: () -> Graphic
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    init(spacing: CGFloat,
         padding: CGFloat,
         minHeight: CGFloat?,
         fillsHeight: Bool,
         @ViewBuilder graphic: @escaping () -> Graphic,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.spacing = spacing
        self.padding = padding
        self.minHeight = minHeight
        self.fillsHeight = fillsHeight
        self.graphic = graphic
        self.content = content
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: spacing) {
            graphic()
            content()
            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
        .frame(minHeight: minHeight)
        .padding(padding)
    }
}

struct ProgressIndicator: View {
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

struct SectionLabel: View {
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

struct InlineStatus: View {
    public var title: String
    public var systemImage: String?
    public var isWorking: Bool
    public var tone: UI.State.Tone

    public init(_ title: String,
                systemImage: String? = nil,
                isWorking: Bool = false,
                tone: UI.State.Tone = .neutral) {
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
                SwiftUI.Image(systemName: systemImage)
                    .foregroundStyle(tone.color)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    func designStatusStyle(_ tone: UI.State.Tone) -> some View {
        foregroundStyle(tone.color)
    }

    func designStateIconStyle() -> some View {
        font(.largeTitle)
            .foregroundStyle(.secondary)
    }
}

#Preview("Content States") {
    VStack(spacing: UI.Tokens.Space.l) {
        HStack(spacing: UI.Tokens.Space.m) {
            UI.Symbol.Image(systemName: "shippingbox", tone: .accent, size: .title3)
            UI.State.StatusText("Ready", tone: .success)
            UI.State.InlineStatus("Checking", isWorking: true)
            UI.State.SectionLabel("Section")
        }

        UI.State.Empty("No containers",
                       systemImage: "shippingbox",
                       description: "Create or import a container to begin.",
                       tone: .neutral,
                       minHeight: 120)

        UI.State.Hero(systemImage: "square.stack.3d.up",
                      title: "Images",
                      message: "Pull, build, and tag runtime images.") {
            UI.Action.TextButton(title: "Pull",
                                 systemName: "arrow.down.circle",
                                 prominence: .prominent) {}
        }

        UI.State.Loading("Loading runtimes", minHeight: 80)
        UI.State.ProgressIndicator(frameSize: 24)
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 520)
}
