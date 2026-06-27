import SwiftUI
import SwiftData
import ContainedCore

/// The app-wide, custom (non-native) toolbar that lives in the title-bar band of the hidden-title-bar
/// window. Three compact glass groups — add menu (leading), search + command palette (center),
/// updates + activity (trailing) — stay **constant across pages** (high-level, not per-section).
///
/// Mounted as a top overlay over the **detail column** in `RootView` (never over the sidebar): the
/// band sits in the title-bar region, the rest of the area is hit-transparent until a control opens.
/// The add `+` grows a `MorphingExpander` panel from its slot; the center search field is a single
/// item that expands *in place* into the command palette (one field, no separate panel). Control
/// sizing comes from `Tokens.Toolbar` / `ToolbarControls`.
struct AppToolbar: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.appSafeAreas) private var safeAreas

    @State private var slots: [UIState.ToolbarMorph: CGRect] = [:]
    @State private var addSoftDismiss: (() -> Void)?

    static let space = "appToolbar"
    /// Title-bar band height. The toolbar lives in the detail column (no traffic lights there), so the
    /// leading inset is just normal padding. Sourced from `Tokens.Toolbar` so the band, the safe-area
    /// manager, and the controls all agree.
    static let bandHeight: CGFloat = Tokens.Toolbar.band

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                toolbarRow
                    .frame(height: Tokens.Toolbar.controlHeight)
                    .padding(.top, rowTopInset)   // centered on the traffic-light line
                Spacer(minLength: 0)            // empty + hit-transparent below the band
                    .allowsHitTesting(false)
            }
            // The center search/command-palette is a single element that expands in place; it lives in
            // its own full-area layer so its open state can float over the page with a backdrop.
            ToolbarCommandPalette(insets: morphTargetInsets)
                .zIndex(ui.activeMorph == .palette ? 20 : 5)
            addMorphLayer
                .zIndex(ui.activeMorph == .add ? 30 : 0)
            updatesMorphLayer
                .zIndex(ui.activeMorph == .updates ? 30 : 0)
            activityMorphLayer
                .zIndex(ui.activeMorph == .activity ? 30 : 0)
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(ToolbarSlotKey.self) { slots = $0 }
    }

    // MARK: Row

    private var toolbarRow: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            leadingZone
            Spacer(minLength: Tokens.Space.m)
            toolbarGroup { trailingZone }
        }
        .padding(.horizontal, Tokens.Toolbar.outerPadding)
        .frame(maxWidth: .infinity)
    }

    // The add control is a standalone circle (single action); the trailing updates/activity buttons are a
    // grouped capsule.
    private var leadingZone: some View {
        ToolbarIconButton(systemName: "plus", help: "Add") { ui.toggleMorph(.add) }
            .frame(width: Tokens.Toolbar.controlHeight, height: Tokens.Toolbar.controlHeight)
            .glassEffect(.regular.interactive(), in: Circle())
            .opacity(ui.activeMorph == .add ? 0 : 1)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ToolbarSlotKey.self,
                                           value: [.add: proxy.frame(in: .named(Self.space))])
                }
            )
    }

    private var trailingZone: some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) {
            ToolbarIconButton(systemName: "arrow.down.circle", help: "Updates") { ui.toggleMorph(.updates) }
                .opacity(ui.activeMorph == .updates ? 0 : 1)
                .background(slotReader(.updates))
            ToolbarIconButton(systemName: "clock.arrow.circlepath", help: "Activity") { ui.toggleMorph(.activity) }
                .opacity(ui.activeMorph == .activity ? 0 : 1)
                .background(slotReader(.activity))
        }
    }

    /// A grouped capsule of related buttons (e.g. updates + activity).
    private func toolbarGroup<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(spacing: Tokens.Toolbar.groupSpacing) { content() }
            .padding(.horizontal, Tokens.Toolbar.groupPaddingH)
            .frame(height: Tokens.Toolbar.controlHeight)
            .toolbarControlGlass()
    }

    // MARK: Add morph layer

    @ViewBuilder
    private var addMorphLayer: some View {
        if ui.activeMorph == .add {
            MorphingExpander(isPresented: addMorphBinding, originFrame: slots[.add] ?? .zero,
                             panelSize: CGSize(width: 440, height: 300),   // initial; flow resizes per page
                             placement: .anchored,
                             targetInsets: morphTargetInsets,
                             onBackdropTap: addSoftDismiss) {
                CreationFlow(start: .menu,
                             onClose: {
                                 addSoftDismiss = nil
                                 ui.activeMorph = nil
                             },
                             onSoftDismissChange: { addSoftDismiss = $0 })
            }
        }
    }

    @ViewBuilder
    private var updatesMorphLayer: some View {
        if ui.activeMorph == .updates {
            MorphingExpander(isPresented: morphBinding(.updates),
                             originFrame: slots[.updates] ?? .zero,
                             panelSize: CGSize(width: 440, height: 300),
                             placement: .anchored,
                             targetInsets: morphTargetInsets) {
                ToolbarUpdatesPanel {
                    ui.activeMorph = nil
                }
            }
        }
    }

    @ViewBuilder
    private var activityMorphLayer: some View {
        if ui.activeMorph == .activity {
            MorphingExpander(isPresented: morphBinding(.activity),
                             originFrame: slots[.activity] ?? .zero,
                             panelSize: CGSize(width: 460, height: 360),
                             placement: .anchored,
                             targetInsets: morphTargetInsets) {
                ToolbarActivityPanel {
                    ui.activeMorph = nil
                }
            }
        }
    }

    private var addMorphBinding: Binding<Bool> {
        Binding(get: { ui.activeMorph == .add }, set: {
            if !$0 { addSoftDismiss = nil; ui.activeMorph = nil }
        })
    }

    private func morphBinding(_ morph: UIState.ToolbarMorph) -> Binding<Bool> {
        Binding(get: { ui.activeMorph == morph }, set: {
            if !$0 { ui.activeMorph = nil }
        })
    }

    private func slotReader(_ morph: UIState.ToolbarMorph) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ToolbarSlotKey.self,
                                   value: [morph: proxy.frame(in: .named(Self.space))])
        }
    }

    private var morphTargetInsets: EdgeInsets {
        safeAreas.morphInsets(.includingToolbar)
    }

    private var rowTopInset: CGFloat { Tokens.Toolbar.topPadding }
}

