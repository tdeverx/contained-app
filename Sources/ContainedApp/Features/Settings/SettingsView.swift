import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import AppKit
import ContainedCore

/// App preferences. Six sections, each built from the same `PanelSection` glass-card model so spacing,
/// headers, and explanatory footers stay consistent: Appearance (theme + glass), General (behavior,
/// data, CLI), Runtime, Registries, Updates, and About.
///
/// Hosted in the toolbar Settings morph panel via the shared `DesignPanelScaffold`, so the panel hugs
/// the active section's content height. Sections switch via a header menu rather than a `TabView`.
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
        DesignPanelScaffold(width: DesignTokens.PanelSize.settings.width, placement: .centered) {
            if showsHeader {
                VStack(spacing: 0) {
                    header
                    Divider()
                }
            }
        } content: {
            sectionBody(settings: settings)
                .padding(DesignTokens.Space.s)
        }
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
        PanelHeader(symbol: page.systemImage,
                    title: "Settings",
                    subtitle: page.rawValue) {
            DesignActionGroup(headerActions)
        }
    }

    private var headerActions: [DesignAction] {
        var actions = SettingsPage.allCases.map { item in
            DesignAction(systemName: item.systemImage,
                         help: item.rawValue,
                         tint: page == item ? .accentColor : nil) {
                page = item
            }
        }
        if let onClose {
            actions.append(DesignAction(systemName: "xmark", help: AppText.close, isCancel: true, action: onClose))
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
