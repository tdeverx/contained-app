import SwiftUI
import ContainedNavigation
import AppKit
import UniformTypeIdentifiers
import ContainedCore
import ContainedDesignSystem

/// The app shell. Fresh installs use the classic sidebar; the experimental toolbar shell adds morph
/// panels, command palette routing, and page-background overflow actions on top of the same app state.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Image load/prune are global actions because they can be invoked from pages, toolbar panels,
    /// menus, and the command palette.
    @State private var pruningImages = false
    /// System logs are reachable from menus and the command palette while system resources can render
    /// as either a sidebar page or toolbar panel.
    @State private var showSystemLogs = false

    var body: some View {
        @Bindable var settings = app.settings
        @Bindable var ui = ui
        rootShell(settings: settings)
        .sheet(isPresented: $ui.showRunSheet, onDismiss: { ui.prefillSpec = nil; ui.advancePrefillQueue() }) {
            ContainerEditSheet(mode: .new(prefill: ui.prefillSpec))
        }
        .sheet(item: $ui.editSheetSnapshot) { snapshot in
            ContainerEditSheet(mode: .edit(snapshot, onComplete: {}))
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
        // Dispatch global actions from toolbar panels, pages, menus, and the command palette. Registry
        // credentials always live in Settings.
        .onChange(of: ui.pendingAction) { _, action in
            switch action {
            case .loadImage:     ui.pendingAction = nil; loadImageTar()
            case .pruneImages:   ui.pendingAction = nil; pruningImages = true
            case .registryLogin: ui.pendingAction = nil; ui.openSettings(to: .registries)
            case .systemLogs:    ui.pendingAction = nil; showSystemLogs = true
            default: break
            }
        }
        .sheet(isPresented: $showSystemLogs) { SystemLogsSheet() }
        .confirmationDialog("Prune images?", isPresented: $pruningImages) {
            Button("Remove unused", role: .destructive) { Task { await pruneImages(all: false) } }
            Button("Remove all unreferenced", role: .destructive) { Task { await pruneImages(all: true) } }
        } message: {
            Text("Unused images aren't referenced by any container. “All” also removes dangling layers.")
        }
        // App-wide drop: compose opens editable prefilled run forms; an image .tar loads into the
        // local image store.
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls {
                switch url.pathExtension.lowercased() {
                case "yaml", "yml":
                    guard app.settings.composeImportEnabled else { continue }
                    ComposeImport.importFile(at: url, app: app, ui: ui); return true
                case "tar":         app.loadImageTar(at: url); return true
                default:            continue
                }
            }
            return false
        }
        // Long-running operations (image pulls, etc.) now surface in the bottom-left status capsule
        // (see `AppToolbar` → `ActivityStatusView`); only transient banners float at the bottom.
        .overlay(alignment: .bottom) {
            bannerView
                .padding(.bottom, DesignTokens.Space.l)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.banner)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.activity)
        .tint(settings.accentTint.color)
        .environment(\.modalMaterial, settings.modalMaterial)
        .environment(\.buttonMaterial, settings.buttonMaterial)
        .environment(\.buttonTintStyle, DesignButtonTintStyle(enabled: settings.buttonTintEnabled,
                                                             tint: settings.buttonTint,
                                                             opacity: settings.buttonTintOpacity,
                                                             gradient: settings.buttonTintGradient,
                                                             gradientAngle: settings.buttonTintGradientAngle,
                                                             blendMode: settings.buttonTintBlendMode))
        .environment(\.cardMaterial, settings.cardMaterial)
        .environment(\.designSystemShowsInfoTips, settings.showInfoTips)
        .environment(\.pageScaffoldUsesToolbarChrome, settings.experimentalToolbarUI)
        .environment(\.pageScaffoldBottomClearance, settings.experimentalToolbarUI ? AppToolbar.bandHeight : 0)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onAppear { applyAppearance(settings.appearance) }
        .onAppear { ui.toolbarUIEnabled = settings.experimentalToolbarUI }
        .onAppear {
            ui.panelNavigationEnabled = settings.usesPanelNavigation
            ui.ensureSelectedSectionIsNavigable()
            updateContainerStatsVisibility()
        }
        .onChange(of: settings.appearance) { _, mode in applyAppearance(mode) }
        .onChange(of: settings.experimentalToolbarUI) { _, enabled in
            ui.toolbarUIEnabled = enabled
            ui.panelNavigationEnabled = settings.usesPanelNavigation
            if !enabled { ui.activeMorph = nil }
            ui.ensureSelectedSectionIsNavigable()
            updateContainerStatsVisibility()
        }
        .onChange(of: settings.experimentalPanelNavigation) { _, _ in
            ui.panelNavigationEnabled = settings.usesPanelNavigation
            if !settings.usesPanelNavigation { ui.activeMorph = nil }
            ui.ensureSelectedSectionIsNavigable()
            updateContainerStatsVisibility()
        }
        .onChange(of: ui.selectedSection) { _, _ in updateContainerStatsVisibility() }
        .onChange(of: ui.activeMorph) { _, _ in updateContainerStatsVisibility() }
        .onChange(of: settings.imageBuildEnabled) { _, enabled in
            if !enabled, ui.selectedSection == .build {
                ui.navigate(to: .images)
            }
        }
        .task {
            await app.bootstrapIfNeeded()
            app.coordinator.start(app: app)
        }
        .onChange(of: scenePhase) { _, phase in
            app.coordinator.isActive = (phase == .active)
        }
    }

    @ViewBuilder
    private func rootShell(settings: SettingsStore) -> some View {
        if settings.experimentalToolbarUI {
            toolbarShell(settings: settings)
        } else {
            classicShell(settings: settings)
        }
    }

    private func toolbarShell(settings: SettingsStore) -> some View {
        GeometryReader { _ in
            ZStack {
                DesignContentBackgroundLayer(material: settings.windowMaterial.nsMaterial)
                toolbarContent
            }
        }
        // Right-click the empty background for the page's overflow actions (cards/rows keep their own
        // context menus, which take precedence). Double-click it to zoom the window — the gesture the
        // title bar used to provide.
        .contextMenu { backgroundMenu() }
        // NOTE: double-click-to-zoom is NOT here — on the shell it would sit above the cards, delay
        // their taps, and fire when double-clicking a card. Pages attach it to a background layer
        // behind their content via `.zoomWindowOnBackgroundDoubleClick()` instead.
    }

    private func classicShell(settings: SettingsStore) -> some View {
        ZStack {
            DesignContentBackgroundLayer(material: settings.windowMaterial.nsMaterial)
            content
                .ignoresSafeArea(.container, edges: .vertical)
        }
        .environment(\.morphSafeAreas, MorphSafeAreaManager(system: EdgeInsets()))
        .contextMenu { backgroundMenu() }
    }

    private var downgradeBinding: Binding<Bool> {
        Binding(get: { app.downgradeSchemaVersion != nil },
                set: { if !$0 { app.downgradeSchemaVersion = nil } })
    }

    private var whatsNewBinding: Binding<Bool> {
        Binding(get: { app.updater.showWhatsNew },
                set: { if !$0 { app.updater.markWhatsNewSeen() } })
    }

    /// The page-overflow menu, shown by right-clicking the background.
    @ViewBuilder
    private func backgroundMenu() -> some View {
        @Bindable var ui = ui
        @Bindable var settings = app.settings
        Button { app.coordinator.wake() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        Divider()
        Toggle(isOn: $ui.runningOnly) { Label("Show Running Only", systemImage: "play.circle") }
        Picker(selection: $settings.density) {
            ForEach(CardDensity.allCases) { Text($0.localizedDisplayName).tag($0) }
        } label: { Label("Card Size", systemImage: "square.grid.2x2") }
        Divider()
        Button { openSectionOrMorph(.images, morph: .updates) } label: { Label("Images", systemImage: "square.stack.3d.up") }
        Button { openSectionOrMorph(.templates, morph: .templates) } label: { Label("Templates", systemImage: "bookmark") }
        Button { openSectionOrMorph(.system, morph: .system) } label: { Label("System", systemImage: "gearshape.2") }
        Button { openSectionOrMorph(.activity, morph: .activity) } label: { Label("Activity", systemImage: "bell") }
        if settings.commandPaletteEnabled {
            Divider()
            Button { openPaletteOrContainers() } label: { Label("Command Palette…", systemImage: "command") }
        }
    }

    private func openPaletteOrContainers() {
        if app.settings.usesPanelNavigation {
            ui.toggleMorph(.palette)
        } else {
            ui.navigate(to: .containers)
        }
    }

    private func updateContainerStatsVisibility() {
        app.setContainerStatsVisible(ui.selectedSection == .containers && ui.activeMorph == nil)
    }

    private func openSectionOrMorph(_ section: AppSection, morph: UIState.ToolbarMorph) {
        if app.settings.usesPanelNavigation {
            ui.toggleMorph(morph)
        } else {
            ui.navigate(to: section)
        }
    }

    /// Force (or release, for `.system`) the app-wide AppKit appearance. Setting `NSApplication.appearance`
    /// directly — rather than relying only on `.preferredColorScheme` — makes "System" re-sync to the
    /// live OS theme even after the app was pinned to Light/Dark.
    private func applyAppearance(_ mode: AppearanceMode) {
        NSApplication.shared.appearance = mode.nsAppearance
    }

    /// Pick an image `.tar` and load it into the local store.
    private func loadImageTar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "tar") ?? .data]
        panel.message = AppText.chooseImageTarArchive
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
            DesignStatusBanner(banner)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.bootstrap {
        case .ready:
            if app.settings.experimentalToolbarUI {
                toolbarContent
            } else {
                ClassicShell(sidebarNavigationEnabled: app.settings.sidebarNavigationEnabled)
            }
        default: BootstrapView()
        }
    }

    @ViewBuilder
    private var toolbarContent: some View {
        ClassicShell(sidebarNavigationEnabled: app.settings.sidebarNavigationEnabled)
    }

}
