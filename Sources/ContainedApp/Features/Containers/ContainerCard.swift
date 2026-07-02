import SwiftUI
import ContainedDesignSystem
import ContainedCore

/// A personalized clear-glass card for one container. The same component renders both the compact
/// grid card and the centered expanded detail card.
struct ContainerCard: View {
    let snapshot: ContainerSnapshot
    var style: Personalization
    var hasStyleOverride: Bool = true
    var density: CardDensity
    var stats: StatsDelta?
    var statsNormalization: StatsNormalizationContext = .containerSpecific
    /// Every metric's recent history, so the footer's widget chips can flip the graph instantly
    /// without borrowing another metric's samples.
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
    /// App-managed healthcheck status (drives the heart badge).
    var health: HealthStatus = .unknown
    /// Multi-select mode: tapping toggles selection instead of opening the detail.
    var selecting: Bool = false
    var isSelected: Bool = false
    var selectedWidgetIndex: Binding<Int>?

    @State private var tab: Tab = .overview
    @State private var confirmingDelete = false
    /// Customize popover, anchored to the whole card so the live card is the preview.
    @State private var showingCustomize = false
    @State private var draftStyle: Personalization? = nil
    /// Session-only graph tab selection. The footer chips act as tabs and switch the graph.
    @State private var localSelectedWidgetIndex = 0

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case logs = "Logs"
        case terminal = "Terminal"
        case stats = "Stats"
        case history = "History"
        case files = "Files"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .overview: return "rectangle.grid.1x2"
            case .logs: return "text.alignleft"
            case .terminal: return "terminal"
            case .stats: return "chart.xyaxis.line"
            case .history: return "clock.arrow.circlepath"
            case .files: return "folder"
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
        let selected = selectedWidgetIndex?.wrappedValue ?? localSelectedWidgetIndex
        return enabled.contains(selected) ? selected : (enabled.first ?? 0)
    }
    private var activeWidget: WidgetConfiguration { styleForDisplay.widget(at: activeWidgetIndex) }
    private var activeWidgetColor: Color { activeWidget.tint?.color ?? tint }
    private var activeWidgetComparisonMetric: GraphMetric? {
        activeWidget.style.resolvedSecondaryMetric(primary: activeWidget.metric,
                                                   requested: activeWidget.secondaryMetric,
                                                   options: GraphMetric.allCases)
    }
    private var cardSize: DesignCardSize { density.resourceSize }

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
        .accessibilityLabel(AppText.containerCardAccessibility(name: name, status: presentation.label))
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
            CustomizeSheet(snapshot: snapshot,
                           presentation: .popover,
                           initialStyle: style,
                           initiallyOverridesInheritedStyle: hasStyleOverride,
                           onDraftChange: { draft in
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
        DesignCard(size: cardSize,
                     isExpanded: isExpanded,
                     cornerRadiusOverride: cornerRadiusOverride,
                     controlsVisible: controlsVisible,
                     isSelected: isSelected,
                     fill: styleForDisplay.fillBackground ? styleForDisplay.color : nil,
                     fillOpacity: styleForDisplay.backgroundOpacity,
                     gradient: styleForDisplay.gradient,
                     gradientAngle: styleForDisplay.gradientAngle,
                     blendMode: styleForDisplay.backgroundBlendMode,
                     onTap: onTap,
                     title: name,
                     subtitle: Format.shortImage(snapshot.image),
                     subtitleStyle: .monospaced,
                     pages: cardPages) {
            iconChip
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            EmptyView()
        } headerAccessory: {
            EmptyView()
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
            LiveSparkline(samples: histories[activeWidget.metric]?.values ?? [],
                          comparisonSamples: activeWidgetComparisonMetric.flatMap { histories[$0]?.values } ?? [],
                          color: activeWidgetColor,
                          lineWidth: activeWidget.lineWidth,
                          style: activeWidget.style,
                          areaUsesGradient: activeWidget.areaUsesGradient,
                          interpolation: activeWidget.interpolation,
                          pointSize: activeWidget.pointSize,
                          barWidth: activeWidget.barWidth,
                          scale: sparklineScale(for: activeWidget.metric),
                          comparisonScale: activeWidgetComparisonMetric.map(sparklineScale(for:)))
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.DesignCard.sparklineHeight)
        }
        .designCardProgressOverlay(when: isBusy)
    }

    private var cardPages: DesignCardPages<Tab> {
        DesignCardPages(items: pageControlItems,
                          selection: tab,
                          tint: tint,
                          controlsReveal: isExpanded && controlsVisible ? 1 : 0,
                          closeLabel: AppText.close,
                          onSelect: selectTab,
                          onClose: onClose)
    }

    private var iconChip: some View {
        ContainerCustomizeButton(snapshot: snapshot, style: styleForDisplay) {
            draftStyle = style
            showingCustomize = true
        }
    }

    private var statusChip: some View {
        DesignCardFooterMini {
            if styleForDisplay.showStatusIcon {
                Image(systemName: statusSymbol)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        } text: {
            if styleForDisplay.showStatusText {
                DesignCardMetricText(text: statusLabel)
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
        Divider()
        Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
    }

    private var pageControlItems: [DesignCardPageControlItem<Tab>] {
        Tab.allCases.map { item in
            DesignCardPageControlItem(id: item,
                                        title: item.rawValue,
                                        systemImage: item.systemImage)
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
            DeferredContainerPage {
                LogsTab(snapshot: snapshot)
            }
        case .terminal:
            DeferredContainerPage {
                TerminalTab(snapshot: snapshot)
            }
        case .stats:
            DeferredContainerPage {
                StatsTab(snapshot: snapshot)
            }
        case .history:
            ContainerHistoryTab(snapshot: snapshot)
        case .files:
            FilesTab(snapshot: snapshot)
        }
    }

    private func selectTab(_ item: Tab) {
        guard tab != item else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tab = item
        }
    }

    /// A selectable widget tab. Tapping flips the graph for this session only (not persisted).
    private func widgetChip(_ index: Int) -> some View {
        let widget = styleForDisplay.widget(at: index)
        let active = index == activeWidgetIndex
        return DesignCardFooterChip(isSelected: active,
                                      tint: widget.tint?.color ?? tint,
                                      help: widget.metric.displayName,
                                      action: {
            if let selectedWidgetIndex {
                selectedWidgetIndex.wrappedValue = index
            } else {
                localSelectedWidgetIndex = index
            }
        }) {
            if widget.showIcon {
                Image(systemName: widget.resolvedSystemImage).font(.caption2)
            }
        } text: {
            if widget.showText {
                DesignCardMetricText(text: stats.map {
                    widget.metric.chipCaption(from: $0,
                                              snapshot: snapshot,
                                              normalization: statsNormalization)
                } ?? "—")
            }
        }
    }

    private func sparklineScale(for metric: GraphMetric) -> SparklineScale {
        switch metric {
        case .cpu, .memory: return .fraction
        case .netRx, .netTx, .diskRead, .diskWrite: return .normalized
        }
    }

    /// Lifecycle + edit/delete, styled to match the compact card's small plain play/stop glyph
    /// rather than the heavier prominent glass circles (per the simplified footer).
    @ViewBuilder
    private var footerActions: some View {
        if isRunning {
            footerAction("stop.fill", help: AppText.stop, action: onStop)
            footerAction("arrow.clockwise", help: AppText.restart, action: onRestart)
        } else {
            footerAction("play.fill", help: AppText.start, tint: tint, action: onStart)
        }
        footerAction("slider.horizontal.3", help: AppText.edit, action: onEdit)
        footerAction("trash", help: AppText.delete, role: .destructive) { confirmingDelete = true }
    }

    private func footerAction(_ systemName: String, help: String, tint: Color? = nil,
                              role: ButtonRole? = nil,
                              action: @escaping () -> Void) -> some View {
        DesignCardFooterButton(systemName: systemName,
                                 help: help,
                                 tint: tint,
                                 role: role,
                                 action: action)
    }
}

private struct DeferredContainerPage<Content: View>: View {
    private let delay: Duration
    @ViewBuilder var content: () -> Content

    @State private var isReady = false

    init(delay: Duration = .milliseconds(60), @ViewBuilder content: @escaping () -> Content) {
        self.delay = delay
        self.content = content
    }

    var body: some View {
        Group {
            if isReady {
                content()
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            isReady = false
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            isReady = true
        }
    }
}
