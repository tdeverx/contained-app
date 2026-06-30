import SwiftUI
import AppKit
import ContainedCore

/// App preferences. Six sections, each built from the same `PanelSection` glass-card model so spacing,
/// headers, and explanatory footers stay consistent: Appearance (theme + glass), General (behavior,
/// data, CLI), Runtime, Registries, Updates, and About.
///
/// Hosted in the toolbar Settings morph panel via the shared `MorphPanelScaffold`, so the panel hugs
/// the active section's content height. Sections switch via a header menu rather than a `TabView`.
struct SettingsContent: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @State private var page: SettingsPage = .appearance
    var onClose: (() -> Void)?

    enum SettingsPage: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case general = "General"
        case runtime = "Runtime"
        case registries = "Registries"
        case updates = "Updates"
        case about = "About"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .appearance: "paintpalette"
            case .general: "gearshape"
            case .runtime: "cpu"
            case .registries: "key"
            case .updates: "arrow.down.app"
            case .about: "info.circle"
            }
        }
    }

    var body: some View {
        @Bindable var settings = app.settings
        MorphPanelScaffold(width: Tokens.PanelSize.settings.width, placement: .centered) {
            VStack(spacing: 0) {
                header
                Divider()
            }
        } content: {
            sectionBody(settings: settings)
                .padding(Tokens.Space.s)
        }
        .onChange(of: ui.settingsPage) { _, requested in
            guard let requested else { return }
            page = requested
            ui.settingsPage = nil
        }
    }

    private var header: some View {
        PanelHeader(symbol: page.systemImage,
                    title: "Settings",
                    subtitle: page.rawValue) {
            GlassButton {
                ForEach(SettingsPage.allCases) { item in
                    GlassButtonItem(help: item.rawValue, isIcon: true, action: { page = item }) {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(Color.white)
                            .opacity(page == item ? 1 : 0.62)
                    }
                }
                if let onClose {
                    GlassButtonItem(systemName: "xmark", help: "Close", isCancel: true, action: onClose)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionBody(settings: SettingsStore) -> some View {
        switch page {
        case .appearance: AppearanceTab(settings: settings)
        case .general: GeneralTab(settings: settings)
        case .runtime: RuntimeTab()
        case .registries: RegistriesTab()
        case .updates: UpdatesTab()
        case .about: AboutTab()
        }
    }
}
