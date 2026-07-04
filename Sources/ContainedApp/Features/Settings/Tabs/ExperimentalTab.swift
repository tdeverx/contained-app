import SwiftUI
import ContainedUI
import ContainedCore

// MARK: - Experimental

/// Opt-in gates for features that aren't fully baked yet. Everything here defaults **off** so a fresh
/// install ships the stable core; flipping a switch reveals the corresponding surface app-wide (menu
/// commands, toolbar affordances, creation options). See `SettingsStore`'s "Experimental features".
struct ExperimentalTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        SettingsForm {
            Section {
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.toolbarFirstUI", defaultValue: "Toolbar-first UI"),
                                  info: AppText.string("settings.experimental.toolbarFirstUI.info", defaultValue: "Show the floating app toolbar. Navigation and edit/create presentation are controlled separately below."),
                                  isChanged: settings.experimentalToolbarUI != false,
                                  isOn: $settings.experimentalToolbarUI)
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.toolbarPanelNavigation", defaultValue: "Toolbar panel navigation"),
                                  info: AppText.string("settings.experimental.toolbarPanelNavigation.info", defaultValue: "Open create/edit flows and page utilities in toolbar morph panels. When off, access points use classic pages and sheets."),
                                  isChanged: settings.experimentalPanelNavigation != false,
                                  isOn: $settings.experimentalPanelNavigation)
                    .disabled(!settings.experimentalToolbarUI)
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.sidebarNavigation", defaultValue: "Sidebar navigation"),
                                  info: AppText.string("settings.experimental.sidebarNavigation.info", defaultValue: "Keep the sidebar visible in either shell. Turn this off for a page-only layout."),
                                  isChanged: settings.sidebarNavigationEnabled != true,
                                  isOn: $settings.sidebarNavigationEnabled)
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.commandPalette", defaultValue: "Command palette (Command-K)"),
                                  info: AppText.string("settings.experimental.commandPalette.info", defaultValue: "The Command-K command index: fuzzy search across every app, container, image, and resource action. Page search and menu commands work regardless of this setting."),
                                  isChanged: settings.commandPaletteEnabled != false,
                                  isOn: $settings.commandPaletteEnabled)
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.dockerHubSearch", defaultValue: "Docker Hub search"),
                                  info: AppText.string("settings.experimental.dockerHubSearch.info", defaultValue: "Search registry images inline (creation Search path and the palette's Hub scope). Requires network access to the registry."),
                                  isChanged: settings.hubSearchEnabled != false,
                                  isOn: $settings.hubSearchEnabled)
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.composeImport", defaultValue: "Compose import"),
                                  info: AppText.string("settings.experimental.composeImport.info", defaultValue: "Import Docker Compose YAML - paste, file pick, or drag-and-drop - mapping each service with an image into a prefilled run."),
                                  isChanged: settings.composeImportEnabled != false,
                                  isOn: $settings.composeImportEnabled)
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.imageBuildWorkspace", defaultValue: "Image build workspace"),
                                  info: AppText.string("settings.experimental.imageBuildWorkspace.info", defaultValue: "Build an image from a Dockerfile + build context, streaming the BuildKit log."),
                                  isChanged: settings.imageBuildEnabled != false,
                                  isOn: $settings.imageBuildEnabled)
                UI.Form.ToggleRow(title: AppText.string("settings.experimental.keyboardShortcuts", defaultValue: "Keyboard shortcuts"),
                                  info: AppText.string("settings.experimental.keyboardShortcuts.info", defaultValue: "Enable menu and command keyboard shortcuts. Off by default so the experimental surface stays opt-in."),
                                  isChanged: settings.keyboardShortcutsEnabled != false,
                                  isOn: $settings.keyboardShortcutsEnabled)
            } header: {
                Text(AppText.sectionSettingsExperimental)
            } footer: {
                Text(AppText.string("settings.experimental.footer", defaultValue: "These features are still being refined. They're off by default; enable any you want to try. You can turn them back off at any time."))
            }
        }
    }
}
