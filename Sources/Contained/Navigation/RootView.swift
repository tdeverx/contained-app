import SwiftUI
import ContainedCore

/// The two-column shell: native sidebar + content over a translucent (behind-window) background,
/// with a native search field and a section-aware Liquid Glass toolbar.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var settings = app.settings
        @Bindable var ui = ui
        NavigationSplitView {
            Sidebar(selection: $ui.section)
                .navigationSplitViewColumnWidth(min: 210, ideal: 224, max: 264)
        } detail: {
            content
                .contentBackground(reduceTransparency: settings.reduceTranslucency)
                .toolbar { toolbarContent }
                .toolbarBackground(.visible, for: .windowToolbar)
                .navigationTitle(ui.section.title)
                .searchable(text: $ui.searchText, prompt: "Search \(ui.section.title.lowercased())")
                .searchFocused($searchFocused)
                .sheet(isPresented: $ui.showRunSheet, onDismiss: { ui.prefillSpec = nil }) {
                    ContainerEditSheet(mode: .new(prefill: ui.prefillSpec))
                }
                .sheet(isPresented: $ui.showPalette) { CommandPalette() }
                .overlay(alignment: .bottom) { bannerView }
                .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.banner)
        }
        .tint(settings.accentTint.color)
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
        .onChange(of: ui.focusSearchTick) { _, _ in searchFocused = true }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = app.banner {
            Text(banner)
                .font(.callout.weight(.medium))
                .padding(.horizontal, Tokens.Space.l)
                .padding(.vertical, Tokens.Space.s)
                .glassEffect(.regular, in: Capsule())
                .padding(.bottom, Tokens.Space.l)
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
        case .networks: NetworksListView()
        case .registries: RegistriesView()
        case .system: SystemView()
        case .templates: TemplatesSectionView()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        @Bindable var settings = app.settings
        @Bindable var ui = ui

        if ui.section == .containers, app.bootstrap == .ready {
            ToolbarItem(placement: .primaryAction) {
                Picker("Show", selection: $ui.runningOnly) {
                    Text("Running").tag(true)
                    Text("All").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("Card size", selection: $settings.density) {
                    Image(systemName: "rectangle.grid.1x2").tag(CardDensity.large)
                    Image(systemName: "square.grid.3x3").tag(CardDensity.compact)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Card size")
            }
            ToolbarSpacer(.flexible, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Button { ui.showRunSheet = true } label: { Image(systemName: "plus") }
                    .help("Run a new container")
            }
        }
    }
}
