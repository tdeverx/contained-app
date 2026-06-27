import SwiftUI
import ContainedCore

/// A personalized clear-glass card for one container. The same component renders both the compact
/// grid card and the centered expanded detail card.
struct ContainerCard: View {
    let snapshot: ContainerSnapshot
    var style: Personalization
    var density: CardDensity
    var stats: StatsDelta?
    var history: [Double]
    /// Every metric's recent history, so the expanded footer's chips can flip the graph instantly
    /// without waiting for the parent to recompute. The compact card just uses `history`.
    var histories: [GraphMetric: [Double]] = [:]
    /// Persist the metric the user picks from the expanded footer (so the compact card matches too).
    var onSelectMetric: (GraphMetric) -> Void = { _ in }
    var isBusy: Bool
    var isExpanded: Bool = false
    /// Whether the expanded card's controls (footer buttons + close) are shown. The grid drops this
    /// the instant a close begins so the glass buttons fade out *before* the shrink finishes.
    var controlsVisible: Bool = true
    var onTap: () -> Void
    var onStart: () -> Void
    var onStop: () -> Void
    var onRestart: () -> Void
    var onEdit: () -> Void = {}
    var onDelete: () -> Void
    var onClose: () -> Void = {}
    var onSelectMultiple: () -> Void = {}
    var onToggleSelected: () -> Void = {}
    var onEndSelecting: () -> Void = {}
    /// Show the "Reveal CLI" affordance (gated by the global Settings toggle).
    var revealCLI: Bool = true
    /// App-managed healthcheck status (drives the heart badge).
    var health: HealthStatus = .unknown
    /// Multi-select mode: tapping toggles selection instead of opening the detail.
    var selecting: Bool = false
    var isSelected: Bool = false
    /// Force a status (used by the customizer preview to show a "running" look).
    var previewPresentation: StatusPresentation? = nil

