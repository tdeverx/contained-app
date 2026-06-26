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
                .toolbar { mainToolbar }
                .toolbarBackground(.visible, for: .windowToolbar)
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

    // MARK: - Unified toolbar (same shape on every page)

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        @Bindable var ui = ui
        @Bindable var settings = app.settings

        // Leading: a single "＋" that adds anything, from any page.
        ToolbarItem(placement: .navigation) {
            Menu {
                Button { ui.dispatch(.runContainer) } label: { Label("New Container…", systemImage: "shippingbox") }
                Button { ui.dispatch(.pullImage) } label: { Label("Pull Image…", systemImage: "arrow.down.circle") }
                Divider()
                Button { ui.dispatch(.createVolume) } label: { Label("New Volume…", systemImage: "externaldrive.badge.plus") }
                Button { ui.dispatch(.createNetwork) } label: { Label("New Network…", systemImage: "network") }
                Button { ui.dispatch(.registryLogin) } label: { Label("Registry Login…", systemImage: "person.badge.key") }
                Divider()
                Button { ui.section = .templates; ui.pendingComposeImport = true } label: {
                    Label("Import Compose…", systemImage: "square.on.square")
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuIndicator(.hidden)
            .help("Add…")
        }

        // Center: search.
        ToolbarItem(placement: .principal) {
            searchField(ui: ui)
        }

        // Trailing: the remaining, page-relevant actions.
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { app.coordinator.wake() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                switch ui.section {
                case .containers:
                    Divider()
                    Toggle(isOn: $ui.runningOnly) { Label("Show running only", systemImage: "play.circle") }
                    Picker(selection: $settings.density) {
                        ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
                    } label: { Label("Card size", systemImage: "square.grid.2x2") }
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
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuIndicator(.hidden)
            .help("More actions")
        }
    }

    private func searchField(ui: UIState) -> some View {
        @Bindable var ui = ui
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
            TextField("Search \(ui.section.title.lowercased())", text: $ui.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .frame(width: 220)
            if !ui.searchText.isEmpty {
                Button { ui.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Tokens.Space.s)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: Capsule())
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
