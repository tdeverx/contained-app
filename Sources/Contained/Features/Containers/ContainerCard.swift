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
    var isBusy: Bool
    var hasImageUpdate: Bool = false
    var isExpanded: Bool = false
    /// Whether the expanded card's controls (footer buttons + close) are shown. The grid drops this
    /// the instant a close begins so the glass buttons fade out *before* the shrink finishes.
    var controlsVisible: Bool = true
    var onTap: () -> Void
    var onStart: () -> Void
    var onStop: () -> Void
    var onRestart: () -> Void
    var onEdit: () -> Void = {}
    var onUpdate: () -> Void = {}
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

    @State private var tab: Tab = .overview
    @State private var confirmingDelete = false
    /// Customize popover, anchored to the whole card so the live card is the preview.
    @State private var showingCustomize = false
    /// Footer-chip override for the plotted metric — session-only (never persisted). Nil falls back
    /// to the resolved style's metric.
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

    private var presentation: StatusPresentation { StatusPresentation(snapshot.state) }
    private var tint: Color { style.color }
    private var name: String { style.displayName(fallback: snapshot.id) }
    private var isRunning: Bool { presentation == .running }
    private var metric: GraphMetric { localMetric ?? style.graphMetric }
    /// The recent history for the currently-plotted metric (live switch in the expanded footer).
    private var plotted: [Double] { histories[metric] ?? history }
    private var cardSize: ResourceCardSize { density.resourceSize }
    /// The metrics offered as selectable footer chips (the runtime exposes no GPU stat).
    private let footerMetrics: [GraphMetric] = [.cpu, .memory, .netRx, .netTx]

    var body: some View {
        Group {
            if isExpanded {
                cardSurface
            } else {
                cardSurface
                    .contextMenu { menuItems }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(presentation.label)")
        // Anchored to the whole card (via the surrounding Group), so the popover floats beside the
        // real, live card — which is itself the preview. The customizer carries only the form.
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(snapshot: snapshot, presentation: .popover)
        }
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
        ResourceGlassCard(size: cardSize,
                          isExpanded: isExpanded,
                          controlsVisible: controlsVisible,
                          isSelected: isSelected,
                          fill: style.fillBackground ? style.color : nil,
                          fillOpacity: style.backgroundOpacity,
                          gradient: style.gradient,
                          gradientAngle: style.gradientAngle,
                          onTap: onTap) {
            headerRow(controlsReveal: controlsVisible ? 1 : 0)
        } bodyContent: {
            detailTabs
        } footerLeading: {
            ForEach(footerMetrics) { metricChip($0) }
        } footerActions: {
            footerActions
        } widget: {
            LiveSparkline(samples: plotted, color: tint)
                .frame(height: 58)
        }
        .overlay(alignment: .topTrailing) { if isBusy { ProgressView().controlSize(.small).padding(8) } }
    }

    private func headerRow(controlsReveal: Double = 1) -> some View {
        HStack(spacing: Tokens.Space.s) {
            iconChip
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    StatusOrb(presentation: presentation, size: 7)
                    if health == .unhealthy {
                        Image(systemName: "heart.slash.fill").font(.caption2)
                            .foregroundStyle(.red).help("Healthcheck failing")
                    } else if health == .healthy {
                        Image(systemName: "heart.fill").font(.caption2)
                            .foregroundStyle(.green).help("Healthy")
                    }
                }
                Text(Format.shortImage(snapshot.image))
                    .font(.system(.caption, design: .monospaced))
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
        ContainerCustomizeButton(snapshot: snapshot, style: style) { showingCustomize = true }
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
        if hasImageUpdate {
            Button { onUpdate() } label: { Label("Update Container…", systemImage: "arrow.down.circle") }
        }
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

    /// A selectable CPU·Memory·Net readout. Tapping flips the graph for this session only (not
    /// persisted); the metric currently driving the graph is tinted, the rest are muted.
    private func metricChip(_ chip: GraphMetric) -> some View {
        let active = chip == metric
        return Button {
            // Temporary, session-only graph switch — deliberately NOT persisted, so flipping the
            // graph never creates a per-container override or changes the saved default.
            localMetric = chip
        } label: {
            HStack(spacing: 4) {
                Image(systemName: chip.systemImage).font(.caption2)
                Text(stats.map(chip.chipCaption(from:)) ?? "—")
                    .font(.caption.weight(.medium))
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
            Image(systemName: systemName).font(.body)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint ?? .secondary)
        .help(help)
        .accessibilityLabel(help)
    }
}