private struct ToolbarUpdatesPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    var onClose: () -> Void

    private var updateGroups: [LocalImageTagGroup] {
        LocalImageTagGroup.groups(for: app.images).filter {
            app.imageUpdateStatus(for: $0.primaryReference).state == .updateAvailable
        }
    }

    private var alertGroups: [LocalImageTagGroup] {
        LocalImageTagGroup.groups(for: app.images).filter {
            app.imageUpdateStatus(for: $0.primaryReference).state == .error
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    countdownCard(context.date)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
                        if updateGroups.isEmpty && alertGroups.isEmpty {
                            emptyCard
                        } else {
                            ForEach(updateGroups) { group in
                                updateCard(group)
                            }
                            ForEach(alertGroups) { group in
                                alertCard(group)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxHeight: 300)
                HStack {
                    Button {
                        Task { await app.runImageUpdateSweepNow() }
                    } label: {
                        Label("Run Now", systemImage: "play.fill")
                    }
                    .buttonStyle(.glassProminent)
                    Button {
                        ui.section = .images
                        onClose()
                    } label: {
                        Label("Open Images", systemImage: "square.stack.3d.up")
                    }
                    .buttonStyle(.glass)
                    Spacer(minLength: 0)
                }
            }
            .padding(Tokens.Space.l)
        }
        .morphPanelSize(CGSize(width: 520, height: 540))
        .morphPanelPlacement(.anchored)
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color.accentColor)
                .frame(width: Tokens.IconSize.control, height: Tokens.IconSize.control)
            VStack(alignment: .leading, spacing: 1) {
                Text("Updates").font(.headline)
                Text("\(updateGroups.count) available · \(app.imageUpdateIntervalDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GlassCircleButton(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
        }
        .padding(Tokens.Space.l)
    }

    private var emptyCard: some View {
        ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("No image updates").font(.callout.weight(.medium))
                    Text("Everything checked is current").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func updateCard(_ group: LocalImageTagGroup) -> some View {
        let status = app.imageUpdateStatus(for: group.primaryReference)
        let style = imageStyle(for: group)
        return ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.s) {
                imageChip(style)
                VStack(alignment: .leading, spacing: 1) {
                    Text(repositoryName(group.primaryReference))
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(updateSubtitle(group, status: status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                GlassCircleButton(systemName: "arrow.down", help: "Pull Update") {
                    Task { await app.pullImageUpdate(group.primaryReference) }
                }
            }
        }
    }

    private func alertCard(_ group: LocalImageTagGroup) -> some View {
        let status = app.imageUpdateStatus(for: group.primaryReference)
        let style = imageStyle(for: group)
        return ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.s) {
                imageChip(style)
                VStack(alignment: .leading, spacing: 1) {
                    Text(repositoryName(group.primaryReference))
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(status.message ?? "Update check failed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func countdownCard(_ now: Date) -> some View {
        ResourceGlassCard(size: .small) {
            HStack(spacing: Tokens.Space.s) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                    .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                    .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Next check").font(.callout.weight(.medium))
                    Text(app.imageUpdateIntervalDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(countdown(to: app.imageUpdateNextRunDate, now: now))
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
            }
        }
    }

    private func imageStyle(for group: LocalImageTagGroup) -> Personalization {
        guard let image = (group.images.first { $0.reference == group.primaryReference } ?? group.images.first) else {
            return Personalization()
        }
        return app.personalization.imageDefault(for: image.reference) ?? Personalization()
    }

    private func imageChip(_ style: Personalization) -> some View {
        Image(systemName: style.symbol)
            .font(.system(size: 15))
            .foregroundStyle(style.color)
            .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
            .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func repositoryName(_ reference: String) -> String {
        let parsed = RegistryImageReference.parse(reference)
        if parsed.registry == "registry-1.docker.io", parsed.repository.hasPrefix("library/") {
            return String(parsed.repository.dropFirst("library/".count))
        }
        return parsed.repository
    }

    private func updateSubtitle(_ group: LocalImageTagGroup, status: ImageUpdateStatus) -> String {
        let tags = "\(group.references.count) tag\(group.references.count == 1 ? "" : "s")"
        guard let checkedAt = status.checkedAt else { return tags }
        return "\(tags) · Checked \(checkedAt.formatted(date: .omitted, time: .shortened))"
    }

    private func countdown(to date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds == 0 { return "due now" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm %02ds", minutes, secs) }
        return "\(secs)s"
    }
}

private struct ToolbarActivityPanel: View {
    var onClose: () -> Void

    var body: some View {
        ActivityContent(showClose: true, onClose: onClose)
            .morphPanelSize(CGSize(width: 560, height: 520))
        .morphPanelPlacement(.anchored)
    }
}

/// The toolbar's center element: a single search field that filters the current page live
/// (`ui.searchText`) and **expands in place** into the full command palette (it doesn't hide behind a
/// separate panel — the same field stays as the header, the results list drops below it). Opens on ⌘K,
/// on submit, or automatically when an in-page search comes up empty.
private struct ToolbarCommandPalette: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @FocusState private var focused: Bool
    let insets: EdgeInsets

    private var isOpen: Bool { ui.activeMorph == .palette }
    private var items: [PaletteItem] { PaletteItem.filtered(ui.searchText, app: app, ui: ui) }
    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    /// Visual open state, animated explicitly off `isOpen` so the grow plays for every trigger
    /// (⌘K, submit, escalation) — implicit `.animation(value:)` wasn't firing for the size change.
    @State private var expanded = false

    private let collapsedWidth: CGFloat = Tokens.Toolbar.searchMaxWidth
    private let openWidth: CGFloat = 560
    private let openHeightCap: CGFloat = 480
    private var topInset: CGFloat { Tokens.Toolbar.topPadding }

    var body: some View {
        GeometryReader { geo in
            let openHeight = max(Tokens.Toolbar.controlHeight,
                                 min(openHeightCap, geo.size.height - topInset - insets.bottom))
            ZStack(alignment: .top) {
                if expanded {
                    Rectangle()
                        .fill(.black.opacity(0.28))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                        .transition(.opacity)
                }
                panel(openHeight: openHeight)
                    .frame(maxWidth: .infinity, alignment: .top)   // centered in the detail area
            }
        }
        .onChange(of: ui.searchText) { _, _ in escalateIfEmpty() }
        .onChange(of: ui.pageResultCount) { _, _ in escalateIfEmpty() }
        .onChange(of: isOpen) { _, open in
            if open { ui.paletteIndex = 0 }
            focused = open
            withAnimation(spring) { expanded = open }
        }
        // ⌘S focuses the page-search field (without opening the palette).
        .onChange(of: ui.searchFocusToken) { _, _ in focused = true }
    }

    private func panel(openHeight: CGFloat) -> some View {
        // Drive visuals off `expanded` (animated), keeping the list mounted but faded + clipped when
        // collapsed so the height interpolates smoothly instead of the content popping in/out.
        let radius = expanded ? Tokens.Radius.sheet : Tokens.Toolbar.controlHeight / 2
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return VStack(spacing: 0) {
            fieldRow
                .frame(height: expanded ? Tokens.Toolbar.searchOpenHeaderHeight : Tokens.Toolbar.controlHeight)
            Divider().opacity(expanded ? 0.5 : 0)
            resultsList.opacity(expanded ? 1 : 0)
        }
        .frame(width: expanded ? openWidth : collapsedWidth,
               height: expanded ? openHeight : Tokens.Toolbar.controlHeight,
               alignment: .top)
        // Same surface as the add-button morph (floatingPanelMaterial: shadow .24/24/12, border .18) so
        // both toolbar morphs read as the one gesture.
        .background { Color.clear.glassEffect(.regular.interactive(), in: shape) }
        .clipShape(shape)
        .overlay { if expanded { shape.strokeBorder(.white.opacity(0.18), lineWidth: 1) } }
        .shadow(color: .black.opacity(expanded ? 0.24 : 0), radius: expanded ? 24 : 0, y: expanded ? 12 : 0)
        .padding(.top, topInset)
    }

    private var fieldRow: some View {
        @Bindable var ui = ui
        return HStack(spacing: Tokens.Toolbar.searchIconGap) {
            Image(systemName: "magnifyingglass")
                .font(.body)                       // scales with the field text (Dynamic Type), like the buttons
                .foregroundStyle(.secondary)
            TextField(isOpen ? "Search or run a command…" : "Search this page, or ⌘K for commands",
                      text: $ui.searchText)
                .textFieldStyle(.plain)
                .font(.body).fontWeight(.medium)   // 13pt medium on macOS, Dynamic-Type scalable
                .focused($focused)
                .onSubmit { onSubmit() }
                .onKeyPress(.downArrow) { guard isOpen else { return .ignored }; move(1); return .handled }
                .onKeyPress(.upArrow) { guard isOpen else { return .ignored }; move(-1); return .handled }
                .onKeyPress(.escape) { guard isOpen else { return .ignored }; close(); return .handled }
            if !ui.searchText.isEmpty {
                Button { ui.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Clear search").accessibilityLabel("Clear search")
            } else {
                Text(isOpen ? "esc" : "⌘K").font(.caption2).fontWeight(.medium).foregroundStyle(.tertiary)
            }
        }
        // Roomier horizontal inset once expanded so the field breathes inside the larger panel.
        .padding(.horizontal, expanded ? Tokens.Space.l : Tokens.Toolbar.searchInnerPadding)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == ui.paletteIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { run(item) }
                    }
                }
                .padding(.horizontal, Tokens.Space.m)   // roomier results gutter, matched to the open field
                .padding(.vertical, Tokens.Space.s)
            }
            .onChange(of: ui.paletteIndex) { _, new in proxy.scrollTo(new, anchor: .center) }
        }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: Tokens.Space.m) {
            Image(systemName: item.icon).foregroundStyle(item.tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if selected { Image(systemName: "return").font(.caption).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Behavior

    private func onSubmit() {
        if isOpen { runSelected() } else { ui.toggleMorph(.palette) }
    }

    /// Escalate an in-page search into the palette when a query (≥2 chars) finds nothing on a page that
    /// reports a count. Guards on `activeMorph == nil` so it only escalates once.
    private func escalateIfEmpty() {
        guard ui.activeMorph == nil else { return }
        let q = ui.searchText.trimmingCharacters(in: .whitespaces)
        if q.count >= 2, ui.pageResultCount == 0 { ui.activeMorph = .palette }
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        ui.paletteIndex = min(max(0, ui.paletteIndex + delta), items.count - 1)
    }

    private func runSelected() {
        guard items.indices.contains(ui.paletteIndex) else { return }
        run(items[ui.paletteIndex])
    }

    private func run(_ item: PaletteItem) {
        close()
        item.action()
    }

    private func close() {
        ui.activeMorph = nil
        ui.searchText = ""
    }
}

/// Collects toolbar button slot frames (in the toolbar coordinate space) so a morph can grow from the
/// exact button that opened it.
private struct ToolbarSlotKey: PreferenceKey {
    static let defaultValue: [UIState.ToolbarMorph: CGRect] = [:]
    static func reduce(value: inout [UIState.ToolbarMorph: CGRect],
                       nextValue: () -> [UIState.ToolbarMorph: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
