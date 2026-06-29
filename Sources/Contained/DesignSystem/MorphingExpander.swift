import SwiftUI

enum MorphPanelPlacement: Equatable {
    case anchored
    case centered
    case topCentered
}

struct AppMorphTarget {
    var placement: MorphPanelPlacement
    var safeArea: AppSafeAreaPolicy
    var margin: CGFloat
    var proposedSize: (CGRect) -> CGSize

    static func anchored(size: CGSize,
                         safeArea: AppSafeAreaPolicy = .toolbarChrome,
                         margin: CGFloat = MorphGeometry.defaultMargin) -> AppMorphTarget {
        AppMorphTarget(placement: .anchored,
                       safeArea: safeArea,
                       margin: margin,
                       proposedSize: { _ in size })
    }

    static func centered(size: CGSize,
                         safeArea: AppSafeAreaPolicy = .content,
                         margin: CGFloat = MorphGeometry.defaultMargin) -> AppMorphTarget {
        AppMorphTarget(placement: .centered,
                       safeArea: safeArea,
                       margin: margin,
                       proposedSize: { _ in size })
    }

    static func centered(safeArea: AppSafeAreaPolicy = .content,
                         margin: CGFloat = MorphGeometry.defaultMargin,
                         proposedSize: @escaping (CGRect) -> CGSize) -> AppMorphTarget {
        AppMorphTarget(placement: .centered,
                       safeArea: safeArea,
                       margin: margin,
                       proposedSize: proposedSize)
    }

    static func topCentered(safeArea: AppSafeAreaPolicy = .content,
                            margin: CGFloat = MorphGeometry.defaultMargin,
                            proposedSize: @escaping (CGRect) -> CGSize) -> AppMorphTarget {
        AppMorphTarget(placement: .topCentered,
                       safeArea: safeArea,
                       margin: margin,
                       proposedSize: proposedSize)
    }

    func rect(origin: CGRect,
              in container: CGSize,
              safeAreas: AppSafeAreaManager,
              proposedSize overrideSize: CGSize? = nil,
              placement overridePlacement: MorphPanelPlacement? = nil) -> CGRect {
        let bounds = safeAreas.bounds(in: container, policy: safeArea)
        return MorphGeometry.targetRect(origin: origin,
                                        proposedSize: overrideSize ?? proposedSize(bounds),
                                        bounds: bounds,
                                        placement: overridePlacement ?? placement,
                                        margin: margin)
    }
}

struct GlobalBackdropStyle: OptionSet {
    let rawValue: Int

    static let dim = GlobalBackdropStyle(rawValue: 1 << 0)
    static let blur = GlobalBackdropStyle(rawValue: 1 << 1)
    static let blurAndDim: GlobalBackdropStyle = [.blur, .dim]
}

enum MorphGeometry {
    static let defaultMargin: CGFloat = Tokens.Space.l
    static let centeredTopMargin: CGFloat = Tokens.Space.xxl * 2

    static func fittedSize(_ proposed: CGSize, in container: CGSize,
                           margin: CGFloat = defaultMargin) -> CGSize {
        fittedSize(proposed, in: CGRect(origin: .zero, size: container), margin: margin)
    }

    static func fittedSize(_ proposed: CGSize, in bounds: CGRect,
                           margin: CGFloat = defaultMargin) -> CGSize {
        let maxWidth = max(1, bounds.width - margin * 2)
        let maxHeight = max(1, bounds.height - margin * 2)
        return CGSize(width: min(max(1, proposed.width), maxWidth),
                      height: min(max(1, proposed.height), maxHeight))
    }

    static func targetRect(origin: CGRect, proposedSize: CGSize, container: CGSize,
                           placement: MorphPanelPlacement,
                           margin: CGFloat = defaultMargin) -> CGRect {
        targetRect(origin: origin,
                   proposedSize: proposedSize,
                   bounds: CGRect(origin: .zero, size: container),
                   placement: placement,
                   margin: margin)
    }

    static func targetRect(origin: CGRect, proposedSize: CGSize, bounds: CGRect,
                           placement: MorphPanelPlacement,
                           margin: CGFloat = defaultMargin) -> CGRect {
        let size = fittedSize(proposedSize, in: bounds, margin: margin)
        switch placement {
        case .centered:
            let x = bounds.minX + (bounds.width - size.width) / 2
            let y = bounds.minY + (bounds.height - size.height) / 2
            return clamped(CGRect(origin: CGPoint(x: x, y: y), size: size),
                           in: bounds, margin: margin)
        case .topCentered:
            let x = bounds.minX + (bounds.width - size.width) / 2
            let y = bounds.minY + margin
            return clamped(CGRect(origin: CGPoint(x: x, y: y), size: size),
                           in: bounds, margin: margin)
        case .anchored:
            let fallback = CGPoint(x: bounds.minX + margin, y: bounds.minY + margin)
            let originPoint = origin.isUsable ? origin.origin : fallback
            return clamped(CGRect(origin: originPoint, size: size),
                           in: bounds, margin: margin)
        }
    }

