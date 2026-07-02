import SwiftUI

public struct MorphFrame: Equatable, Sendable {
    public var source: CGRect
    public var target: CGRect
    public var progress: CGFloat

    public init(source: CGRect, target: CGRect, progress: CGFloat) {
        self.source = source
        self.target = target
        self.progress = MorphGeometry.clampedProgress(progress)
    }

    public var rect: CGRect {
        source.morphInterpolated(to: target, progress: progress)
    }
}

/// Hosts one promoted surface while it grows from an existing slot into a larger target rect.
///
/// This is the single-card version of the rect motion used by `MorphingExpander`: callers keep the
/// source view laid out in place, hide it while selected, and render one overlay through this helper.
public struct MorphingSingleSurface<Content: View>: View {
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
        let rect = MorphFrame(source: source, target: target, progress: progress).rect
        content()
            .frame(width: max(rect.width, 1), height: max(rect.height, 1), alignment: alignment)
            .position(x: rect.midX, y: rect.midY)
    }
}

/// Hosts one promoted card-like surface with the same lifecycle as `MorphingExpander`, but without
/// drawing a separate panel shell around the content.
///
/// Use this when the promoted content is already its own visual surface, such as an expanded
/// `DesignCardSurface`. Panel contents should still use `MorphingExpander`.
public struct MorphingSingleSurfaceExpander<Content: View>: View {
    @Binding var isPresented: Bool
    public var originFrame: CGRect
    public var target: MorphTarget
    public var backdropStyle: GlobalBackdropStyle
    public var showsBackdrop: Bool
    public var closeRequestToken: Int
    public var onBackdropTap: (() -> Void)?
    public var onExpansionChange: ((Bool) -> Void)?
    @ViewBuilder private var content: () -> Content

    @State private var expanded = false
    @State private var liveSize: CGSize?
    @State private var livePlacement: MorphPanelPlacement?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.morphSafeAreas) private var safeAreas
    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    public init(isPresented: Binding<Bool>,
                originFrame: CGRect,
                target: MorphTarget,
                backdropStyle: GlobalBackdropStyle = .dim,
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
                    safeAreas: safeAreas,
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

public extension MorphGeometry {
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
        MorphGeometry.interpolatedRect(from: self, to: target, progress: progress)
    }
}
