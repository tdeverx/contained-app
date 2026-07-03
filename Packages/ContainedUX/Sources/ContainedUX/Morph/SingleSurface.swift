import SwiftUI
import ContainedUI

public extension UX.Morph {
struct Frame: Equatable, Sendable {
    public var source: CGRect
    public var target: CGRect
    public var progress: CGFloat

    public init(source: CGRect, target: CGRect, progress: CGFloat) {
        self.source = source
        self.target = target
        self.progress = UX.Morph.Geometry.clampedProgress(progress)
    }

    public var rect: CGRect {
        source.morphInterpolated(to: target, progress: progress)
    }
}

/// Hosts one promoted surface while it grows from an existing slot into a larger target rect.
///
/// This is the single-card version of the rect motion used by `UX.Morph.Expander`: callers keep the
/// source view laid out in place, hide it while selected, and render one overlay through this helper.
struct SingleSurface<Content: View>: View {
    public var source: CGRect
    public var target: CGRect
    public var progress: CGFloat
    public var alignment: Alignment
    @ViewBuilder private var content: () -> Content

    public init(source: CGRect,
                target: CGRect,
                progress: CGFloat,
                alignment: Alignment = .top,
                @ViewBuilder content: @escaping () -> Content) {
        self.source = source
        self.target = target
        self.progress = progress
        self.alignment = alignment
        self.content = content
    }

    public var body: some View {
        let rect = UX.Morph.Frame(source: source, target: target, progress: progress).rect
        content()
            .frame(width: max(rect.width, 1), height: max(rect.height, 1), alignment: alignment)
            .position(x: rect.midX, y: rect.midY)
    }
}

/// Hosts one promoted card-like surface with the same lifecycle as `UX.Morph.Expander`, but without
/// drawing a separate panel shell around the content.
///
/// Use this when the promoted content is already its own visual surface, such as an expanded design
/// card. Panel contents should still use `UX.Morph.Expander`.
struct SingleSurfaceExpander<Content: View>: View {
    @Binding var isPresented: Bool
    public var originFrame: CGRect
    public var target: UX.Morph.Target
    public var backdropStyle: UX.Panel.BackdropStyle
    public var showsBackdrop: Bool
    public var closeRequestToken: Int
    public var onBackdropTap: (() -> Void)?
    public var onExpansionChange: ((Bool) -> Void)?
    @ViewBuilder private var content: () -> Content

    @State private var expanded = false
    @State private var liveSize: CGSize?
    @State private var livePlacement: UX.Panel.Placement?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.morphSafeAreaManager) private var safeAreaManager
    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    public init(isPresented: Binding<Bool>,
                originFrame: CGRect,
                target: UX.Morph.Target,
                backdropStyle: UX.Panel.BackdropStyle = .dim,
                showsBackdrop: Bool = true,
                closeRequestToken: Int = 0,
                onBackdropTap: (() -> Void)? = nil,
                onExpansionChange: ((Bool) -> Void)? = nil,
                @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self.originFrame = originFrame
        self.target = target
        self.backdropStyle = backdropStyle
        self.showsBackdrop = showsBackdrop
        self.closeRequestToken = closeRequestToken
        self.onBackdropTap = onBackdropTap
        self.onExpansionChange = onExpansionChange
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            let target = targetRect(in: geo.size)
            let source = originFrame.isUsableForMorph ? originFrame : target
            let rect = expanded ? target : source
            ZStack {
                if showsBackdrop {
                    Color.clear
                        .globalBackdrop(style: backdropStyle,
                                        progress: expanded ? 1 : 0,
                                        dimOpacity: 0.28)
                        .contentShape(Rectangle())
                        .onTapGesture { onBackdropTap?() ?? close() }
                }

                Button(action: close) { EmptyView() }
                    .keyboardShortcut(.cancelAction)
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .accessibilityHidden(true)

                content()
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1), alignment: .top)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .onPreferenceChange(MorphPanelSizeKey.self) { size in
            guard let size, size.isUsableForMorphPanel else { return }
            withAnimation(reduceMotion ? nil : spring) { liveSize = size }
        }
        .onPreferenceChange(MorphPanelPlacementKey.self) { placement in
            guard let placement else { return }
            withAnimation(reduceMotion ? nil : spring) { livePlacement = placement }
        }
        .onAppear {
            guard !reduceMotion else {
                expanded = true
                onExpansionChange?(true)
                return
            }
            DispatchQueue.main.async {
                onExpansionChange?(true)
                withAnimation(spring) { expanded = true }
            }
        }
        .onChange(of: closeRequestToken) { _, _ in close() }
        .onExitCommand(perform: close)
    }

    private func targetRect(in size: CGSize) -> CGRect {
        target.rect(origin: originFrame,
                    in: size,
                    safeAreaManager: safeAreaManager,
                    proposedSize: liveSize,
                    placement: livePlacement)
    }

    private func close() {
        onExpansionChange?(false)
        guard !reduceMotion else {
            isPresented = false
            return
        }
        withAnimation(spring) { expanded = false } completion: {
            isPresented = false
        }
    }
}
}

