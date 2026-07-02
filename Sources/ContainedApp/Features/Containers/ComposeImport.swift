import AppKit
import ContainedCore
import ContainedRuntime

/// Import a `compose.yaml` without a dedicated page: pick the file, translate each service with an
/// image into a `RunSpec`, pull the images, then open a prefilled New-Container editor per service
/// (the prefill queue steps through them). Triggered from File ▸ Import Compose…, drag-and-drop,
/// and the palette.
@MainActor
enum ComposeImport {
    /// Show an open panel, then import the chosen file.
    static func pickAndImport(app: AppModel, ui: UIState) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.yaml]
        panel.message = AppText.chooseComposeFile
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(at: url, app: app, ui: ui)
    }

    /// Parse a compose file and feed its services into the prefill queue (also used by drag-and-drop).
    static func importFile(at url: URL, app: AppModel, ui: UIState) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let projectName = url.deletingLastPathComponent().lastPathComponent
            importText(text, projectName: projectName.isEmpty ? "stack" : projectName,
                       baseDirectory: url.deletingLastPathComponent(), app: app, ui: ui)
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }

    /// Parse pasted compose text and feed its services into the prefill queue.
    static func importText(_ text: String, projectName: String = "pasted",
                           baseDirectory: URL? = nil, app: AppModel, ui: UIState) {
        do {
            let parsed = try ComposeParser.parse(text, projectName: projectName)
            guard let client = app.client else {
                app.flash(AppText.containerRuntimeNotReady)
                app.logger.record("Compose import \(parsed.name) could not start because no runtime is available",
                                  category: .compose,
                                  severity: .warning)
                return
            }
            let plan = try client.translateCompose(parsed, baseDirectory: baseDirectory)
            let specs = plan.items.map { RunSpec(request: $0.request, healthCheck: $0.healthCheck) }
            guard !specs.isEmpty else {
                app.flash(AppText.composeNoServicesWithImages)
                app.logger.record("Compose import \(parsed.name) had no services with images",
                                  category: .compose,
                                  severity: .warning)
                return
            }
            if !plan.warnings.isEmpty {
                app.flash(AppText.composeWarnings)
                app.logger.record("Compose import \(parsed.name) produced \(plan.warnings.count) warning\(plan.warnings.count == 1 ? "" : "s")",
                                  category: .compose,
                                  severity: .warning)
            }
            app.logger.record("Imported compose project \(parsed.name) with \(specs.count) service\(specs.count == 1 ? "" : "s")",
                              category: .compose)
            ui.beginPrefillQueue(specs, using: app)
        } catch {
            app.flash(error.appDisplayMessage)
            app.logger.recordFailure("Compose import failed",
                                     error: error,
                                     category: .compose,
                                     severity: .error)
        }
    }
}
