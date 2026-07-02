import SwiftUI
import ContainedUI

public enum PanelPlacement: Equatable, Sendable {
    case anchored
    case centered
}

public struct MorphTargetConfig {
    public var placement: PanelPlacement
    public var safeArea: SafeAreaPolicy
    public var margin: CGFloat
    public var proposedSize: (CGRect) -> CGSize

    public init(placement: PanelPlacement,
                safeArea: SafeAreaPolicy,
                margin: CGFloat,
                proposedSize: @escaping (CGRect) -> CGSize) {
        self.placement = placement
        self.safeArea = safeArea
        self.margin = margin
        self.proposedSize = proposedSize
    }

    public static func anchored(size: CGSize,
                                safeArea: SafeAreaPolicy = .toolbarChrome,
                                margin: CGFloat = MorphGeometryEngine.defaultMargin) -> MorphTargetConfig {
        MorphTargetConfig(placement: .anchored,
                       safeArea: safeArea,
                       margin: margin,
                       proposedSize: { _ in size })
    }

    public static func centered(size: CGSize,
                                safeArea: SafeAreaPolicy = .content,
                                margin: CGFloat = MorphGeometryEngine.defaultMargin) -> MorphTargetConfig {
        MorphTargetConfig(placement: .centered,
                       safeArea: safeArea,
                       margin: margin,
                       proposedSize: { _ in size })
    }

    public static func centered(safeArea: SafeAreaPolicy = .content,
                                margin: CGFloat = MorphGeometryEngine.defaultMargin,
                                proposedSize: @escaping (CGRect) -> CGSize) -> MorphTargetConfig {
        MorphTargetConfig(placement: .centered,
                       safeArea: safeArea,
                       margin: margin,
                       proposedSize: proposedSize)
    }

    public func rect(origin: CGRect,
                     in container: CGSize,
                     safeAreaManager: SafeAreaManager,
                     proposedSize overrideSize: CGSize? = nil,
                     placement overridePlacement: PanelPlacement? = nil) -> CGRect {
        let bounds = safeAreaManager.bounds(in: container, policy: safeArea)
        return MorphGeometryEngine.targetRect(origin: origin,
                                        proposedSize: overrideSize ?? proposedSize(bounds),
                                        bounds: bounds,
                                        placement: overridePlacement ?? placement,
                                        margin: margin)
    }
}

public struct PanelBackdropStyle: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let dim = PanelBackdropStyle(rawValue: 1 << 0)
    public static let blur = PanelBackdropStyle(rawValue: 1 << 1)
    public static let blurAndDim: PanelBackdropStyle = [.blur, .dim]
}

public enum MorphGeometryEngine {
    public static let defaultMargin: CGFloat = UI.Layout.Spacing.l
    public static let centeredTopMargin: CGFloat = UI.Layout.Spacing.xxl * 2

    public static func fittedSize(_ proposed: CGSize, in container: CGSize,
                                  margin: CGFloat = defaultMargin) -> CGSize {
        fittedSize(proposed, in: CGRect(origin: .zero, size: container), margin: margin)
    }

    public static func fittedSize(_ proposed: CGSize, in bounds: CGRect,
                                  margin: CGFloat = defaultMargin) -> CGSize {
        let maxWidth = max(1, bounds.width - margin * 2)
        let maxHeight = max(1, bounds.height - margin * 2)
        return CGSize(width: min(max(UI.Panel.Size.minWidth, proposed.width), maxWidth),
                      height: min(max(UI.Panel.Size.minHeight, proposed.height), maxHeight))
    }

    public static func targetRect(origin: CGRect, proposedSize: CGSize, container: CGSize,
                                  placement: PanelPlacement,
                                  margin: CGFloat = defaultMargin) -> CGRect {
        targetRect(origin: origin,
                   proposedSize: proposedSize,
                   bounds: CGRect(origin: .zero, size: container),
                   placement: placement,
                   margin: margin)
    }