    @State private var hovering = false
    @State private var tab: Tab = .overview
    @State private var confirmingDelete = false
    /// Footer-chip override for the plotted metric — instant local response; also persisted via
    /// `onSelectMetric`. Nil falls back to the resolved style.
    @State private var localMetric: GraphMetric? = nil

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case logs = "Logs"
        case terminal = "Terminal"
        case stats = "Stats"
        case history = "History"
        case files = "Files"
        case inspect = "Inspect"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .overview: return "rectangle.grid.1x2"
            case .logs: return "text.alignleft"
            case .terminal: return "terminal"
            case .stats: return "chart.xyaxis.line"
            case .history: return "clock.arrow.circlepath"
            case .files: return "folder"
            case .inspect: return "doc.text.magnifyingglass"
            }
        }
    }

    private var presentation: StatusPresentation { previewPresentation ?? StatusPresentation(snapshot.state) }
    private var tint: Color { style.color }
    private var name: String { style.displayName(fallback: snapshot.id) }
    private var isRunning: Bool { presentation == .running }
    private var metric: GraphMetric { localMetric ?? style.graphMetric }
    /// The recent history for the currently-plotted metric (live switch in the expanded footer).
    private var plotted: [Double] { histories[metric] ?? history }
    // Compact drops the ~66pt graph block (58pt sparkline + Space.s), so it's that much shorter than
    // large; both share the same width band.
    private var cardHeight: CGFloat { density == .compact ? 110 : 176 }
    /// The metrics offered as selectable footer chips (the runtime exposes no GPU stat).
    private let footerMetrics: [GraphMetric] = [.cpu, .memory, .netRx, .netTx]

    var body: some View {
        Group {
            if isExpanded {
                cardSurface
            } else {
                cardSurface
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    .contextMenu { menuItems }
                    .onHover { hovering = $0 }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(presentation.label)")
        .confirmationDialog("Delete \(name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                onDelete()
                onClose()
            }
        } message: {
            Text("This removes the container. This can't be undone.")
        }
    }

    private var cardSurface: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if isExpanded {
                expandedBody
            } else {
                collapsedBody
            }
        }
        .padding(Tokens.Space.m)
        // Expanded: fill the actual (animating) frame so header/footer stay pinned to the real top
        // and bottom edges — NOT a fixed min height, which would push the footer past the bottom
        // and clip it during the grow. Collapsed: keep the fixed card height.
        .frame(maxWidth: .infinity,
               minHeight: isExpanded ? 0 : cardHeight,
               maxHeight: isExpanded ? .infinity : nil,
               // Expanded anchors to the bottom: the footer is the fixed bottom bookend, so if the
               // card ever shrinks below header+footer (the compact slot on close) the overflow
               // clips at the top instead of pushing the footer past the bottom and snapping.
               alignment: isExpanded ? .bottomLeading : .topLeading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card,
                      fill: style.fillBackground ? style.color : nil,
                      fillOpacity: style.backgroundOpacity,
                      gradient: style.gradient,
                      gradientAngle: style.gradientAngle)
        .overlay(alignment: .topTrailing) { if isBusy { ProgressView().controlSize(.small).padding(8) } }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Tokens.Radius.card)
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    .padding(1)
            }
        }
    }

    /// The collapsed card is just the two bookends — header on top, the shared footer pinned to the
    /// bottom. Large shows the graph; compact hides it (graph only on expand). Buttons stay hidden
    /// until hover. No body.
    @ViewBuilder
    private var collapsedBody: some View {
        headerRow()
        Spacer(minLength: 0)
        cardFooter(showGraph: density == .large, showButtons: hovering)
    }

    /// The expanded interior. Header and footer are DIRECT children of the card's VStack, so the real
    /// stack layout pins them to the top/bottom edges every frame (no lag). Only the middle tab area
    /// is a GeometryReader, which reveals the body inline with its height.
    @ViewBuilder
    private var expandedBody: some View {
        headerRow(controlsReveal: controlsVisible ? 1 : 0)
        GeometryReader { proxy in
            detailTabs
                .frame(width: proxy.size.width, height: proxy.size.height)
                .opacity(clamp((proxy.size.height - 40) / 160))
        }
        cardFooter(showGraph: true, showButtons: controlsVisible)
    }

    private func clamp(_ value: CGFloat) -> Double { Double(max(0, min(1, value))) }

    private func headerRow(controlsReveal: Double = 1) -> some View {
        HStack(spacing: Tokens.Space.s) {
            iconChip
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    StatusOrb(presentation: presentation, size: 7)
                    if health == .unhealthy {
                        Image(systemName: "heart.slash.fill").font(.system(size: 9))
                            .foregroundStyle(.red).help("Healthcheck failing")
                    } else if health == .healthy {
                        Image(systemName: "heart.fill").font(.system(size: 9))
                            .foregroundStyle(.green).help("Healthy")
                    }
                }
                Text(Format.shortImage(snapshot.image))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isExpanded {
                closeAction
                    .opacity(controlsReveal)
                    .animation(.easeOut(duration: 0.18), value: controlsReveal)
            }
        }
    }

    private var iconChip: some View {
        ContainerCustomizeButton(snapshot: snapshot, style: style)
    }

    /// The container's actions for the right-click context menu.
    @ViewBuilder
    private var menuItems: some View {
        if isRunning {
            Button { onStop() } label: { Label("Stop", systemImage: "stop.fill") }
            Button { onRestart() } label: { Label("Restart", systemImage: "arrow.clockwise") }
        } else {
            Button { onStart() } label: { Label("Start", systemImage: "play.fill") }
        }
        Divider()
        Button { onTap() } label: { Label("Open details", systemImage: "rectangle.expand.vertical") }
        if selecting {
            Button { onToggleSelected() } label: {
                Label(isSelected ? "Deselect" : "Select", systemImage: isSelected ? "checkmark.circle.fill" : "circle")
            }
            Button { onEndSelecting() } label: { Label("Done Selecting", systemImage: "checkmark") }
        } else {
            Button { onSelectMultiple() } label: { Label("Select Multiple", systemImage: "checklist") }
        }
        Button { onEdit() } label: { Label("Edit…", systemImage: "slider.horizontal.3") }
        Button { copyToPasteboard(snapshot.id) } label: { Label("Copy ID", systemImage: "doc.on.doc") }
        if revealCLI {
            Button { copyToPasteboard("container inspect \(snapshot.id)") } label: {
                Label("Copy as CLI", systemImage: "terminal")
            }
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
    }

    private var closeAction: some View {
        GlassCircleButton(systemName: "xmark", tint: tint, help: "Close", isCancel: true) { onClose() }
    }

    private var detailTabs: some View {
        TabView(selection: $tab) {
            ContainerOverviewTab(snapshot: snapshot)
                .tabItem { Label(Tab.overview.rawValue, systemImage: Tab.overview.systemImage) }
                .tag(Tab.overview)
            LogsTab(snapshot: snapshot)
                .tabItem { Label(Tab.logs.rawValue, systemImage: Tab.logs.systemImage) }
                .tag(Tab.logs)
            TerminalTab(snapshot: snapshot)
                .tabItem { Label(Tab.terminal.rawValue, systemImage: Tab.terminal.systemImage) }
                .tag(Tab.terminal)
            StatsTab(snapshot: snapshot)
                .tabItem { Label(Tab.stats.rawValue, systemImage: Tab.stats.systemImage) }
                .tag(Tab.stats)
            ContainerHistoryTab(snapshot: snapshot)
                .tabItem { Label(Tab.history.rawValue, systemImage: Tab.history.systemImage) }
                .tag(Tab.history)
            FilesTab(snapshot: snapshot)
                .tabItem { Label(Tab.files.rawValue, systemImage: Tab.files.systemImage) }
                .tag(Tab.files)
            ContainerInspectTab(snapshot: snapshot)
                .tabItem { Label(Tab.inspect.rawValue, systemImage: Tab.inspect.systemImage) }
                .tag(Tab.inspect)
        }
        .tabViewStyle(.automatic)
        .tint(tint)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The shared bottom bookend — identical on the compact and expanded cards. The expanded card
    /// shows the live graph above the metrics row; the compact card hides the graph but keeps the
    /// selectable percentages. It never resizes, so the open/close animation has nothing to reflow.
    private func cardFooter(showGraph: Bool, showButtons: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            if showGraph {
                LiveSparkline(samples: plotted, color: tint)
                    .frame(height: 58)
            }
            HStack(spacing: Tokens.Space.m) {
                ForEach(footerMetrics) { metricChip($0) }
                Spacer(minLength: 0)
                // Always laid out (even when hidden) so the action glyphs — taller than the metric
                // chips — set a constant row height. Hiding via opacity keeps the footer from
                // jumping when the buttons fade in on hover. Identical metrics row in all 3 states.
                footerActions
                    .opacity(showButtons ? 1 : 0)
                    .allowsHitTesting(showButtons)
                    // Quick, self-contained fade — independent of the slower grow/shrink spring — so
                    // on close the buttons are gone well before the card finishes shrinking.
                    .animation(.easeOut(duration: 0.18), value: showButtons)
            }
        }
        .padding(.top, showGraph ? Tokens.Space.s : 0)
    }

    /// A selectable CPU·Memory·Net readout. Tapping flips the graph (instantly + persisted); the
    /// metric currently driving the graph is tinted, the rest are muted.
    private func metricChip(_ chip: GraphMetric) -> some View {
        let active = chip == metric
        return Button {
            // Update local state for instant UI feedback
            localMetric = chip
            // Only persist if this is a real change from the current style metric
            if chip != style.graphMetric {
                onSelectMetric(chip)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: chip.systemImage).font(.system(size: 10))
                Text(stats.map(chip.chipCaption(from:)) ?? "—")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }
            .foregroundStyle(active ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .help(chip.displayName)
    }

    /// Lifecycle + edit/delete, styled to match the compact card's small plain play/stop glyph
    /// rather than the heavier prominent glass circles (per the simplified footer).
    private var footerActions: some View {
        HStack(spacing: Tokens.Space.m) {
            if isRunning {
                footerAction("stop.fill", help: "Stop", action: onStop)
                footerAction("arrow.clockwise", help: "Restart", action: onRestart)
            } else {
                footerAction("play.fill", help: "Start", tint: tint, action: onStart)
            }
            footerAction("slider.horizontal.3", help: "Edit", action: onEdit)
            footerAction("trash", help: "Delete", tint: .red) { confirmingDelete = true }
        }
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint ?? .secondary)
        .help(help)
        .accessibilityLabel(help)
    }
}