public extension UX.Morph.Geometry {
    static func clampedProgress(_ progress: CGFloat) -> CGFloat {
        min(max(progress.isFinite ? progress : 0, 0), 1)
    }

    static func interpolatedRect(from source: CGRect, to target: CGRect, progress: CGFloat) -> CGRect {
        let progress = clampedProgress(progress)
        return CGRect(
            x: interpolate(source.minX, target.minX, progress: progress),
            y: interpolate(source.minY, target.minY, progress: progress),
            width: max(1, interpolate(source.width, target.width, progress: progress)),
            height: max(1, interpolate(source.height, target.height, progress: progress))
        )
    }

    static func isUsableFrame(_ rect: CGRect) -> Bool {
        rect.width.isFinite &&
        rect.height.isFinite &&
        rect.minX.isFinite &&
        rect.minY.isFinite &&
        rect.width > 1 &&
        rect.height > 1
    }

    private static func interpolate(_ source: CGFloat, _ target: CGFloat, progress: CGFloat) -> CGFloat {
        source + (target - source) * progress
    }
}

public extension CGRect {
    func morphInterpolated(to target: CGRect, progress: CGFloat) -> CGRect {
        UX.Morph.Geometry.interpolatedRect(from: self, to: target, progress: progress)
    }
}

#Preview("Single Surface") {
    SingleSurfacePreview()
        .frame(width: 620, height: 360)
        .environment(\.buttonMaterial, .glassClear)
}

private struct SingleSurfacePreview: View {
    @State private var isPresented = true

    private let source = CGRect(x: 24, y: 24, width: 180, height: 120)
    private let target = CGRect(x: 180, y: 70, width: 360, height: 220)

    var body: some View {
        ZStack(alignment: .topLeading) {
            UI.Card.Scaffold(title: "preview-web",
                             subtitle: "Collapsed") {
                UI.Card.IconChip(symbol: "shippingbox.fill", tint: .accentColor)
            } titleAccessory: {
                EmptyView()
            } subtitleAccessory: {
                EmptyView()
            } headerAccessory: {
                EmptyView()
            } bodyContent: {
                EmptyView()
            } footerLeading: {
                EmptyView()
            } footerActions: {
                EmptyView()
            } widget: {
                EmptyView()
            }
            .frame(width: source.width, height: source.height)
            .position(x: source.midX, y: source.midY)

            UX.Morph.SingleSurface(source: source,
                                   target: target,
                                   progress: 0.65) {
                UI.Card.Scaffold(size: .large,
                                 isExpanded: true,
                                 title: "preview-web",
                                 subtitle: "Expanded") {
                    UI.Card.IconChip(symbol: "shippingbox.fill", tint: .accentColor)
                } titleAccessory: {
                    UI.Badge.Text(text: "Running")
                } subtitleAccessory: {
                    EmptyView()
                } headerAccessory: {
                    EmptyView()
                } bodyContent: {
                    UI.Card.InsetSection {
                        UI.Chart.Sparkline(samples: [0.1, 0.3, 0.2, 0.62],
                                           scale: .fraction)
                            .frame(height: 64)
                    }
                } footerLeading: {
                    UI.Card.MetricText(text: "62%")
                } footerActions: {
                    UI.Card.FooterButton(systemName: "xmark", help: "Close") {}
                } widget: {
                    EmptyView()
                }
            }

            if isPresented {
                UX.Morph.SingleSurfaceExpander(isPresented: $isPresented,
                                               originFrame: source,
                                               target: .centered(size: CGSize(width: 320, height: 180)),
                                               showsBackdrop: false) {
                    UI.Surface.Content(elevated: true) {
                        Text("Lifecycle expander")
                    }
                }
                .opacity(0.001)
                .allowsHitTesting(false)
            }
        }
    }
}