    public static func targetRect(origin: CGRect, proposedSize: CGSize, bounds: CGRect,
                                  placement: PanelPlacement,
                                  margin: CGFloat = defaultMargin) -> CGRect {
        let size = fittedSize(proposedSize, in: bounds, margin: margin)
        switch placement {
        case .centered:
            let x = bounds.minX + (bounds.width - size.width) / 2
            let y = bounds.minY + (bounds.height - size.height) / 2
            return clamped(CGRect(origin: CGPoint(x: x, y: y), size: size),
                           in: bounds, margin: margin)
        case .anchored:
            let fallback = CGPoint(x: bounds.minX + margin, y: bounds.minY + margin)
            let originPoint = origin.isUsableForMorph ? origin.origin : fallback
            return clamped(CGRect(origin: originPoint, size: size),
                           in: bounds, margin: margin)
        }
    }

    public static func clamped(_ rect: CGRect, in container: CGSize,
                               margin: CGFloat = defaultMargin) -> CGRect {
        clamped(rect, in: CGRect(origin: .zero, size: container), margin: margin)
    }

    public static func clamped(_ rect: CGRect, in bounds: CGRect,
                               margin: CGFloat = defaultMargin) -> CGRect {
        let width = min(max(1, rect.width), max(1, bounds.width - margin * 2))
        let height = min(max(1, rect.height), max(1, bounds.height - margin * 2))
        let minX = bounds.minX + margin
        let minY = bounds.minY + margin
        let maxX = max(minX, bounds.maxX - width - margin)
        let maxY = max(minY, bounds.maxY - height - margin)
        let x = min(max(rect.minX.isFinite ? rect.minX : minX, minX), maxX)
        let y = min(max(rect.minY.isFinite ? rect.minY : minY, minY), maxY)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

extension CGSize {
    var isUsableForMorphPanel: Bool {
        width.isFinite && height.isFinite && width > 1 && height > 1
    }
}

/// A centered material panel that **grows from an origin slot** (e.g. a toolbar button) over a
/// dimmed/blurred backdrop, then shrinks back into it on close — the same in-place grow the container
/// cards use for their detail panel, hoisted into a reusable primitive.
///
/// Mount it inside a **window-spanning** `ZStack` whose coordinate space matches the one `originFrame`
/// was measured in (so the grow starts from the real button location). It owns the open/close spring;
/// the parent just toggles `isPresented` and supplies the slot frame + panel content.
public struct MorphExpander<Content: View>: View {
    /// Bound presence. The expander animates the close itself, then flips this to `false` on completion.
    @Binding var isPresented: Bool
    /// The slot the panel grows out of / collapses back into, in this view's coordinate space.
    let originFrame: CGRect
    var target: MorphTargetConfig
    var backdropStyle: PanelBackdropStyle = .dim
    var showsBackdrop = true
    var showsPanelShadow = true
    var closeRequestToken = 0
    var sourceCornerRadius = UI.Toolbar.Size.groupRadius
    var targetCornerRadius = UI.Panel.Radius.surface
    var onBackdropTap: (() -> Void)?
    var onExpansionChange: ((Bool) -> Void)?
    @ViewBuilder var content: () -> Content

    @State private var expanded = false
    /// Live target size — seeded from `panelSize`, then updated (with the spring) whenever the hosted
    /// content reports a new desired size via `.morphPanelSize(...)`. This is what lets a paged panel
    /// resize and re-center as it moves between sections.
    @State private var liveSize: CGSize?
    @State private var livePlacement: PanelPlacement?
    @Namespace private var shellNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.morphSafeAreaManager) private var safeAreaManager
    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    public init(isPresented: Binding<Bool>,
         originFrame: CGRect,
         target: MorphTargetConfig = .centered(size: CGSize(width: 460, height: 440)),
         backdropStyle: PanelBackdropStyle = .dim,
         showsBackdrop: Bool = true,
         showsPanelShadow: Bool = true,
         closeRequestToken: Int = 0,
         sourceCornerRadius: CGFloat = UI.Toolbar.Size.groupRadius,
         targetCornerRadius: CGFloat = UI.Panel.Radius.surface,
         onBackdropTap: (() -> Void)? = nil,
         onExpansionChange: ((Bool) -> Void)? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self.originFrame = originFrame
        self.target = target
        self.backdropStyle = backdropStyle
        self.showsBackdrop = showsBackdrop
        self.showsPanelShadow = showsPanelShadow
        self.closeRequestToken = closeRequestToken
        self.sourceCornerRadius = sourceCornerRadius
        self.targetCornerRadius = targetCornerRadius
        self.onBackdropTap = onBackdropTap
        self.onExpansionChange = onExpansionChange
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            let target = targetRect(in: geo.size)
            let source = originFrame.isUsableForMorph ? originFrame : target
            let rect = MorphFrameGeometry(source: source,
                                  target: target,
                                  progress: expanded ? 1 : 0).rect
            let cornerRadius = expanded ? targetCornerRadius : sourceCornerRadius
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

                MorphPanelShell(cornerRadius: cornerRadius,
                                showsShadow: showsPanelShadow)
                    .matchedGeometryEffect(id: "morph-panel-shell",
                                           in: shellNamespace,
                                           properties: .frame)
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                    .position(x: rect.midX, y: rect.midY)

                content()
                    // Lay the content out ONCE at the final panel size, then reveal it through the
                    // growing/clipping window below. Framing it to the *animating* rect instead would
                    // re-lay-out — and re-draw Canvas-based sparklines — on every frame of the open
                    // spring, which made content-heavy panels jitter.
                    .frame(width: max(target.width, 1), height: max(target.height, 1), alignment: .top)
                    // Fade only foreground content. The panel surface and shadow are separate, always
                    // visible layers so elevation participates in the morph instead of popping in late.
                    .opacity(expanded ? 1 : 0)
                    // The animating window clips the (statically laid-out) content, pinned to the top so
                    // headers hug the top edge as the panel grows or shrinks.
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1), alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            // Grow on the next runloop so the panel has a real starting (origin) frame to animate from.
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
        guard !reduceMotion else { isPresented = false; return }
        withAnimation(spring) { expanded = false } completion: { isPresented = false }
    }
}

