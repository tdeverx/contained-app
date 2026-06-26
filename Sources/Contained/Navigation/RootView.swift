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
                .contentBackground(reduceTransparency: settings.reduceTranslucency,
                                   material: settings.windowMaterial.nsMaterial)
                .mainToolbar(ui: ui, settings: settings)
                .toolbarBackground(.visible, for: .windowToolbar)
                .navigationTitle(ui.section.title)
                .searchable(text: $ui.searchText, prompt: "Search \(ui.section.title.lowercased())")
                .searchFocused($searchFocused)
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
        }
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
        case .networks: NetworksListView()
        case .registries: RegistriesView()
        case .system: SystemView()
        case .templates: TemplatesSectionView()
        }
    }

}