    static func clamped(_ rect: CGRect, in container: CGSize,
                        margin: CGFloat = defaultMargin) -> CGRect {
        clamped(rect, in: CGRect(origin: .zero, size: container), margin: margin)
    }

    static func clamped(_ rect: CGRect, in bounds: CGRect,
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

private extension CGRect {
    var isUsable: Bool {
        width.isFinite && height.isFinite && minX.isFinite && minY.isFinite && width > 1 && height > 1
    }
}

/// A centered glass panel that **grows from an origin slot** (e.g. a toolbar button) over a
/// dimmed/blurred backdrop, then shrinks back into it on close — the same in-place grow the container
/// cards use for their detail panel, hoisted into a reusable primitive.
///
/// Mount it inside a **window-spanning** `ZStack` whose coordinate space matches the one `originFrame`
/// was measured in (so the grow starts from the real button location). It owns the open/close spring;
/// the parent just toggles `isPresented` and supplies the slot frame + panel content.
struct MorphingExpander<Content: View>: View {
    /// Bound presence. The expander animates the close itself, then flips this to `false` on completion.
    @Binding var isPresented: Bool
    /// The slot the panel grows out of / collapses back into, in this view's coordinate space.
    let originFrame: CGRect
    var target: AppMorphTarget
    var backdropStyle: GlobalBackdropStyle = .dim
    var showsBackdrop = true
    var showsPanelShadow = true
    var closeRequestToken = 0
    var sourceCornerRadius = Tokens.Toolbar.groupRadius
    var targetCornerRadius = Tokens.Radius.sheet
    var onBackdropTap: (() -> Void)?
    var onExpansionChange: ((Bool) -> Void)?
    @ViewBuilder var content: () -> Content

    @State private var expanded = false
    /// Live target size — seeded from `panelSize`, then updated (with the spring) whenever the hosted
    /// content reports a new desired size via `.morphPanelSize(...)`. This is what lets a paged panel
    /// resize and re-center as it moves between sections.
    @State private var liveSize: CGSize?
    @State private var livePlacement: MorphPanelPlacement?
    @Namespace private var shellNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appSafeAreas) private var safeAreas
    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    init(isPresented: Binding<Bool>,
         originFrame: CGRect,
         target: AppMorphTarget = .centered(size: CGSize(width: 460, height: 440)),
         backdropStyle: GlobalBackdropStyle = .dim,
         showsBackdrop: Bool = true,
         showsPanelShadow: Bool = true,
         closeRequestToken: Int = 0,
         sourceCornerRadius: CGFloat = Tokens.Toolbar.groupRadius,
         targetCornerRadius: CGFloat = Tokens.Radius.sheet,
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

    var body: some View {
        GeometryReader { geo in
            let target = targetRect(in: geo.size)
            let rect = expanded ? target : originFrame
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
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                content()
                    // Fade only foreground content. The panel surface and shadow are separate, always
                    // visible layers so elevation participates in the morph instead of popping in late.
                    .opacity(expanded ? 1 : 0)
                    .frame(width: rect.width, height: rect.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .onPreferenceChange(MorphPanelSizeKey.self) { size in
            guard let size else { return }
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
                    safeAreas: safeAreas,
                    proposedSize: liveSize,
                    placement: livePlacement)
    }

    private func close() {
        onExpansionChange?(false)
        guard !reduceMotion else { isPresented = false; return }
        withAnimation(spring) { expanded = false } completion: { isPresented = false }
    }
}

extension View {
    func globalBackdrop(style: GlobalBackdropStyle,
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
    var cornerRadius = Tokens.Radius.sheet
    var showsShadow = true

    var body: some View {
        Color.clear
            .floatingPanelMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow)
    }
}

/// Hosted content reports its desired panel size up to the enclosing `MorphingExpander`, which animates
/// the panel to it — so a paged panel can resize and re-center between sections.
private struct MorphPanelSizeKey: PreferenceKey {
    static let defaultValue: CGSize? = nil
    static func reduce(value: inout CGSize?, nextValue: () -> CGSize?) {
        if let next = nextValue() { value = next }
    }
}

private struct MorphPanelPlacementKey: PreferenceKey {
    static let defaultValue: MorphPanelPlacement? = nil
    static func reduce(value: inout MorphPanelPlacement?,
                       nextValue: () -> MorphPanelPlacement?) {
        if let next = nextValue() { value = next }
    }
}

extension View {
    /// Declare the desired size of the panel hosting this content (read by `MorphingExpander`).
    func morphPanelSize(_ size: CGSize) -> some View {
        preference(key: MorphPanelSizeKey.self, value: size)
    }

    /// Declare whether the hosting morph panel should stay near its source slot or move to center.
    func morphPanelPlacement(_ placement: MorphPanelPlacement) -> some View {
        preference(key: MorphPanelPlacementKey.self, value: placement)
    }
}
