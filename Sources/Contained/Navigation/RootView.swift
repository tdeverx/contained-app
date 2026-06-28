import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ContainedCore

/// The app shell: a single translucent content area (Containers) with the app-wide toolbar floating in
/// the title-bar band. The sidebar is gone — global actions live in the toolbar morph panels, the
/// command palette (⌘K), and the page-background overflow menu.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Image load/prune used to live on the Images page; now they're global (the page is gone).
    @State private var pruningImages = false
    /// Registry login used to live on the Registries page; the page is gone (credentials live in
    /// Settings), so the login sheet is presented globally instead.
    @State private var registryLogin = false
    /// System logs used to live on the System page; the page is now a toolbar panel, so the standalone
    /// viewer (reachable from menus / the command palette) is presented globally.
    @State private var showSystemLogs = false

    var body: some View {
        @Bindable var settings = app.settings
        @Bindable var ui = ui
        detailShell(settings: settings)
        .sheet(isPresented: $ui.showCreateWizard, onDismiss: { ui.creationPrefillSpec = nil }) {
            CreationWizard(entry: ui.creationEntry, prefill: ui.creationPrefillSpec)
        }
        .sheet(isPresented: $ui.showRunSheet, onDismiss: { ui.prefillSpec = nil; ui.advancePrefillQueue() }) {
            ContainerEditSheet(mode: .new(prefill: ui.prefillSpec))
        }
        .sheet(isPresented: downgradeBinding) {
            DowngradeDecisionView(schemaVersion: app.downgradeSchemaVersion ?? StateMigrator.currentSchemaVersion,
                                  onExportAndReset: { app.exportForDowngradeAndReset() },
                                  onKeep: { app.resolveDowngradeByKeepingReadableData() },
                                  onQuit: { NSApplication.shared.terminate(nil) })
        }
        .sheet(isPresented: whatsNewBinding) {
            ReleaseNotesView(title: "What’s New",
                             html: app.updater.currentReleaseNotesHTML,
                             onClose: { app.updater.markWhatsNewSeen() })
        }
        // These used to live on now-removed pages (Images / Registries / System); they're dispatched
        // globally from the toolbar panels, menus, and the command palette.
        .onChange(of: ui.pendingAction) { _, action in
            switch action {
            case .loadImage:     ui.pendingAction = nil; loadImageTar()
            case .pruneImages:   ui.pendingAction = nil; pruningImages = true
            case .registryLogin: ui.pendingAction = nil; registryLogin = true
            case .systemLogs:    ui.pendingAction = nil; showSystemLogs = true
            default: break
            }
        }
        .sheet(isPresented: $registryLogin) { RegistryLoginSheet() }
        .sheet(isPresented: $showSystemLogs) { SystemLogsSheet() }
        .confirmationDialog("Prune images?", isPresented: $pruningImages) {
            Button("Remove unused", role: .destructive) { Task { await pruneImages(all: false) } }
            Button("Remove all unreferenced", role: .destructive) { Task { await pruneImages(all: true) } }
        } message: {
            Text("Unused images aren't referenced by any container. “All” also removes dangling layers.")
        }
        // App-wide drop: a compose file opens the creation flow prefilled; an image .tar loads into the
        // store. The Images page keeps its own .tar drop target, which takes precedence there.
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls {
                switch url.pathExtension.lowercased() {
                case "yaml", "yml": ComposeImport.importFile(at: url, app: app, ui: ui); return true
                case "tar":         app.loadImageTar(at: url); return true
                default:            continue
                }
            }
            return false
        }
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
            await app.bootstrapIfNeeded()
            app.coordinator.start(app: app)
        }
        .onChange(of: scenePhase) { _, phase in
            app.coordinator.isActive = (phase == .active)
        }
    }

    private func detailShell(settings: SettingsStore) -> some View {
        GeometryReader { proxy in
            ZStack {
                ContentBackgroundLayer(reduceTransparency: settings.reduceTranslucency,
                                       material: settings.windowMaterial.nsMaterial)
                // Pages respect the top safe area again now that the toolbar occupies that band — so their
                // content starts below the toolbar rather than under it. (The background layer self-ignores
                // the safe area, so the vibrancy still fills behind the toolbar.)
                content
            }
            .environment(\.appSafeAreas, AppSafeAreaManager(system: proxy.safeAreaInsets,
                                                            toolbarHeight: AppToolbar.bandHeight))
            // The app-wide toolbar draws up into the title-bar band; its morph panels center within the
            // content area.
            .overlay { AppToolbar().ignoresSafeArea(.container, edges: .top) }
        }
        // Right-click the empty background for the page's overflow actions (cards/rows keep their own
        // context menus, which take precedence). Double-click it to zoom the window — the gesture the
        // title bar used to provide.
        .contextMenu { backgroundMenu() }
        // NOTE: double-click-to-zoom is NOT here — on the shell it would sit above the cards, delay
        // their taps, and fire when double-clicking a card. Pages attach it to a background layer
        // behind their content via `.zoomWindowOnBackgroundDoubleClick()` instead.
    }

    private var downgradeBinding: Binding<Bool> {
        Binding(get: { app.downgradeSchemaVersion != nil },
                set: { if !$0 { app.downgradeSchemaVersion = nil } })
    }

    private var whatsNewBinding: Binding<Bool> {
        Binding(get: { app.updater.showWhatsNew },
                set: { if !$0 { app.updater.markWhatsNewSeen() } })
    }

    /// The page-overflow menu (formerly the toolbar's ⋯), shown by right-clicking the background.
    @ViewBuilder
    private func backgroundMenu() -> some View {
        @Bindable var ui = ui
        @Bindable var settings = app.settings
        Button { app.coordinator.wake() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        Divider()
        Toggle(isOn: $ui.runningOnly) { Label("Show Running Only", systemImage: "play.circle") }
        Picker(selection: $settings.density) {
            ForEach(CardDensity.allCases) { Text($0.displayName).tag($0) }
        } label: { Label("Card Size", systemImage: "square.grid.2x2") }
        Divider()
        Button { ui.toggleMorph(.system) } label: { Label("System", systemImage: "gearshape.2") }
        Button { ui.toggleMorph(.activity) } label: { Label("Activity", systemImage: "clock.arrow.circlepath") }
        Divider()
        Button { ui.toggleMorph(.palette) } label: { Label("Command Palette…", systemImage: "command") }
    }

    /// Pick an image `.tar` and load it into the local store (formerly the Images page loader).
    private func loadImageTar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.message = "Choose an image tar archive"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        app.loadImageTar(at: url)
    }

    private func pruneImages(all: Bool) async {
        guard let client = app.client else { return }
        if let error = await app.captured({ _ = try await client.pruneImages(all: all) }) { app.flash(error) }
        await app.refreshImagesIfStale(force: true)
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
        case .ready: ContainersGridView()   // the only standing page; everything else is a toolbar panel
        default: BootstrapView()
        }
    }

}