public extension View {
    func globalBackdrop(style: PanelBackdropStyle,
                        progress: Double,
                        dimOpacity: Double = 0.28) -> some View {
        self
            .overlay {
                if style.contains(.blur) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(progress)
                        .ignoresSafeArea()
                }
            }
            .overlay {
                if style.contains(.dim) {
                    Rectangle()
                        .fill(.black.opacity(dimOpacity * progress))
                        .ignoresSafeArea()
                }
            }
    }
}

private struct MorphPanelShell: View {
    var cornerRadius = UI.Panel.Radius.surface
    var showsShadow = true

    var body: some View {
        Color.clear
            .floatingPanelMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow)
    }
}

/// Hosted content reports its desired panel size up to the enclosing `MorphExpander`, which animates
/// the panel to it — so a paged panel can resize and re-center between sections.
struct MorphPanelSizeKey: PreferenceKey {
    static let defaultValue: CGSize? = nil
    static func reduce(value: inout CGSize?, nextValue: () -> CGSize?) {
        if let next = nextValue() { value = next }
    }
}

struct MorphPanelPlacementKey: PreferenceKey {
    static let defaultValue: PanelPlacement? = nil
    static func reduce(value: inout PanelPlacement?,
                       nextValue: () -> PanelPlacement?) {
        if let next = nextValue() { value = next }
    }
}

public extension View {
    /// Declare the desired size of the panel hosting this content (read by `MorphExpander`).
    func morphPanelSize(_ size: CGSize) -> some View {
        preference(key: MorphPanelSizeKey.self, value: size)
    }

    /// Declare whether the hosting morph panel should stay near its source slot or move to center.
    func morphPanelPlacement(_ placement: PanelPlacement) -> some View {
        preference(key: MorphPanelPlacementKey.self, value: placement)
    }
}
