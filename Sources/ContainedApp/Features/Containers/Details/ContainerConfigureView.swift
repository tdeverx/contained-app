import SwiftUI
import ContainedUX
import ContainedUI
import ContainedCore

/// The container create/edit form body hosted by the toolbar creation flow. Owns the spec,
/// validation, pre-flight warnings, create/recreate, and save-as-template.
struct ContainerConfigureView: View {
    enum Mode {
        case new(prefill: ContainerFormState?)
        case edit(Core.Container.Snapshot, onComplete: () -> Void)
    }

    /// The leading header control: a sheet shows cancel (✕), a page shows back (‹).
    enum Leading {
        case cancel(() -> Void)
        case back(() -> Void)
    }

    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui

    let mode: Mode
    let leading: Leading
    var onFinished: () -> Void

    @State private var spec: ContainerFormState
    @State private var working = false
    @State private var confirming = false
    @State private var loaded = false
    @State private var savingTemplate = false
    @State private var templateName = ""
    @State private var page: ContainerFormPage = .basics

    init(mode: Mode, leading: Leading, onFinished: @escaping () -> Void) {
        self.mode = mode
        self.leading = leading
        self.onFinished = onFinished
        switch mode {
        case .new(let prefill):      _spec = State(initialValue: prefill ?? ContainerFormState(runtimeKind: AppRuntimeIntent.placeholderKind))
        case .edit(let snapshot, _): _spec = State(initialValue: ContainerFormState(from: snapshot.configuration))
        }
    }

    private var isEdit: Bool { if case .edit = mode { return true }; return false }

    var body: some View {
        UI.Panel.Scaffold(width: UI.Panel.SheetSize.form.width, scrolls: false) {
            VStack(spacing: 0) {
                header
                Divider()
                validationSummary
            }
        } content: {
            ContainerSchemaForm(spec: $spec, page: page)
        } footer: {
            commandFooter
        }
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
        UI.Panel.Header(symbol: isEdit ? "slider.horizontal.3" : "play.fill",
                    title: isEdit ? "Edit container" : "Run a container",
                    subtitle: page.subtitle) {
            HStack(spacing: UI.Layout.Spacing.s) {
                UI.Action.Group(pageActions)
                UI.Action.Group(utilityActions)
            }
        }
    }

    private var pageActions: [UI.Action.Item] {
        ContainerFormPage.allCases.map { item in
            UI.Action.Item(systemName: item.systemImage,
                           help: item.title,
                           tint: page == item ? .accentColor : nil) {
                page = item
            }
        }
    }

    private var utilityActions: [UI.Action.Item] {
        [
            UI.Action.Item(systemName: "bookmark",
                           help: AppText.saveAsTemplate,
                           isEnabled: spec.isRunnable && !working) {
                templateName = spec.name.isEmpty ? Format.shortImage(spec.image) : spec.name
                savingTemplate = true
            },
            leadingAction,
        ]
    }

    @ViewBuilder
    private var commandFooter: some View {
        if app.settings.revealCLI {
            UI.Command.PreviewBar(commandText: app.previewCreateCommandText(for: spec),
                                  copyHelp: AppText.copyCommand,
                                  copiedAccessibilityLabel: AppText.copied) {
                primaryCommandAction
            }
            .padding(UI.Layout.Spacing.s)
            .frame(maxWidth: .infinity)
        } else {
            HStack {
                Spacer()
                primaryCommandAction
            }
            .padding(UI.Layout.Spacing.s)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var primaryCommandAction: some View {
        if working {
            UI.Action.ProgressCapsule()
        } else {
            UI.Action.TextButton(title: isEdit ? AppText.string("common.save", defaultValue: "Save") : AppText.string("runSpec.run", defaultValue: "Run"),
                                 systemName: isEdit ? "checkmark" : "play.fill",
                                 help: isEdit ? AppText.string("runSpec.saveAndReplace", defaultValue: "Save and replace the container") : AppText.string("runSpec.runCommand", defaultValue: "Run this command"),
                                 prominence: .prominent,
                                 isEnabled: spec.isRunnable) {
                if isEdit { confirming = true } else { create() }
            }
            .opacity(spec.isRunnable ? 1 : 0.55)
        }
    }

    private var leadingAction: UI.Action.Item {
        switch leading {
        case .cancel(let action):
            return UI.Action.Item(systemName: "xmark", help: AppText.cancel, isCancel: true, action: action)
        case .back(let action):
            return UI.Action.Item(systemName: "chevron.left", help: AppText.back, action: action)
        }
    }

    @ViewBuilder
    private var validationSummary: some View {
        let messages = spec.validationMessages
        let warnings = preflightWarnings
        if !messages.isEmpty || !warnings.isEmpty || runError != nil {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.xs) {
                ForEach(messages, id: \.self) { message in
                    UI.State.InlineStatus(message,
                                       systemImage: "exclamationmark.circle")
                }
                ForEach(warnings, id: \.self) { warning in
                    UI.State.InlineStatus(warning,
                                       systemImage: "exclamationmark.triangle",
                                       tone: .warning)
                }
                if let runError {
                    UI.State.InlineStatus(runError,
                                       systemImage: "xmark.octagon",
                                       tone: .error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, UI.Layout.Spacing.l)
            .padding(.bottom, UI.Layout.Spacing.s)
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
           app.containers.snapshots.contains(where: { $0.runtimeKind == spec.effectiveRuntimeKind && ($0.id == name || $0.displayName == name) }) {
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
        do {
            app.historyStore.insertTemplate(try RecipeRecord.make(name: name, spec: spec))
            app.flash(AppText.savedTemplate(name))
        } catch {
            app.flash(error.appDisplayMessage)
        }
    }

    /// The id of the container being edited (empty in `.new` mode).
    private var editID: String {
        if case .edit(let snapshot, _) = mode { return snapshot.scopedID }
        return ""
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .new:
            if spec.effectiveRuntimeKind == AppRuntimeIntent.placeholderKind {
                spec.runtimeKind = app.preselectedRuntimeKind(current: spec.effectiveRuntimeKind, capability: .containers)
            }
        case .edit(let snapshot, _):
            // Pull the current style + healthcheck from the local stores so edits start from what's set.
            spec.personalization = app.containerStyle(for: snapshot)
            spec.healthCheck = app.healthChecks.check(for: snapshot.scopedID) ?? Core.Container.HealthCheck()
            spec.applyLinkedVolumePaths(app.database.linkedVolumePaths(for: snapshot.scopedID))
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
                onFinished()
            }
            // else: stay open — `app.createError` drives the inline error.
        }
    }

    private func save() {
        guard case .edit(let snapshot, let onComplete) = mode else { return }
        working = true
        Task {
            let newID = await app.recreateContainer(originalID: snapshot.scopedID, spec: spec)
            working = false
            if newID != nil {
                onComplete()
                onFinished()
            }
        }
    }
}
