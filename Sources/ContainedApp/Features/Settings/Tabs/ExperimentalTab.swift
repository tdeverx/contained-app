import SwiftUI
import ContainedDesignSystem
import ContainedCore

// MARK: - Experimental

/// Opt-in gates for features that aren't fully baked yet. Everything here defaults **off** so a fresh
/// install ships the stable core; flipping a switch reveals the corresponding surface app-wide (menu
/// commands, toolbar affordances, creation options). See `SettingsStore`'s "Experimental features".
struct ExperimentalTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        LazyVStack(spacing: DesignTokens.Space.l) {
            PanelSection(header: "Experimental",
                         footer: "These features are still being refined. They're off by default; enable any you want to try. You can turn them back off at any time.") {
                PanelToggleRow(title: "Toolbar-first UI",
                               info: "Show the floating app toolbar. Navigation and edit/create presentation are controlled separately below.",
                               isOn: $settings.experimentalToolbarUI)
                PanelToggleRow(title: "Toolbar panel navigation",
                               info: "Open create/edit flows and page utilities in toolbar morph panels. When off, access points use classic pages and sheets.",
                               isOn: $settings.experimentalPanelNavigation)
                    .disabled(!settings.experimentalToolbarUI)
                PanelToggleRow(title: "Sidebar navigation",
                               info: "Keep the sidebar visible in either shell. Turn this off for a page-only layout.",
                               isOn: $settings.sidebarNavigationEnabled)
                PanelToggleRow(title: "Command palette (⌘K)",
                               info: "The ⌘K command index: fuzzy search across every app, container, image, and resource action. Page search and menu commands work regardless of this setting.",
                               isOn: $settings.commandPaletteEnabled)
                PanelToggleRow(title: "Docker Hub search",
                               info: "Search registry images inline (creation “Search” path and the palette’s Hub scope). Requires network access to the registry.",
                               isOn: $settings.hubSearchEnabled)
                PanelToggleRow(title: "Compose import",
                               info: "Import Docker Compose YAML — paste, file pick, or drag-and-drop — mapping each service with an image into a prefilled run.",
                               isOn: $settings.composeImportEnabled)
                PanelToggleRow(title: "Image build workspace",
                               info: "Build an image from a Dockerfile + build context, streaming the BuildKit log.",
                               isOn: $settings.imageBuildEnabled)
                PanelToggleRow(title: "Keyboard shortcuts",
                               info: "Enable menu and command keyboard shortcuts. Off by default so the experimental surface stays opt-in.",
                               isOn: $settings.keyboardShortcutsEnabled)
            }
        }
    }
}
