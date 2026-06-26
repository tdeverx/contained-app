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
    var isBusy: Bool
    var isExpanded: Bool = false
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
    private var metric: GraphMetric { style.graphMetric }
    private var cardHeight: CGFloat { density == .compact ? 136 : 176 }

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
        // Roomier sheet-like padding when expanded (matches the Customize/Settings panels); compact
        // padding for grid cards.
        .padding(isExpanded ? Tokens.Space.l : Tokens.Space.m)
        // Expanded: fill the actual (animating) frame so header/footer stay pinned to the real top
        // and bottom edges — NOT a fixed min height, which would push the footer past the bottom
        // and clip it during the grow. Collapsed: keep the fixed card height.
        .frame(maxWidth: .infinity,
               minHeight: isExpanded ? 0 : cardHeight,
               maxHeight: isExpanded ? .infinity : nil,
               alignment: .topLeading)
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

    @ViewBuilder
    private var collapsedBody: some View {
        headerRow()
        portsRow                       // both densities now (renders only when ports are published)
        if density == .large { statsStrip }
        sparkRow                        // flexible — fills the remaining height, no dead band
        collapsedFooter
    }

    /// A compact CPU · Memory readout for the large card, shown when live stats are available.
    @ViewBuilder
    private var statsStrip: some View {
        if let stats {
            HStack(spacing: Tokens.Space.m) {
                statChip("cpu", GraphMetric.cpu.caption(from: stats))
                statChip("memorychip", GraphMetric.memory.caption(from: stats))
                Spacer(minLength: 0)
            }
        }
    }

    private func statChip(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(value).font(.system(size: 11, weight: .medium)).monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }

    /// The expanded interior, laid out against its live height so everything tracks the grow/shrink:
    /// header and footer/graph are sticky bookends; the tab body reveals with the opening gap; and
    /// the glass control buttons (close + lifecycle/edit/delete) fade out earlier than the body so
    /// they're gone well before the card finishes collapsing.
    private var expandedBody: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let bodyReveal = clamp((h - 180) / 200)
            let controlsReveal = clamp((h - 300) / 130)
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                headerRow(controlsReveal: controlsReveal)
                detailTabs.opacity(bodyReveal)
                expandedFooter(controlsReveal: controlsReveal)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private func clamp(_ value: CGFloat) -> Double { Double(max(0, min(1, value))) }

    private func headerRow(controlsReveal: Double = 1) -> some View {
        HStack(spacing: Tokens.Space.s) {
            iconChip
            VStack(alignment: .leading, spacing: isExpanded ? 2 : 1) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(isExpanded ? .system(size: 16, weight: .semibold) : .system(size: 14, weight: .medium))
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
                    .font(.system(size: isExpanded ? 12 : 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isExpanded { closeAction.opacity(controlsReveal) }
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

    private var portsRow: some View {
        let ports = snapshot.configuration.publishedPorts
        return Group {
            if !ports.isEmpty {
                Text(ports.map(\.display).joined(separator: ", "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var sparkRow: some View {
        LiveSparkline(samples: history, color: tint)
            .frame(minHeight: density == .large ? 26 : 16, maxHeight: .infinity)
    }

    private var collapsedFooter: some View {
        HStack(spacing: Tokens.Space.s) {
            Label(metric.displayName, systemImage: metric.systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(isRunning ? "↑ \(Format.uptime(since: snapshot.startedDate))" : presentation.label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let stats { Text(metric.caption(from: stats)).font(.system(size: 12, weight: .medium)).foregroundStyle(tint) }
            if hovering {
                Button(action: isRunning ? onStop : onStart) {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
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

    private func expandedFooter(controlsReveal: Double) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            // The graph is a persistent bookend: always visible, stretching to full width with the
            // card. It is never gated by the reveal — only the tab body in the gap is.
            LiveSparkline(samples: history, color: tint)
                .frame(height: 58)
            HStack(spacing: Tokens.Space.s) {
                Label(metric.displayName, systemImage: metric.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(isRunning ? "↑ \(Format.uptime(since: snapshot.startedDate))" : presentation.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let stats {
                    Text(metric.caption(from: stats))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tint)
                }
                // The glass control buttons fade out early on close so they're gone before the card
                // finishes collapsing — the metric/uptime text stays as part of the footer bookend.
                footerActions.opacity(controlsReveal)
                lifecycleActions.opacity(controlsReveal)
            }
        }
    }

    private var lifecycleActions: some View {
        HStack(spacing: Tokens.Space.s) {
            if isRunning {
                GlassCircleButton(systemName: "stop.fill", prominent: true, role: .destructive, help: "Stop") { onStop() }
                GlassCircleButton(systemName: "arrow.clockwise", prominent: true, tint: tint, help: "Restart") { onRestart() }
            } else {
                GlassCircleButton(systemName: "play.fill", prominent: true, tint: tint, help: "Start") { onStart() }
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: Tokens.Space.s) {
            GlassCircleButton(systemName: "slider.horizontal.3", prominent: true, tint: tint, help: "Edit") { onEdit() }
            GlassCircleButton(systemName: "trash", prominent: true, role: .destructive, help: "Delete") {
                confirmingDelete = true
            }
        }
    }
}
