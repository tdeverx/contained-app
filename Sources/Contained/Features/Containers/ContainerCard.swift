import SwiftUI
import ContainedCore

/// A personalized clear-glass card for one container: icon chip, name + inline status orb,
/// a selectable live sparkline, and a functional `⋯` menu.
struct ContainerCard: View {
    let snapshot: ContainerSnapshot
    var style: Personalization
    var density: CardDensity
    var stats: StatsDelta?
    var history: [Double]
    var isBusy: Bool
    var onTap: () -> Void
    var onStart: () -> Void
    var onStop: () -> Void
    var onRestart: () -> Void
    var onCustomize: () -> Void
    var onEdit: () -> Void = {}
    var onDelete: () -> Void
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var presentation: StatusPresentation { previewPresentation ?? StatusPresentation(snapshot.state) }
    private var tint: Color { style.color }
    private var name: String { style.displayName(fallback: snapshot.id) }
    private var isRunning: Bool { presentation == .running }
    private var metric: GraphMetric { style.graphMetric }
    private var cardHeight: CGFloat { density == .compact ? 120 : 156 }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            header
            if density == .large { portsRow }
            Spacer(minLength: Tokens.Space.xs)
            sparkRow
            footer
        }
        .padding(Tokens.Space.m)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card, glass: .clear,
                      fill: style.fillBackground ? style.color : nil,
                      fillOpacity: style.backgroundOpacity,
                      gradient: style.gradient,
                      gradientAngle: style.gradientAngle)
        .overlay(alignment: .topTrailing) { if isBusy { ProgressView().controlSize(.small).padding(8) } }
        .overlay(alignment: .topLeading) {
            if selecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .padding(8)
            }
        }
        .overlay {
            if selecting && isSelected {
                RoundedRectangle(cornerRadius: Tokens.Radius.card)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(presentation.label)")
    }

    private var header: some View {
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
            menu
        }
    }

    private var iconChip: some View {
        Image(systemName: style.symbol)
            .font(.system(size: 15))
            .foregroundStyle(tint)
            .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var menu: some View {
        Menu {
            if isRunning {
                Button { onStop() } label: { Label("Stop", systemImage: "stop.fill") }
                Button { onRestart() } label: { Label("Restart", systemImage: "arrow.clockwise") }
            } else {
                Button { onStart() } label: { Label("Start", systemImage: "play.fill") }
            }
            Divider()
            Button { onCustomize() } label: { Label("Customize…", systemImage: "paintbrush.pointed") }
            Button { onEdit() } label: { Label("Edit…", systemImage: "slider.horizontal.3") }
            Button { copyToPasteboard(snapshot.id) } label: { Label("Copy ID", systemImage: "doc.on.doc") }
            if revealCLI {
                Button { copyToPasteboard("container inspect \(snapshot.id)") } label: {
                    Label("Copy as CLI", systemImage: "terminal")
                }
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: Tokens.IconSize.rowMenu, height: Tokens.IconSize.rowMenu)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
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
            .frame(height: density == .large ? 28 : 18)
    }

    private var footer: some View {
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
                .transition(.opacity)
            }
        }
    }
}
