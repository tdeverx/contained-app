import Foundation
import ContainedCore

/// Import a `compose.yaml` without a dedicated page: pick the file, translate each service with an
/// image into a `ContainerFormState`, pull the images, then open a prefilled New-Container editor per service
/// (the prefill queue steps through them). Triggered from File ▸ Import Compose…, drag-and-drop,
/// and the palette.
@MainActor
enum ComposeImport {
    /// Parse a compose file and feed its services into the prefill queue (also used by drag-and-drop).
    static func importFile(at url: URL,
                           runtimeKind: Core.Runtime.Kind? = nil,
                           app: AppModel,
                           ui: UIState) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let projectName = url.deletingLastPathComponent().lastPathComponent
            importText(text, projectName: projectName.isEmpty ? "stack" : projectName,
                       baseDirectory: url.deletingLastPathComponent(),
                       runtimeKind: runtimeKind,
                       app: app,
                       ui: ui)
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }

    /// Parse pasted compose text and feed its services into the prefill queue.
    static func importText(_ text: String, projectName: String = "pasted",
                           baseDirectory: URL? = nil,
                           runtimeKind: Core.Runtime.Kind? = nil,
                           app: AppModel,
                           ui: UIState) {
        do {
            let parsed = try Core.Compose.parse(text, projectName: projectName)
            guard let client = app.client else {
                app.flash(AppText.containerRuntimeNotReady)
                app.logger.record("Compose import could not start because no runtime is available",
                                  category: .compose,
                                  severity: .warning)
                return
            }
            let selectedRuntime: Core.Runtime.Kind
            if let runtimeKind {
                selectedRuntime = runtimeKind
            } else {
                let runtimes = app.availableRuntimeDescriptors.filter { $0.supports(.composeImport) }
                guard let first = runtimes.first else {
                    app.flash(AppText.containerRuntimeNotReady)
                    return
                }
                guard runtimes.count > 1 else {
                    return importText(text,
                                      projectName: projectName,
                                      baseDirectory: baseDirectory,
                                      runtimeKind: first.kind,
                                      app: app,
                                      ui: ui)
                }
                ui.runtimeSelectionRequest = .composeText(text: text,
                                                          projectName: projectName,
                                                          baseDirectory: baseDirectory)
                return
            }
            let plan = try client.translateCompose(parsed,
                                                   baseDirectory: baseDirectory,
                                                   runtimeKind: selectedRuntime)
            let specs = plan.items.map { ContainerFormState(document: $0.document, healthCheck: $0.healthCheck) }
            guard !specs.isEmpty else {
                app.flash(AppText.composeNoServicesWithImages)
                app.logger.record("Compose import had no services with images",
                                  category: .compose,
                                  severity: .warning)
                return
            }
            if !plan.warnings.isEmpty {
                app.flash(AppText.composeWarnings)
                app.logger.record("Compose import produced \(plan.warnings.count) warning\(plan.warnings.count == 1 ? "" : "s")",
                                  category: .compose,
                                  severity: .warning)
            }
            app.logger.record("Imported compose project with \(specs.count) service\(specs.count == 1 ? "" : "s")",
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
