import SwiftUI
import ContainedUX
import UniformTypeIdentifiers
import ContainedCore
import ContainedUI

/// The main scene root. Primary resource pages share one permanent toolbar shell; utility routes and
/// create/edit flows are presented through its morph panels.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Image load/prune are global actions because they can be invoked from pages, toolbar panels,
    /// menus, and the command palette.
    @State private var pruningImages = false
    @State private var importingImageArchive = false
    @State private var importingComposeFile = false
    @State private var exportingDowngradeBackup = false
    @State private var downgradeBackupDocument: DataFileDocument?
    /// System logs are reachable from menus, panels, and the command palette.
    @State private var showSystemLogs = false

    var body: some View {
        @Bindable var settings = app.settings
        @Bindable var ui = ui
        rootShell(settings: settings)
        .sheet(isPresented: downgradeBinding) {
            DowngradeDecisionView(schemaVersion: app.downgradeSchemaVersion ?? StateMigrator.currentSchemaVersion,
                                  onExportAndReset: prepareDowngradeBackupExport,
                                  onKeep: { app.resolveDowngradeByKeepingReadableData() },
                                  onQuit: { Platform.quit() })
        }
        .sheet(isPresented: whatsNewBinding) {
            ReleaseNotesView(title: AppText.string("releaseNotes.whatsNew", defaultValue: "What's New"),
                             html: app.updater.currentReleaseNotesHTML,
                             onClose: { app.updater.markWhatsNewSeen() })
        }
        .sheet(item: runtimeSelectionBinding) { request in
            RuntimeSelectionSheet(request: request)
        }
        // Dispatch global actions from toolbar panels, pages, menus, and the command palette. Registry
        // credentials always live in Settings.
        .onChange(of: ui.pendingAction) { _, action in
            switch action {
            case .loadImage:     ui.pendingAction = nil; loadImageTar()
            case .importCompose: ui.pendingAction = nil; importingComposeFile = true
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
                case "tar":
                    loadImageTar(at: url)
                    return true
                default:            continue
                }
            }
            return false
        }
        .modifier(RootFileDialogs(importingImageArchive: $importingImageArchive,
                                  importingComposeFile: $importingComposeFile,
                                  exportingDowngradeBackup: $exportingDowngradeBackup,
                                  downgradeBackupDocument: $downgradeBackupDocument,
                                  onImageArchive: handleImportedImageArchive,
                                  onComposeFile: handleImportedComposeFile,
                                  onDowngradeBackupExport: handleDowngradeBackupExport))
        // Long-running operations (image pulls, etc.) now surface in the bottom-left status capsule
        // (see `AppToolbar` → `UI.State.ActivityStatusIndicator`); only transient banners float at the bottom.
        .overlay(alignment: .bottom) {
            bannerView
                .padding(.bottom, UI.Layout.Spacing.l)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.banner)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: app.activity)
        .tint(settings.accentTint.resolvedAppAccentColor)
        .accentColor(settings.accentTint.resolvedAppAccentColor)
        .environment(\.designSystemAccentColor, settings.accentTint.resolvedAppAccentColor)
        .environment(\.modalMaterial, settings.modalMaterial)
        .environment(\.buttonMaterial, settings.buttonMaterial)
        .environment(\.buttonTintStyle, UI.Theme.ButtonTintStyle(enabled: settings.buttonTintEnabled,
                                                             tint: settings.buttonTint,
                                                             opacity: settings.buttonTintOpacity,
                                                             gradient: settings.buttonTintGradient,
                                                             gradientAngle: settings.buttonTintGradientAngle,
                                                             blendMode: settings.buttonTintBlendMode))
        .environment(\.cardMaterial, settings.cardMaterial)
        .environment(\.designSystemShowsInfoTips, settings.showInfoTips)
        .environment(\.pageScaffoldUsesToolbarChrome, true)
        .environment(\.pageScaffoldBottomClearance, AppToolbar.bandHeight)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onAppear {
            updateContainerStatsVisibility()
        }
        .onChange(of: ui.selectedSection) { _, _ in updateContainerStatsVisibility() }
        .onChange(of: ui.toolbar.activeMorph) { _, _ in updateContainerStatsVisibility() }
        .task {
            await app.bootstrapIfNeeded()
            app.coordinator.start(app: app)
            app.historySamplingCoordinator.start(app: app)
        }
        .onChange(of: scenePhase) { _, phase in
            app.coordinator.isActive = (phase == .active)
            updateContainerStatsVisibility()
        }
    }

    private func rootShell(settings: SettingsStore) -> some View {
        GeometryReader { _ in
            ZStack {
                UI.Theme.BackgroundLayer(material: settings.windowMaterial)
                content
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

    private var downgradeBinding: Binding<Bool> {
        Binding(get: { app.downgradeSchemaVersion != nil },
                set: { if !$0 { app.downgradeSchemaVersion = nil } })
    }

    private var whatsNewBinding: Binding<Bool> {
        Binding(get: { app.updater.showWhatsNew },
                set: { if !$0 { app.updater.markWhatsNewSeen() } })
    }

    private var runtimeSelectionBinding: Binding<UIState.RuntimeSelectionRequest?> {
        Binding(get: { ui.runtimeSelectionRequest },
                set: { ui.runtimeSelectionRequest = $0 })
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
            ForEach(UI.Card.Density.allCases) { Text($0.localizedDisplayName).tag($0) }
        } label: { Label("Card Size", systemImage: "square.grid.2x2") }
        Divider()
        Button { ui.navigate(to: .images) } label: { Label("Images", systemImage: "square.stack.3d.up") }
        Button { ui.toggleMorph(.templates) } label: { Label("Templates", systemImage: "bookmark") }
        Button { ui.toggleMorph(.system) } label: { Label("System", systemImage: "gearshape.2") }
        Button { ui.toggleMorph(.activity) } label: { Label("Activity", systemImage: "bell") }
        if settings.commandPaletteEnabled {
            Divider()
            Button { openPaletteOrContainers() } label: { Label("Command Palette…", systemImage: "command") }
        }
    }

    private func openPaletteOrContainers() {
        ui.toggleMorph(.palette)
    }

    private func updateContainerStatsVisibility() {
        app.setContainerStatsVisible(scenePhase == .active
                                     && ui.selectedSection == .containers
                                     && ui.toolbar.activeMorph == nil)
    }

    /// Pick an image `.tar` and load it into the local store.
    private func loadImageTar() {
        importingImageArchive = true
    }

    private func handleImportedImageArchive(_ result: Result<URL, Error>) {
        guard let url = importedURL(from: result) else { return }
        loadImageTar(at: url)
    }

    private func handleImportedComposeFile(_ result: Result<URL, Error>) {
        guard let url = importedURL(from: result) else { return }
        ComposeImport.importFile(at: url, app: app, ui: ui)
    }

    private func loadImageTar(at url: URL) {
        let descriptors = app.availableRuntimeDescriptors.filter { $0.supports(.imageArchive) }
        guard let first = descriptors.first else {
            app.flash(AppText.containerRuntimeNotReady)
            return
        }
        guard descriptors.count > 1 else {
            app.loadImageTar(at: url, runtimeKind: first.kind)
            return
        }
        ui.runtimeSelectionRequest = .imageArchive(url)
    }

    private func pruneImages(all: Bool) async {
        guard let client = app.client else { return }
        if let error = await app.captured({
            for descriptor in app.availableRuntimeDescriptors where descriptor.supports(.images) {
                _ = try await client.pruneImages(all: all, runtimeKind: descriptor.kind)
            }
        }) { app.flash(error) }
        await app.refreshImagesIfNeeded(force: true)
    }

    /// Toggle the front window between its zoomed (filled) and restored size — emulates the
    /// title-bar double-click now that there's no title bar to double-click.
    private func zoomFrontWindow() {
        Platform.zoomFrontWindow()
    }

    private func importedURL(from result: Result<URL, Error>) -> URL? {
        switch result {
        case .success(let url):
            return url
        case .failure(let error):
            app.flash(error.appDisplayMessage)
            return nil
        }
    }

    private func prepareDowngradeBackupExport() {
        do {
            downgradeBackupDocument = DataFileDocument(data: try app.configurationData())
            exportingDowngradeBackup = true
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }

    private func handleDowngradeBackupExport(_ result: Result<URL, Error>) {
        defer { downgradeBackupDocument = nil }
        switch result {
        case .success:
            app.resetIncompatibleLocalState()
            app.downgradeSchemaVersion = nil
            app.flash(AppText.exportedBackupAndReset)
        case .failure(let error):
            app.flash(error.appDisplayMessage)
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = app.banner {
            UI.State.Banner(banner)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.bootstrap {
        case .ready:
            AppShell()
        default: BootstrapView()
        }
    }

}

private struct RootFileDialogs: ViewModifier {
    @Binding var importingImageArchive: Bool
    @Binding var importingComposeFile: Bool
    @Binding var exportingDowngradeBackup: Bool
    @Binding var downgradeBackupDocument: DataFileDocument?
    var onImageArchive: (Result<URL, Error>) -> Void
    var onComposeFile: (Result<URL, Error>) -> Void
    var onDowngradeBackupExport: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $importingImageArchive,
                          allowedContentTypes: UTType.imageArchives,
                          onCompletion: onImageArchive)
            .fileImporter(isPresented: $importingComposeFile,
                          allowedContentTypes: UTType.composeDocuments,
                          onCompletion: onComposeFile)
            .fileExporter(isPresented: $exportingDowngradeBackup,
                          document: downgradeBackupDocument,
                          contentTypes: UTType.containedBackupDocuments,
                          defaultFilename: "Contained Downgrade Backup.containedbackup",
                          onCompletion: onDowngradeBackupExport)
    }
}
