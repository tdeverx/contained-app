import SwiftUI
import ContainedCore

// MARK: - Experimental

/// Opt-in gates for features that aren't fully baked yet. Everything here defaults **off** so a fresh
/// install ships the stable core; flipping a switch reveals the corresponding surface app-wide (menu
/// commands, toolbar affordances, creation options). See `SettingsStore`'s "Experimental features".
struct ExperimentalTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            PanelSection(header: "Experimental",
                         footer: "These features are still being refined. They're off by default; enable any you want to try. You can turn them back off at any time.") {
                PanelToggleRow(title: "Toolbar-first UI",
                               info: "Use the floating morph toolbar instead of the default sidebar and menu navigation.",
                               isOn: $settings.experimentalToolbarUI)
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
            }
        }
    }
}
