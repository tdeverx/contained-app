import AppKit
import ContainedCore

/// Import a `compose.yaml` without a dedicated page: pick the file, translate each service with an
/// image into a `RunSpec`, pull the images, then open a prefilled New-Container window per service
/// (the prefill queue steps through them). Triggered from File ▸ Import Compose… and the palette.
@MainActor
enum ComposeImport {
    /// Show an open panel, then import the chosen file.
    static func pickAndImport(app: AppModel, ui: UIState) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.yaml]
        panel.message = "Choose a compose.yaml"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(at: url, app: app, ui: ui)
    }

    /// Parse a compose file and feed its services into the prefill queue (also used by drag-and-drop).
    static func importFile(at url: URL, app: AppModel, ui: UIState) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let projectName = url.deletingLastPathComponent().lastPathComponent
            let parsed = try ComposeParser.parse(text, projectName: projectName.isEmpty ? "stack" : projectName)
            let baseDirectory = url.deletingLastPathComponent()
            var specs: [RunSpec] = []
            for service in parsed.services where service.image != nil {
                var spec = RunSpec(service: service, projectName: parsed.name)
                spec.volumes = spec.volumes.map { resolveRelativeVolume($0, baseDirectory: baseDirectory) }
                specs.append(spec)
            }
            guard !specs.isEmpty else {
                app.flash("No services with an image to import.")
                return
            }
            if !parsed.warnings.isEmpty {
                app.flash("Some compose keys weren't translated — review each container before creating.")
            }
            ui.beginPrefillQueue(specs, using: app)
        } catch let error as ComposeError {
            app.flash({ if case .invalid(let message) = error { return message }; return "Invalid compose file." }())
        } catch {
            app.flash(error.localizedDescription)
        }
    }

    /// Docker Compose resolves relative bind sources from the compose file's directory. The runtime
    /// receives `container run` from the app process, so make those sources absolute at import time.
    static func resolveRelativeVolume(_ volume: VolumeMap, baseDirectory: URL) -> VolumeMap {
        guard volume.source.hasPrefix("./") || volume.source.hasPrefix("../") else { return volume }
        var resolved = volume
        resolved.source = baseDirectory.appending(path: volume.source).standardizedFileURL.path
        return resolved
    }
}
