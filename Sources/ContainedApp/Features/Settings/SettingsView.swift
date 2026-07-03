import SwiftUI
import ContainedUX
import ContainedUI
import ContainedCore

/// App preferences. Six sections, each built from the same `UI.Panel.Section` glass-card model so spacing,
/// headers, and explanatory footers stay consistent: Appearance (theme + glass), General (behavior,
/// data, CLI), Runtime, Registries, Updates, and About.
///
/// Hosted in the toolbar Settings morph panel via the shared `UI.Panel.Scaffold`.
/// Sections switch via a header menu rather than a `TabView`.
struct SettingsContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var page: SettingsPage
    var onClose: (() -> Void)?

    enum SettingsPage: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case general = "General"
        case runtime = "Runtime"
        case registries = "Registries"
        case experimental = "Experimental"
        case updates = "Updates"
        case about = "About"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: AppText.sectionSettingsAppearance
            case .general: AppText.sectionSettingsGeneral
            case .runtime: AppText.sectionSettingsRuntime
            case .registries: AppText.sectionSettingsRegistries
            case .experimental: AppText.sectionSettingsExperimental
            case .updates: AppText.sectionSettingsUpdates
            case .about: AppText.sectionSettingsAbout
            }
        }

        var systemImage: String {
            switch self {
            case .appearance: "paintpalette"
            case .general: "gearshape"
            case .runtime: "cpu"
            case .registries: "key"
            case .experimental: "flask"
            case .updates: "arrow.down.app"
            case .about: "info.circle"
            }
        }
    }

    init(initialPage: SettingsPage = .appearance, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        _page = State(initialValue: initialPage)
    }

    private var showsHeader: Bool {
        onClose != nil || !ui.toolbarUIEnabled
    }

    var body: some View {
        @Bindable var settings = app.settings
        UI.Panel.Scaffold(width: UI.Panel.Size.settings.width) {
            if showsHeader {
                VStack(spacing: 0) {
                    header
                    Divider()
                }
            }
        } content: {
            sectionBody(settings: settings)
                .padding(UI.Layout.Spacing.s)
        }
        .morphPanelPlacement(.centered)
        .onAppear { consumeRequestedPage() }
        .onChange(of: ui.settingsPage) { _, requested in
            guard let requested else { return }
            consumeRequestedPage(requested)
        }
    }

    private func consumeRequestedPage(_ requested: SettingsPage? = nil) {
        guard let requested = requested ?? ui.settingsPage else { return }
        page = requested
        ui.settingsPage = nil
    }

    private var header: some View {
        UI.Panel.Header(symbol: page.systemImage,
                    title: AppText.sectionSettings,
                    subtitle: page.title) {
            UI.Action.Group(headerActions)
        }
    }

    private var headerActions: [UI.Action.Item] {
        var actions = SettingsPage.allCases.map { item in
            UI.Action.Item(systemName: item.systemImage,
                         help: item.title,
                         tint: page == item ? .accentColor : nil) {
                page = item
            }
        }
        if let onClose {
            actions.append(UI.Action.Item(systemName: "xmark", help: AppText.close, isCancel: true, action: onClose))
        }
        return actions
    }

    @ViewBuilder
    private func sectionBody(settings: SettingsStore) -> some View {
        switch page {
        case .appearance: AppearanceTab(settings: settings)
        case .general: GeneralTab(settings: settings)
        case .runtime: RuntimeTab()
        case .registries: RegistriesTab()
        case .experimental: ExperimentalTab(settings: settings)
        case .updates: UpdatesTab()
        case .about: AboutTab()
        }
    }
}
