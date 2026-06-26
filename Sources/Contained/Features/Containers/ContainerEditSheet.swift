import SwiftUI
import SwiftData
import ContainedCore

/// The single container Create/Edit form: the shared `RunSpecForm` plus a live "Reveal CLI" preview.
/// Mode `.new` creates a container ("Create"); mode `.edit` prefills from an existing one and, on
/// "Save", tears it down and re-runs the edited spec in its place (container config is immutable, so
/// editing means delete + re-run). Replaces the old separate Create and Recreate sheets.
struct ContainerEditSheet: View {
    enum Mode {
        case new(prefill: RunSpec?)
        case edit(ContainerSnapshot, onComplete: () -> Void)
    }

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let mode: Mode

    @State private var spec: RunSpec
    @State private var working = false
    @State private var confirming = false
    @State private var loaded = false
    @State private var savingTemplate = false
    @State private var templateName = ""

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .new(let prefill):
            _spec = State(initialValue: prefill ?? RunSpec())
        case .edit(let snapshot, _):
            _spec = State(initialValue: RunSpec(from: snapshot.configuration))
        }
    }

    private var isEdit: Bool { if case .edit = mode { return true }; return false }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isEdit ? "Edit container" : "Run a container",
                        subtitle: isEdit ? "Replaces the existing container with your edits" : nil,
                        onCancel: { dismiss() }) {
                if working {
                    ProgressView().controlSize(.small)
                        .frame(width: Tokens.IconSize.control, height: Tokens.IconSize.control)
                } else {
                    GlassCircleButton(systemName: "bookmark", help: "Save as template") {
                        templateName = spec.name.isEmpty ? Format.shortImage(spec.image) : spec.name
                        savingTemplate = true
                    }
                    .disabled(!spec.isRunnable)
                    GlassCircleButton(systemName: isEdit ? "checkmark" : "play.fill",
                                      prominent: true, help: isEdit ? "Save" : "Create") {
                        if isEdit { confirming = true } else { create() }
                    }
                    .disabled(!spec.isRunnable)
                }
            }

            RunSpecForm(spec: $spec)

            if app.settings.revealCLI {
                CommandPreviewBar(command: spec.arguments())
                    .padding(Tokens.Space.l)
            }
        }
        .frame(Tokens.SheetSize.form)
        .sheetMaterial()
        .onAppear(perform: load)
        .confirmationDialog("Save changes to \(spec.name.isEmpty ? editID : spec.name)?",
                            isPresented: $confirming) {
            Button("Delete & recreate", role: .destructive) { save() }
        } message: {
            Text("This deletes the current container and runs a new one with your changes. Data not on a volume is lost.")
        }
        .alert("Save as template", isPresented: $savingTemplate) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveTemplate() }
        } message: {
            Text("Save these settings as a reusable template.")
        }
    }

    private func saveTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(Template(name: name, spec: spec))
        try? modelContext.save()
        app.flash("Saved template “\(name)”")
    }

    /// The id of the container being edited (empty in `.new` mode).
    private var editID: String {
        if case .edit(let snapshot, _) = mode { return snapshot.id }
        return ""
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .new:
            break   // spec was prefilled at init
        case .edit(let snapshot, _):
            // Pull the current style + healthcheck from the local stores so edits start from what's set.
            spec.personalization = app.personalization.resolved(id: snapshot.id, image: snapshot.image)
            spec.healthCheck = app.healthChecks.check(for: snapshot.id) ?? HealthCheck()
        }
    }

    private func create() {
        // Dismiss right away and let AppModel run the (possibly image-pulling) create in the
        // background, surfacing progress in the floating bar. This fixes the old flow where a
        // not-yet-pulled image made "Create" appear to do nothing until the image arrived.
        app.beginCreate(spec)
        dismiss()
    }

    private func save() {
        guard case .edit(let snapshot, let onComplete) = mode else { return }
        working = true
        Task {
            let ok = await app.containers.recreate(originalID: snapshot.id, spec: spec)
            if ok {
                let newID = spec.name.isEmpty ? snapshot.id : spec.name
                if newID != snapshot.id {
                    app.personalization.clearOverride(id: snapshot.id)
                    app.healthChecks.clear(id: snapshot.id)
                }
                if spec.personalization.isDefault {
                    app.personalization.clearOverride(id: newID)
                } else {
                    app.personalization.setOverride(spec.personalization, for: newID)
                }
                app.healthChecks.setCheck(spec.healthCheck, for: newID)
                working = false
                onComplete()
                dismiss()
            } else {
                working = false
            }
        }
    }
}
