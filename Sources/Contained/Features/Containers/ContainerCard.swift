import SwiftUI
import ContainedDesignSystem
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
    var histories: [GraphMetric: SampleBuffer] = [:]
    var isBusy: Bool
    var hasImageUpdate: Bool = false
    var isExpanded: Bool = false
    var cornerRadiusOverride: CGFloat?
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
    @State private var draftStyle: Personalization? = nil
    /// Session-only graph tab selection. The footer chips act as tabs and switch the graph.
    @State private var selectedWidgetIndex = 0

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
    private var styleForDisplay: Personalization { draftStyle ?? style }
    private var tint: Color { styleForDisplay.color }
    private var name: String { styleForDisplay.displayName(fallback: snapshot.id) }
    private var isRunning: Bool { presentation == .running }
    private var activeWidgetIndex: Int {
        let enabled = styleForDisplay.widgets.indices.filter { styleForDisplay.widget(at: $0).enabled }
        return enabled.contains(selectedWidgetIndex) ? selectedWidgetIndex : (enabled.first ?? 0)
    }
    private var activeWidget: WidgetConfiguration { styleForDisplay.widget(at: activeWidgetIndex) }
    private var activeWidgetColor: Color { activeWidget.tint?.color ?? tint }
    private var activeWidgetComparisonMetric: GraphMetric? {
        activeWidget.style.resolvedSecondaryMetric(primary: activeWidget.metric,
                                                   requested: activeWidget.secondaryMetric,
                                                   options: GraphMetric.allCases)
    }
    private var cardSize: ResourceCardSize { density.resourceSize }

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
        .onChange(of: showingCustomize) { _, isShowing in
            if isShowing {
                draftStyle = style
            } else {
                draftStyle = nil
            }
        }
        // Anchored to the whole card (via the surrounding Group), so the popover floats beside the
        // real, live card — which is itself the preview. The customizer carries only the form.
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(snapshot: snapshot, presentation: .popover, onDraftChange: { draft in
                draftStyle = draft
            })
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
                          cornerRadiusOverride: cornerRadiusOverride,
                          controlsVisible: controlsVisible,
                          isSelected: isSelected,
                          fill: styleForDisplay.fillBackground ? styleForDisplay.color : nil,
                          fillOpacity: styleForDisplay.backgroundOpacity,
                          gradient: styleForDisplay.gradient,
                          gradientAngle: styleForDisplay.gradientAngle,
                          blendMode: styleForDisplay.backgroundBlendMode,
                          onTap: onTap) {
            headerRow(controlsReveal: controlsVisible ? 1 : 0)
        } bodyContent: {
            detailBody
        } footerLeading: {
            if styleForDisplay.showStatusIndicator {
                statusChip
            }
            ForEach(styleForDisplay.widgets.indices.filter { styleForDisplay.widget(at: $0).enabled }, id: \.self) { index in
                widgetChip(index)
            }
        } footerActions: {
            footerActions
        } widget: {
            LiveSparkline(samples: histories[activeWidget.metric]?.values ?? history,
                          comparisonSamples: activeWidgetComparisonMetric.flatMap { histories[$0]?.values } ?? [],
                          color: activeWidgetColor,
                          lineWidth: activeWidget.lineWidth,
                          style: activeWidget.style,
                          areaUsesGradient: activeWidget.areaUsesGradient,
                          interpolation: activeWidget.interpolation,
                          pointSize: activeWidget.pointSize,
                          barWidth: activeWidget.barWidth)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.ResourceCard.sparklineHeight)
        }
        .overlay { if isBusy { ProgressView().controlSize(.small) } }
    }

    @ViewBuilder
    private func headerRow(controlsReveal: Double = 1) -> some View {
        if isExpanded {
            compactHeaderRow
                .overlay(alignment: .topTrailing) {
                    headerButtons(controlsReveal: controlsReveal)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(Tokens.Space.s)
                        .zIndex(1)
                }
        } else {
            compactHeaderRow
        }
    }

    private var compactHeaderRow: some View {
        ResourceCardHeader {
            iconChip
        } content: {
            headerTitleBlock
        } trailing: {
            EmptyView()
        }
    }

    private func headerButtons(controlsReveal: Double) -> some View {
        GlassButton(singleItem: false) {
            expandedPageButtons
            GlassButtonItem(systemName: "xmark", help: "Close") {
                onClose()
            }
        }
        .opacity(controlsReveal)
        .animation(.easeOut(duration: 0.18), value: controlsReveal)
    }

    private var headerTitleBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.ResourceCard.compactTextSpacing) {
            HStack(alignment: .top, spacing: Tokens.Space.xs) {
                ResourceCardTitleText(text: name)
            }
            HStack(alignment: .top, spacing: Tokens.Space.xs) {
                ResourceCardMonospacedSubtitleText(text: Format.shortImage(snapshot.image))
            }
        }
    }

    private var iconChip: some View {
        ContainerCustomizeButton(snapshot: snapshot, style: styleForDisplay) {
            draftStyle = style
            showingCustomize = true
        }
    }

    private var statusChip: some View {
        ResourceCardFooterMini {
            if styleForDisplay.showStatusIcon {
                Image(systemName: statusSymbol)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        } text: {
            if styleForDisplay.showStatusText {
                ResourceCardMetricText(text: statusLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .help(statusHelp)
    }

    private enum StatusState: Hashable {
        case online, restarting, stopped, unknown, failed
    }

    private var statusState: StatusState {
        if health == .unhealthy { return .failed }
        switch presentation {
        case .running: return .online
        case .stopping: return .restarting
        case .stopped: return .stopped
        case .unknown: return .unknown
        case .errored: return .failed
        }
    }

    private var statusLabel: String {
        switch statusState {
        case .online: return "Online"
        case .restarting: return "Restarting"
        case .stopped: return "Stopped"
        case .unknown: return "Unknown"
        case .failed: return "Failed"
        }
    }

    private var statusSymbol: String {
        switch statusState {
        case .online: return "dot.radiowaves.left.and.right"
        case .restarting: return "arrow.clockwise.circle.fill"
        case .stopped: return "circle.fill"
        case .unknown: return "questionmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch statusState {
        case .online: return .green
        case .restarting: return .orange
        case .stopped: return .secondary
        case .unknown: return .gray
        case .failed: return .red
        }
    }

    private var statusHelp: String {
        switch statusState {
        case .online: return "Healthy"
        case .restarting: return "Restarting"
        case .stopped: return "Stopped"
        case .unknown: return "Status unknown"
        case .failed: return "Healthcheck failing"
        }
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

    @ViewBuilder
    private var expandedPageButtons: some View {
        ForEach(Tab.allCases) { item in
            GlassButtonItem(tint: tab == item ? tint : nil,
                            help: item.rawValue,
                            isIcon: true,
                            action: { tab = item }) {
                Image(systemName: item.systemImage)
                    .opacity(tab == item ? 1 : 0.62)
            }
        }
    }

    private var detailBody: some View {
        detailContent
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch tab {
        case .overview:
            ContainerOverviewTab(snapshot: snapshot)
        case .logs:
            LogsTab(snapshot: snapshot)
        case .terminal:
            TerminalTab(snapshot: snapshot)
        case .stats:
            StatsTab(snapshot: snapshot)
        case .history:
            ContainerHistoryTab(snapshot: snapshot)
        case .files:
            FilesTab(snapshot: snapshot)
        case .inspect:
            ContainerInspectTab(snapshot: snapshot)
        }
    }

    /// A selectable widget tab. Tapping flips the graph for this session only (not persisted).
    private func widgetChip(_ index: Int) -> some View {
        let widget = styleForDisplay.widget(at: index)
        let active = index == activeWidgetIndex
        return Button {
            selectedWidgetIndex = index
        } label: {
            ResourceCardFooterMini {
                if widget.showIcon {
                    Image(systemName: widget.resolvedSystemImage).font(.caption2)
                }
            } text: {
                if widget.showText {
                    ResourceCardMetricText(text: stats.map(widget.metric.chipCaption(from:)) ?? "—")
                }
            }
            .foregroundStyle(active ? AnyShapeStyle(widget.tint?.color ?? tint) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .help(widget.metric.displayName)
    }

    /// Lifecycle + edit/delete, styled to match the compact card's small plain play/stop glyph
    /// rather than the heavier prominent glass circles (per the simplified footer).
    @ViewBuilder
    private var footerActions: some View {
        if isRunning {
            footerAction("stop.fill", help: "Stop", action: onStop)
            footerAction("arrow.clockwise", help: "Restart", action: onRestart)
        } else {
            footerAction("play.fill", help: "Start", tint: tint, action: onStart)
        }
        footerAction("slider.horizontal.3", help: "Edit", action: onEdit)
        footerAction("trash", help: "Delete", tint: .red) { confirmingDelete = true }
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ResourceCardFooterMini {
                Image(systemName: systemName).font(.body)
            } text: {
                EmptyView()
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint ?? .secondary)
        .help(help)
        .accessibilityLabel(help)
    }
}
