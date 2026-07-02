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
    var isUsableForMorph: Bool {
        MorphGeometry.isUsableFrame(self)
    }

    func morphInterpolated(to target: CGRect, progress: CGFloat) -> CGRect {
        MorphGeometry.interpolatedRect(from: self, to: target, progress: progress)
    }
}
