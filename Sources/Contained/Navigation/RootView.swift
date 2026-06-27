import SwiftUI
import AppKit
import ContainedCore

/// The native macOS shell: a system sidebar (whose header carries the global add ＋ / overflow ⋯
/// menus) over a translucent content area. There is no window toolbar; the command palette (⌘K)
/// covers global quick actions and in-window search is being reworked.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var settings = app.settings
        @Bindable var ui = ui
        NavigationSplitView {
            Sidebar(selection: $ui.section)
                .navigationSplitViewColumnWidth(min: 210, ideal: 224, max: 264)
        } detail: {
            detailShell(settings: settings)
        }
        .navigationTitle(ui.section.title)
        .sheet(isPresented: $ui.showRunSheet, onDismiss: { ui.prefillSpec = nil }) {
            ContainerEditSheet(mode: .new(prefill: ui.prefillSpec))
        }
        .sheet(isPresented: $ui.showPalette) { CommandPalette() }
        .overlay(alignment: .bottom) {
            VStack(spacing: Tokens.Space.s) {
                activityBar
                bannerView
            }
            .padding(.bottom, Tokens.Space.l)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.banner)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.activity)
        .tint(settings.accentTint.color)
        .environment(\.modalMaterial, settings.modalMaterial)
        .preferredColorScheme(settings.appearance.colorScheme)
        .task {
            if let restored = AppSection(rawValue: settings.lastSection) { ui.section = restored }
            await app.bootstrapIfNeeded()
            app.coordinator.start(app: app)
        }
        .onChange(of: ui.section) { _, new in
            ui.searchText = ""
            settings.lastSection = new.rawValue
            app.coordinator.activeSection = new
            app.coordinator.wake()
        }
        .onChange(of: scenePhase) { _, phase in
            app.coordinator.isActive = (phase == .active)
        }
    }

    private func detailShell(settings: SettingsStore) -> some View {
        ZStack {
            ContentBackgroundLayer(reduceTransparency: settings.reduceTranslucency,
                                   material: settings.windowMaterial.nsMaterial)
            content
        }
        // Reclaim the dead band the (now-hidden) title bar still reserves as a top safe-area inset on
        // the detail column — pages own their own top padding. The sidebar keeps its inset so the
        // traffic lights stay clear.
        .ignoresSafeArea(.container, edges: .top)
        // Right-click the empty background for the page's overflow actions (cards/rows keep their own
        // context menus, which take precedence). Double-click it to zoom the window — the gesture the
        // title bar used to provide, now that the toolbar is gone.
        .contextMenu { backgroundMenu() }
        // NOTE: double-click-to-zoom is NOT here — on the shell it would sit above the cards, delay
        // their taps, and fire when double-clicking a card. Pages attach it to a background layer
        // behind their content via `.zoomWindowOnBackgroundDoubleClick()` instead.
    }

    /// The page-overflow menu (formerly the toolbar's ⋯), shown by right-clicking the background.
    @ViewBuilder
    private func backgroundMenu() -> some View {
        @Bindable var ui = ui
        @Bindable var settings = app.settings
        Button { app.coordinator.wake() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        switch ui.section {
        case .containers:
            Divider()
            Toggle(isOn: $ui.runningOnly) { Label("Show Running Only", systemImage: "play.circle") }
            Picker(selection: $settings.density) {
                ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
            } label: { Label("Card Size", systemImage: "square.grid.2x2") }
        case .images:
            Divider()
            Button { ui.dispatch(.loadImage) } label: { Label("Load Image Tar…", systemImage: "square.and.arrow.down") }
            Button { ui.dispatch(.pruneImages) } label: { Label("Prune Images…", systemImage: "trash") }
        case .system:
            Divider()
            Button { ui.dispatch(.activityHistory) } label: { Label("Activity History", systemImage: "clock.arrow.circlepath") }
            Button { ui.dispatch(.systemLogs) } label: { Label("System Logs", systemImage: "text.alignleft") }
        default:
            EmptyView()
        }
        Divider()
        Button { ui.showPalette = true } label: { Label("Command Palette…", systemImage: "command") }
    }

    /// Toggle the front window between its zoomed (filled) and restored size — emulates the
    /// title-bar double-click now that there's no title bar to double-click.
    private func zoomFrontWindow() {
        (NSApp.keyWindow ?? NSApp.mainWindow)?.zoom(nil)
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = app.banner {
            Text(banner)
                .font(.callout.weight(.medium))
                .padding(.horizontal, Tokens.Space.l)
                .padding(.vertical, Tokens.Space.s)
                .glassEffect(.regular, in: Capsule())
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Floating progress bar for a long operation (e.g. pulling an image before a run).
    @ViewBuilder
    private var activityBar: some View {
        if let activity = app.activity {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Tokens.Space.s) {
                    ProgressView().controlSize(.small)
                    Text(activity.title).font(.callout.weight(.medium))
                    Spacer(minLength: 0)
                }
                if let fraction = activity.fraction {
                    ProgressView(value: fraction).progressViewStyle(.linear)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
                if !activity.detail.isEmpty {
                    Text(activity.detail)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.m)
            .frame(maxWidth: 460)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.bootstrap {
        case .ready: destination
        default: BootstrapView()
        }
    }

    @ViewBuilder
    private var destination: some View {
        switch ui.section {
        case .containers: ContainersGridView()
        case .images: ImagesListView()
        case .build: BuildWorkspaceView()
        case .volumes: VolumesListView()
        case .registries: RegistriesView()
        case .system: SystemView()
        case .templates: TemplatesSectionView()
        }
    }

}
