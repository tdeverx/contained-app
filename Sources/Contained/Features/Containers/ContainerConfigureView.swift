import SwiftUI
import SwiftData
import ContainedCore

/// The container create/edit form body — shared by `ContainerEditSheet` (a modal sheet) and the paged
/// `CreationFlow` (hosted in the toolbar's morph panel). Owns the spec, validation, pre-flight
/// warnings, create/recreate, and save-as-template. The host supplies a leading control (cancel for a
/// sheet, back for a page) and is told when to close via `onFinished` (success) — the form never
/// dismisses itself.
struct ContainerConfigureView: View {
    /// The leading header control: a sheet shows cancel (✕), a page shows back (‹).
    enum Leading {
        case cancel(() -> Void)
        case back(() -> Void)
    }

    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext

    let mode: ContainerEditSheet.Mode
    let leading: Leading
    var onFinished: () -> Void

    @State private var spec: RunSpec
    @State private var working = false
    @State private var confirming = false
    @State private var loaded = false
    @State private var savingTemplate = false
    @State private var templateName = ""

    init(mode: ContainerEditSheet.Mode, leading: Leading, onFinished: @escaping () -> Void) {
        self.mode = mode
        self.leading = leading
        self.onFinished = onFinished
        switch mode {
        case .new(let prefill):      _spec = State(initialValue: prefill ?? RunSpec())
        case .edit(let snapshot, _): _spec = State(initialValue: RunSpec(from: snapshot.configuration))
        }
    }

    private var isEdit: Bool { if case .edit = mode { return true }; return false }

    var body: some View {
        VStack(spacing: 0) {
            header
            validationSummary
            RunSpecForm(spec: $spec)
            if app.settings.revealCLI {
                CommandPreviewBar(command: spec.arguments())
                    .padding(Tokens.Space.l)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: load)
        .confirmationDialog("Replace \(spec.name.isEmpty ? editID : spec.name)?",
                            isPresented: $confirming) {
            Button("Delete current container and run replacement", role: .destructive) { save() }
        } message: {
            Text("Contained will stop and delete the current container, then run a replacement from the command preview. Local style and health settings are reapplied. Data not stored in volumes is lost.")
        }
        .alert("Save as template", isPresented: $savingTemplate) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveTemplate() }
        } message: {
            Text("Save these settings as a reusable template.")
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.s) {
            switch leading {
            case .cancel(let action):
                GlassCircleButton(systemName: "xmark", help: "Cancel", isCancel: true, action: action)
            case .back(let action):
                GlassCircleButton(systemName: "chevron.left", help: "Back", action: action)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(isEdit ? "Edit container" : "Run a container").font(.headline)
                if isEdit {
                    Text("Replaces the existing container with your edits")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
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
        .padding(Tokens.Space.l)
    }

    @ViewBuilder
    private var validationSummary: some View {
        let messages = spec.validationMessages
        let warnings = preflightWarnings
        if !messages.isEmpty || !warnings.isEmpty || runError != nil {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                // Blocking issues (gate the run button) in secondary; pre-flight warnings in orange;
                // the run/pull failure in red.
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if let runError {
                    Label(runError, systemImage: "xmark.octagon")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Space.l)
            .padding(.bottom, Tokens.Space.s)
        }
    }

    /// The inline failure to show: the create/pull error (new mode) or the recreate error (edit mode).
    private var runError: String? {
        isEdit ? app.containers.errorMessage : app.createError
    }

    /// Cheap, app-state-aware checks that warn (but don't block) before running. Only for new
    /// containers — an edit replaces the original in place, so a name "collision" with itself is fine.
    private var preflightWarnings: [String] {
        guard !isEdit else { return [] }
        var out: [String] = []
        let name = spec.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty,
           app.containers.snapshots.contains(where: { $0.id == name || $0.displayName == name }) {
            out.append("A container named “\(name)” already exists — creating this will fail unless you rename it.")
        }
        // Two ports mapping the same host port within this spec.
        let hostPorts = spec.ports.map(\.hostPort).filter { !$0.isEmpty }
        if Set(hostPorts).count != hostPorts.count {
            out.append("Two port mappings share the same host port.")
        }
        return out
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
        // Stay open while the (possibly image-pulling) create runs, so a failure can be shown inline
        // without losing the user's spec. The header swaps to a spinner via `working`; progress for a
        // pull still shows in the floating bar. Only close on success.
        working = true
        app.createError = nil
        Task {
            let newID = await app.createContainer(spec)
            working = false
            if newID != nil {
                ui.section = .containers
                onFinished()
            }
            // else: stay open — `app.createError` drives the inline error.
        }
    }

    private func save() {
        guard case .edit(let snapshot, let onComplete) = mode else { return }
        working = true
        Task {
            let newID = await app.recreateContainer(originalID: snapshot.id, spec: spec)
            working = false
            if newID != nil {
                onComplete()
                onFinished()
            }
        }
    }
}
