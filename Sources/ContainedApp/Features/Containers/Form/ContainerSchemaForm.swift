import SwiftUI
import ContainedUX
import ContainedUI
import UniformTypeIdentifiers
import ContainedCore

/// The shared container Create/Edit form body: native grouped Form sections mapping the `run`
/// flags. Reused by `ContainerEditSheet` for both new and edit modes. Field guidance stays available
/// through tappable `info.circle` popovers that appear on row hover/focus.
struct ContainerSchemaForm: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Binding var spec: ContainerFormState
    let page: ContainerFormPage

    init(spec: Binding<ContainerFormState>, page: ContainerFormPage) {
        self._spec = spec
        self.page = page
    }

    var body: some View {
        UI.Form.Grouped {
            pageSections
        }
        .task(id: spec.normalizedImageReference) {
            guard !spec.image.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            await app.refreshImagesIfNeeded()
        }
    }

    @ViewBuilder
    private var pageSections: some View {
        switch page {
        case .basics:
            Section {
                generalSection
            } header: {
                formSectionHeader(AppText.string("runSpec.section.essentials", defaultValue: "Essentials"), highlighted: spec.hasGeneralOptions)
            }
            Section {
                resourcesSection
            } header: {
                formSectionHeader(AppText.string("runSpec.section.resources", defaultValue: "Resources"), highlighted: spec.hasResourceOptions)
            }
        case .network:
            Section {
                portsSection
                networkSection
                socketsSection
            } header: {
                formSectionHeader(AppText.string("runSpec.section.networking", defaultValue: "Networking"), highlighted: spec.hasNetworkingOptions)
            }
        case .storage:
            storageSections
        case .options:
            Section {
                environmentSection
            } header: {
                formSectionHeader(AppText.string("runSpec.section.environment", defaultValue: "Environment"), highlighted: spec.hasEnvironmentOptions)
            }
            Section {
                restartSection
                healthSection
            } header: {
                formSectionHeader(AppText.string("runSpec.section.appManaged", defaultValue: "App Managed"), highlighted: spec.hasAppManagedOptions)
            }
            Section {
                personalizationSection
            } header: {
                formSectionHeader(AppText.sectionSettingsAppearance, highlighted: spec.hasPersonalizationOptions)
            }
        case .advanced:
            advancedOptionsSection
            dockerComposeSection
        }
    }

    private func formSectionHeader(_ title: String, highlighted: Bool) -> some View {
        HStack(spacing: UI.Layout.Spacing.xs) {
            if highlighted {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
            }
            Text(title)
                .foregroundStyle(highlighted ? Color.blue : Color.secondary)
        }
    }

    private func storageGroupHeader(index: Int, group: StorageGroup, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: UI.Layout.Spacing.s) {
            formSectionHeader(storageGroupTitle(index: index, group: group), highlighted: storageGroupHasValues(group))
            Spacer()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(AppText.string("runSpec.removeStorageGroup", defaultValue: "Remove storage group"))
        }
    }

    private func storageGroupTitle(index: Int, group: StorageGroup) -> String {
        if group.usesRuntimeVolume {
            let name = group.volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return "\(AppText.string("runSpec.storageGroup", defaultValue: "Storage Group")) \(index + 1)"
    }

    private func storageGroupFooter(_ group: StorageGroup) -> some View {
        Text(group.usesRuntimeVolume
            ? AppText.string("runSpec.storageGroup.runtimeVolume.footer", defaultValue: "Contained mounts this runtime volume, then links each host folder inside it before the container starts.")
            : AppText.string("runSpec.storageGroup.bindMount.footer", defaultValue: "Each path is mounted directly from the host into the container."))
            .foregroundStyle(.secondary)
    }

    private func storageGroupHasValues(_ group: StorageGroup) -> Bool {
        group.usesRuntimeVolume ||
        !group.volumeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !group.volumeTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        group.paths.contains { path in
            !path.hostPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !path.internalPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func formRow<Trailing: View>(title: String,
                                         path: Core.Field.Path? = nil,
                                         subtitle: String? = nil,
                                         info: String? = nil,
                                         error: String? = nil,
                                         isChanged: Bool? = nil,
                                         @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        UI.Form.Row(title: title,
                    subtitle: subtitle,
                    info: info,
                    error: error ?? path.flatMap(fieldError),
                    isChanged: isChanged ?? path.map(fieldChanged) ?? false,
                    trailing: trailing)
    }

    private func formField<Control: View>(label: String,
                                          path: Core.Field.Path? = nil,
                                          info: String? = nil,
                                          error: String? = nil,
                                          isChanged: Bool? = nil,
                                          @ViewBuilder control: @escaping () -> Control) -> some View {
        UI.Form.Field(label: label,
                      info: info,
                      error: error ?? path.flatMap(fieldError),
                      isChanged: isChanged ?? path.map(fieldChanged) ?? false,
                      control: control)
    }

    private func formToggleRow(title: String,
                               path: Core.Field.Path? = nil,
                               subtitle: String? = nil,
                               info: String? = nil,
                               error: String? = nil,
                               isChanged: Bool? = nil,
                               isOn: Binding<Bool>) -> some View {
        UI.Form.ToggleRow(title: title,
                          subtitle: subtitle,
                          info: info,
                          error: error ?? path.flatMap(fieldError),
                          isChanged: isChanged ?? path.map(fieldChanged) ?? false,
                          isOn: isOn)
    }

    private func fieldChanged(_ path: Core.Field.Path) -> Bool {
        guard let field = spec.definition.descriptor(for: path) else { return false }
        let value = spec.document.value(path, in: spec.definition) ?? field.defaultValue
        return value != field.defaultValue
    }

    private func fieldError(_ path: Core.Field.Path) -> String? {
        spec.validationIssues
            .first { $0.field == path && $0.severity == .error }?
            .localizedMessage()
    }

    private var generalSection: some View {
        Group {
            formRow(title: AppText.runtime,
                    path: .runtimeKind,
                    subtitle: app.runtimePickerIsEnabled ? AppText.runtimeSubtitle : app.runtimePickerDisabledReason) {
                Picker("", selection: runtimeKindBinding) {
                    ForEach(app.availableRuntimeDescriptors, id: \.kind) { descriptor in
                        Text(descriptor.displayName).tag(descriptor.kind)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!app.runtimePickerIsEnabled)
            }
            formField(label: AppText.string("runSpec.image", defaultValue: "Image"),
                      path: .imageReference,
                      info: fieldInfo(.imageReference)) {
                TextField("", text: $spec.image, prompt: Text("e.g. nginx:latest"))
            }
            if imageDefaults != nil {
                formRow(title: AppText.string("runSpec.imageDefaults", defaultValue: "Image defaults"),
                        subtitle: AppText.string("runSpec.imageDefaults.subtitle", defaultValue: "Fill empty command, entrypoint, user, working directory, and environment fields from the pulled image config."),
                        info: AppText.string("containerForm.imageDefaults.info", defaultValue: "Images can define default startup settings. Adopt copies those defaults into this form so you can see and edit them before running.")) {
                    UI.Action.TextButton(title: AppText.string("runSpec.adopt", defaultValue: "Adopt"),
                                           systemName: "wand.and.stars") {
                        adoptImageDefaults()
                    }
                }
            }
            formRow(title: AppText.string("runSpec.platform", defaultValue: "Platform"),
                    path: .imagePlatform,
                    info: fieldInfo(.imagePlatform)) {
                Picker("", selection: platformPresetBinding) {
                    Text("Default").tag("")
                    Text("Linux arm64").tag("linux/arm64")
                    Text("Linux amd64").tag("linux/amd64")
                    Text("Linux amd64/v2").tag("linux/amd64/v2")
                    Text("Custom").tag("custom")
                }
                .labelsHidden().fixedSize()
            }
            if platformPresetBinding.wrappedValue == "custom" {
                formField(label: AppText.string("runSpec.customPlatform", defaultValue: "Custom platform"),
                          path: .imagePlatform,
                          info: fieldInfo(.imagePlatform)) {
                    TextField("", text: $spec.platform, prompt: Text("os/arch[/variant]"))
                }
            }
            formField(label: fieldLabel(.imageOS, fallback: "Image OS"),
                      path: .imageOS,
                      info: fieldInfo(.imageOS)) {
                TextField("", text: $spec.imageOS, prompt: Text("linux"))
            }
            formField(label: fieldLabel(.imageArchitecture, fallback: "Image architecture"),
                      path: .imageArchitecture,
                      info: fieldInfo(.imageArchitecture)) {
                TextField("", text: $spec.imageArchitecture, prompt: Text("arm64"))
            }
            formField(label: AppText.string("runSpec.name", defaultValue: "Name"),
                      path: .containerName,
                      info: fieldInfo(.containerName)) {
                TextField("", text: $spec.name, prompt: Text("optional"))
            }
            formField(label: AppText.string("runSpec.command", defaultValue: "Command"),
                      path: .processCommand,
                      info: fieldInfo(.processCommand)) {
                TextField("", text: $spec.command, prompt: Text("override the default command (optional)"))
            }
            formToggleRow(title: AppText.string("runSpec.detach", defaultValue: "Run in the background"),
                          path: .processDetach,
                          info: fieldInfo(.processDetach),
                          isOn: $spec.detach)
            formToggleRow(title: AppText.string("runSpec.removeWhenStopped", defaultValue: "Remove when stopped"),
                          path: .processRemoveOnExit,
                          info: fieldInfo(.processRemoveOnExit),
                          isOn: $spec.removeOnExit)
        }
    }

    private var resourcesSection: some View {
        Group {
            formRow(title: AppText.string("runSpec.cpus", defaultValue: "CPUs"),
                    path: .resourcesCPULimit,
                    info: fieldInfo(.resourcesCPULimit)) {
                Picker("", selection: cpuBinding) {
                    Text("Default").tag(0)
                    ForEach(1...max(1, hostCPUs), id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            formToggleRow(title: AppText.string("runSpec.limitMemory", defaultValue: "Limit memory"),
                          path: .resourcesMemoryLimit,
                          info: fieldInfo(.resourcesMemoryLimit),
                          isOn: memoryLimitBinding)
            if !spec.memory.isEmpty {
                formField(label: AppText.string("runSpec.memory", defaultValue: "Memory"),
                          path: .resourcesMemoryLimit) {
                    HStack(spacing: UI.Layout.Spacing.s) {
                        Slider(value: memoryGBBinding, in: 0.5...max(0.5, maxMemoryGB), step: 0.5)
                        Text(memoryReadout).monospacedDigit().frame(width: UI.Form.Width.memoryReadout)
                    }
                }
            }
        }
    }

    // MARK: Host-bounded resource controls

    private var hostCPUs: Int { ProcessInfo.processInfo.activeProcessorCount }
    /// Whole gigabytes of physical RAM, rounded down — the slider's upper bound.
    private var maxMemoryGB: Double { (Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded(.down) }

    /// CPU picker selection; `0` means "Default" (no `--cpus`, runtime decides).
    private var cpuBinding: Binding<Int> {
        Binding(get: { Int(spec.cpus) ?? 0 }, set: { spec.cpus = $0 == 0 ? "" : String($0) })
    }
    /// Memory-limit toggle: on writes a sensible default spec, off clears it.
    private var memoryLimitBinding: Binding<Bool> {
        Binding(get: { !spec.memory.isEmpty },
                set: { spec.memory = $0 ? Self.memorySpec(gb: min(2, max(0.5, maxMemoryGB))) : "" })
    }
    /// Memory slider value in GB, parsed from / written back to the `--memory` spec string.
    private var memoryGBBinding: Binding<Double> {
        Binding(get: { Self.parseMemoryGB(spec.memory) ?? 2 }, set: { spec.memory = Self.memorySpec(gb: $0) })
    }
    private var memoryReadout: String {
        memoryReadout(spec.memory, fallbackGB: 2)
    }
    private func memoryReadout(_ spec: String, fallbackGB: Double) -> String {
        ContainerFormStateMemoryFormatter.readout(spec, fallbackGB: fallbackGB)
    }

    private var platformPresetBinding: Binding<String> {
        let presets = Set(["", "linux/arm64", "linux/amd64", "linux/amd64/v2"])
        return Binding(get: { presets.contains(spec.platform) ? spec.platform : "custom" },
                       set: { if $0 != "custom" { spec.platform = $0 } })
    }

    private var imageDefaults: Core.Container.ImageDefaults? {
        app.imageDefaults(for: spec)
    }

    private var runtimeKindBinding: Binding<Core.Runtime.Kind> {
        Binding(get: { spec.effectiveRuntimeKind },
                set: { spec.runtimeKind = $0 })
    }

    private func adoptImageDefaults() {
        guard let imageDefaults else { return }
        let applied = spec.adoptImageDefaults(from: imageDefaults)
        if applied > 0 {
            app.flash(AppText.adoptedImageDefaults(applied))
        } else {
            app.flash(AppText.imageDefaultsAlreadyRepresented)
        }
    }

    static func parseMemoryGB(_ spec: String) -> Double? {
        ContainerFormStateMemoryFormatter.parseGB(spec)
    }

    static func memorySpec(gb: Double) -> String {
        ContainerFormStateMemoryFormatter.spec(gb: gb)
    }

    private var portsSection: some View {
        Group {
            ForEach(spec.ports) { port in
                HStack {
                    TextField("Host", text: elementBinding($spec.ports, id: port.id, \.hostPort, fallback: ""))

                        .frame(width: UI.Form.Width.port)
                    UI.Symbol.Image(systemName: "arrow.right")
                    TextField("Container", text: elementBinding($spec.ports, id: port.id, \.containerPort, fallback: ""))

                        .frame(width: UI.Form.Width.containerPort)
                    Picker("", selection: elementBinding($spec.ports, id: port.id, \.proto, fallback: "tcp")) { Text("tcp").tag("tcp"); Text("udp").tag("udp") }
                        .labelsHidden().frame(width: UI.Form.Width.port)
                    Spacer()
                    removeButton { spec.ports.removeAll { $0.id == port.id } }
                }
            }
            addButton(AppText.string("runSpec.addPort", defaultValue: "Add port"), info: fieldInfo(.networkPorts)) {
                spec.ports.append(PortMap())
            }
        }
    }

    @ViewBuilder
    private var storageSections: some View {
        ForEach(Array(storageGroupsBinding.wrappedValue.enumerated()), id: \.element.id) { index, group in
            Section {
                StorageGroupEditor(runtimeKind: spec.effectiveRuntimeKind,
                                   group: storageGroupBinding(id: group.id))
            } header: {
                storageGroupHeader(index: index, group: group) {
                    var groups = storageGroupsBinding.wrappedValue
                    groups.removeAll { $0.id == group.id }
                    storageGroupsBinding.wrappedValue = groups
                }
            } footer: {
                storageGroupFooter(group)
            }
        }

        Section {
            addButton(AppText.string("runSpec.addStorageGroup", defaultValue: "Add storage group"), info: fieldInfo(.storageVolumes)) {
                var groups = storageGroupsBinding.wrappedValue
                groups.append(StorageGroup())
                storageGroupsBinding.wrappedValue = groups
            }
        }
    }

    private var environmentSection: some View {
        Group {
            ForEach(spec.env) { variable in
                HStack {
                    TextField("KEY", text: elementBinding($spec.env, id: variable.id, \.key, fallback: ""))

                    UI.State.StatusText("=")
                    TextField("value", text: elementBinding($spec.env, id: variable.id, \.value, fallback: ""))

                    removeButton { spec.env.removeAll { $0.id == variable.id } }
                }
            }
            addButton(AppText.string("runSpec.addVariable", defaultValue: "Add variable"), info: fieldInfo(.environmentVariables)) {
                spec.env.append(KeyValue())
            }
            stringList(AppText.string("runSpec.addEnvFile", defaultValue: "Add env file"), $spec.envFiles, prompt: "/path/to/.env",
                       info: fieldInfo(.environmentFiles))
        }
    }

    private var socketsSection: some View {
        Group {
            ForEach(spec.sockets) { socket in
                LazyVStack(spacing: UI.Layout.Spacing.xs) {
                    HStack {
                        TextField("Host socket path", text: elementBinding($spec.sockets, id: socket.id, \.hostPath, fallback: ""))

                        removeButton { spec.sockets.removeAll { $0.id == socket.id } }
                    }
                    TextField("Container socket path", text: elementBinding($spec.sockets, id: socket.id, \.containerPath, fallback: ""))

                }
            }
            addButton(AppText.string("runSpec.addSocket", defaultValue: "Add socket"), info: fieldInfo(.networkSockets)) {
                spec.sockets.append(SocketMap())
            }
        }
    }

    private var labelsSection: some View {
        Group {
            ForEach(spec.labels) { label in
                HStack {
                    TextField("KEY", text: elementBinding($spec.labels, id: label.id, \.key, fallback: ""))

                    UI.State.StatusText("=")
                    TextField("value", text: elementBinding($spec.labels, id: label.id, \.value, fallback: ""))

                    removeButton { spec.labels.removeAll { $0.id == label.id } }
                }
            }
            addButton(AppText.string("runSpec.addLabel", defaultValue: "Add label"), info: fieldInfo(.metadataLabels)) {
                spec.labels.append(KeyValue())
            }
        }
    }

    private var personalizationSection: some View {
        Group {
            formField(label: AppText.string("runSpec.nickname", defaultValue: "Nickname"),
                      info: AppText.string("containerForm.personalization.nickname.info", defaultValue: "A display name for the card only. It does not rename the real container."),
                      isChanged: spec.personalization.nickname != Personalization().nickname) {
                TextField("", text: $spec.personalization.nickname, prompt: Text("display name (optional)"))
            }
            formField(label: AppText.string("runSpec.icon", defaultValue: "Icon"),
                      info: AppText.string("containerForm.personalization.icon.info", defaultValue: "An SF Symbol name for the card icon, such as `shippingbox` or `bolt`."),
                      isChanged: spec.personalization.icon != Personalization().icon) {
                TextField("", text: $spec.personalization.icon, prompt: Text("SF Symbol, e.g. globe, bolt"))
            }
            formRow(title: AppText.string("runSpec.color", defaultValue: "Color"),
                    info: AppText.string("containerForm.personalization.color.info", defaultValue: "Sets the card icon color. If background color is enabled, it also tints the glass card."),
                    isChanged: spec.personalization.tint != Personalization().tint) {
                UI.Control.TintSelector(selection: $spec.personalization.tint) { $0.localizedDisplayName }
            }
            formToggleRow(title: AppText.string("runSpec.colorCardBackground", defaultValue: "Color the card background"),
                          info: AppText.string("containerForm.personalization.colorCardBackground.info", defaultValue: "Adds a soft color wash behind the glass. Turn it off for clear glass with only a colored icon."),
                          isChanged: spec.personalization.fillBackground != Personalization().fillBackground,
                          isOn: $spec.personalization.fillBackground)
            if spec.personalization.fillBackground {
                formField(label: AppText.string("runSpec.opacity", defaultValue: "Opacity"),
                          isChanged: spec.personalization.backgroundOpacity != Personalization.defaultBackgroundOpacity) {
                    HStack(spacing: UI.Layout.Spacing.s) {
                        Slider(value: $spec.personalization.backgroundOpacity, in: 0.05...0.6)
                        Text(Format.percent(spec.personalization.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: UI.Form.Width.shortReadout)
                    }
                }
                formToggleRow(title: AppText.string("runSpec.gradient", defaultValue: "Gradient"),
                              info: AppText.string("containerForm.personalization.gradient.info", defaultValue: "Blends the color across the card instead of using one flat wash."),
                              isChanged: spec.personalization.gradient != Personalization().gradient,
                              isOn: $spec.personalization.gradient)
                if spec.personalization.gradient {
                    UI.Control.GradientAngle(angle: $spec.personalization.gradientAngle, title: AppText.direction)
                }
                formRow(title: AppText.string("runSpec.blendMode", defaultValue: "Blend mode"),
                        info: AppText.string("containerForm.personalization.blendMode.info", defaultValue: "Controls how the card color wash blends with the glass behind it."),
                        isChanged: spec.personalization.backgroundBlendMode != Personalization().backgroundBlendMode) {
                    Picker("", selection: $spec.personalization.backgroundBlendMode) {
                        ForEach(UI.Theme.ColorBlendMode.allCases) { mode in
                            Text(mode.localizedDisplayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }

    private var restartSection: some View {
        formRow(title: AppText.string("runSpec.restartPolicy", defaultValue: "Restart policy"),
                path: .lifecycleRestartPolicy,
                info: AppText.string("containerForm.restartPolicy.info", defaultValue: "Contained restarts the container automatically based on this setting.")) {
            Picker("", selection: $spec.restart) {
                ForEach(Core.Container.RestartPolicy.allCases) { Text($0.localizedDisplayName).tag($0) }
            }
            .labelsHidden().fixedSize()
        }
    }

    private var healthSection: some View {
        Group {
            formToggleRow(title: AppText.string("runSpec.enableHealthcheck", defaultValue: "Enable healthcheck"),
                          info: AppText.string("containerForm.healthcheck.enabled.info", defaultValue: "Contained probes the container on an interval (app-managed; the runtime has no native healthcheck)."),
                          isChanged: spec.healthCheck.enabled != Core.Container.HealthCheck().enabled,
                          isOn: $spec.healthCheck.enabled)
            if spec.healthCheck.enabled {
                formField(label: AppText.string("runSpec.probeCommand", defaultValue: "Probe command"),
                          info: AppText.string("containerForm.healthcheck.probeCommand.info", defaultValue: "Run inside the container via `sh -c`; a zero exit = healthy. Needs a shell in the image."),
                          isChanged: spec.healthCheck.command != Core.Container.HealthCheck().command) {
                    TextField("", text: healthCommandBinding, prompt: Text("curl -f http://localhost/ || exit 1"))
                }
                Stepper("Interval: \(spec.healthCheck.intervalSeconds)s",
                        value: $spec.healthCheck.intervalSeconds, in: 5...600, step: 5)
                Stepper("Unhealthy after \(spec.healthCheck.retries) failures",
                        value: $spec.healthCheck.retries, in: 1...10)
            }
        }
    }

    /// Bridges the probe string to/from a `sh -c <cmd>` argv so shell expressions work.
    private var healthCommandBinding: Binding<String> {
        Binding(get: {
            let cmd = spec.healthCheck.command
            if cmd.count >= 3, cmd[0] == "sh", cmd[1] == "-c" { return cmd[2] }
            return cmd.joined(separator: " ")
        }, set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            spec.healthCheck.command = trimmed.isEmpty ? [] : ["sh", "-c", trimmed]
        })
    }

    @ViewBuilder
    private var runtimeSection: some View {
        Group {
            formField(label: AppText.string("runSpec.entrypoint", defaultValue: "Entrypoint"),
                      path: .processEntrypoint,
                      info: fieldInfo(.processEntrypoint)) {
                TextField("", text: $spec.entrypoint, prompt: Text("optional"))
            }
            formToggleRow(title: AppText.string("runSpec.keepStdinOpen", defaultValue: "Keep stdin open"),
                          path: .processInteractive,
                          info: fieldInfo(.processInteractive), isOn: $spec.interactive)
            formToggleRow(title: AppText.string("runSpec.allocateTTY", defaultValue: "Allocate TTY"),
                          path: .processTTY,
                          info: fieldInfo(.processTTY), isOn: $spec.tty)
            formField(label: AppText.string("runSpec.workingDirectory", defaultValue: "Working directory"),
                      path: .processWorkingDirectory,
                      info: fieldInfo(.processWorkingDirectory)) {
                TextField("", text: $spec.workingDir, prompt: Text("optional, e.g. /app"))
            }
            formField(label: AppText.string("runSpec.user", defaultValue: "User"),
                      path: .processUser,
                      info: fieldInfo(.processUser)) {
                TextField("", text: $spec.user, prompt: Text("name | uid[:gid]"))
            }
            formField(label: AppText.string("runSpec.userID", defaultValue: "User ID"),
                      info: "\(fieldInfo(.processUserID))\n\n\(fieldInfo(.processGroupID))",
                      error: fieldError(.processUserID) ?? fieldError(.processGroupID),
                      isChanged: fieldChanged(.processUserID) || fieldChanged(.processGroupID)) {
                HStack {
                    TextField("UID", text: $spec.uid).frame(width: UI.Form.Width.userID)
                    TextField("GID", text: $spec.gid).frame(width: UI.Form.Width.userID)
                    Spacer()
                }
            }
            formToggleRow(title: AppText.string("runSpec.setSharedMemorySize", defaultValue: "Set shared memory size"),
                          path: .resourcesSharedMemorySize,
                          info: fieldInfo(.resourcesSharedMemorySize), isOn: shmLimitBinding)
            if !spec.shmSize.isEmpty {
                formField(label: AppText.string("runSpec.sharedMemory", defaultValue: "Shared memory"),
                          path: .resourcesSharedMemorySize) {
                    HStack(spacing: UI.Layout.Spacing.s) {
                        Slider(value: shmGBBinding, in: 0.0625...max(0.0625, maxMemoryGB), step: 0.0625)
                        Text(memoryReadout(spec.shmSize, fallbackGB: 0.0625))
                            .monospacedDigit()
                            .frame(width: UI.Form.Width.memoryReadout)
                    }
                }
            }

            stringList(AppText.string("runSpec.addCapability", defaultValue: "Add capability"), $spec.capAdd, prompt: "CAP_NET_RAW or ALL",
                       info: fieldInfo(.securityCapabilitiesAdd))
            stringList(AppText.string("runSpec.dropCapability", defaultValue: "Drop capability"), $spec.capDrop, prompt: "CAP_NET_RAW or ALL",
                       info: fieldInfo(.securityCapabilitiesDrop))
            formField(label: AppText.string("runSpec.containerIDFile", defaultValue: "Container ID file"),
                      path: .outputContainerIDFile,
                      info: fieldInfo(.outputContainerIDFile)) {
                TextField("", text: $spec.cidFile, prompt: Text("optional path"))
            }
            stringList(AppText.string("runSpec.addTmpfsMount", defaultValue: "Add tmpfs mount"), $spec.tmpfs, prompt: "/path",
                       info: fieldInfo(.storageTmpfs))
            stringList(AppText.string("runSpec.addUlimit", defaultValue: "Add ulimit"), $spec.ulimits, prompt: "nofile=1024:2048",
                       info: fieldInfo(.processUlimits))
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Group {
            formToggleRow(title: AppText.string("runSpec.readOnlyFilesystem", defaultValue: "Read-only filesystem"),
                          path: .securityReadOnlyRootFS,
                          info: fieldInfo(.securityReadOnlyRootFS), isOn: $spec.readOnly)
            formToggleRow(title: AppText.string("runSpec.useInitProcess", defaultValue: "Use an init process"),
                          path: .securityUseInit,
                          info: fieldInfo(.securityUseInit), isOn: $spec.useInit)
            formToggleRow(title: AppText.string("runSpec.rosetta", defaultValue: "Rosetta (x86 apps)"),
                          path: .securityRosetta,
                          info: fieldInfo(.securityRosetta), isOn: $spec.rosetta)
            formToggleRow(title: AppText.string("runSpec.forwardSSHAgent", defaultValue: "Forward SSH agent"),
                          path: .securitySSHAgent,
                          info: fieldInfo(.securitySSHAgent), isOn: $spec.ssh)
            formToggleRow(title: AppText.string("runSpec.exposeVirtualization", defaultValue: "Expose virtualization"),
                          path: .securityVirtualization,
                          info: fieldInfo(.securityVirtualization), isOn: $spec.virtualization)
        }
    }

    @ViewBuilder
    private var networkSection: some View {
        formRow(title: AppText.string("runSpec.network", defaultValue: "Network"),
                path: .networkName,
                info: fieldInfo(.networkName)) {
            Menu(networkMenuTitle) {
                Button {
                    spec.network = ""
                } label: {
                    Label("Default", systemImage: spec.network.isEmpty ? "checkmark" : "network")
                }
                if !app.networks.isEmpty { Divider() }
                ForEach(app.networks) { network in
                    Button {
                        spec.network = network.name
                    } label: {
                        Label(network.name, systemImage: spec.network == network.name ? "checkmark" : "network")
                    }
                }
                Divider()
                Button {
                    ui.dispatch(.createNetwork)
                } label: {
                    Label("Create New Network…", systemImage: "plus")
                }
            }
            .fixedSize()
            TextField("", text: $spec.network, prompt: Text("custom network"))
                .frame(width: UI.Form.Width.networkName)
        }
        .task { await app.refreshNetworks() }
    }

    @ViewBuilder
    private var fetchSection: some View {
        Group {
            formField(label: AppText.string("runSpec.runtime", defaultValue: "Runtime"),
                      path: .runtimeHandler,
                      info: fieldInfo(.runtimeHandler)) {
                TextField("", text: $spec.runtime, prompt: Text("optional"))
            }
            formField(label: AppText.string("runSpec.initImage", defaultValue: "Init image"),
                      path: .imageInitReference,
                      info: fieldInfo(.imageInitReference)) {
                TextField("", text: $spec.initImage, prompt: Text("optional image"))
            }
            formField(label: AppText.string("runSpec.kernel", defaultValue: "Kernel"),
                      path: .kernelPath,
                      info: fieldInfo(.kernelPath)) {
                TextField("", text: $spec.kernel, prompt: Text("optional path"))
            }
            formRow(title: AppText.string("runSpec.registryScheme", defaultValue: "Registry scheme"),
                    path: .registryScheme,
                    info: fieldInfo(.registryScheme)) {
                Picker("", selection: $spec.scheme) {
                    Text("Default").tag("")
                    Text("Auto").tag("auto")
                    Text("HTTPS").tag("https")
                    Text("HTTP").tag("http")
                }
                .labelsHidden().fixedSize()
            }
            formRow(title: AppText.string("runSpec.progress", defaultValue: "Progress"),
                    path: .progressMode,
                    info: fieldInfo(.progressMode)) {
                Picker("", selection: $spec.progress) {
                    Text("Default").tag("")
                    Text("Auto").tag("auto")
                    Text("None").tag("none")
                    Text("ANSI").tag("ansi")
                    Text("Plain").tag("plain")
                    Text("Color").tag("color")
                }
                .labelsHidden().fixedSize()
            }
            formToggleRow(title: AppText.string("runSpec.limitParallelDownloads", defaultValue: "Limit parallel downloads"),
                          path: .imageMaxConcurrentDownloads,
                          info: fieldInfo(.imageMaxConcurrentDownloads), isOn: maxDownloadsBinding)
            if !spec.maxConcurrentDownloads.isEmpty {
                Stepper("Max downloads: \(maxConcurrentDownloadsBinding.wrappedValue)",
                        value: maxConcurrentDownloadsBinding, in: 1...16)
            }
        }
    }

    @ViewBuilder
    private var dnsSection: some View {
        Group {
            formToggleRow(title: AppText.string("runSpec.disableDNS", defaultValue: "Disable DNS"),
                          path: .networkDNSDisabled,
                          info: fieldInfo(.networkDNSDisabled), isOn: $spec.noDNS)
            if !spec.noDNS {
                stringList(AppText.string("runSpec.addNameserver", defaultValue: "Add nameserver"), $spec.dns, prompt: "1.1.1.1",
                           info: fieldInfo(.networkDNSServers))
                formField(label: AppText.string("runSpec.searchDomain", defaultValue: "Search domain"),
                          path: .networkDNSDomain,
                          info: fieldInfo(.networkDNSDomain)) {
                    TextField("", text: $spec.dnsDomain, prompt: Text("optional"))
                }
                stringList(AppText.string("runSpec.addSearchDomain", defaultValue: "Add search domain"), $spec.dnsSearch, prompt: "example.com",
                           info: fieldInfo(.networkDNSSearchDomains))
                stringList(AppText.string("runSpec.addDNSOption", defaultValue: "Add DNS option"), $spec.dnsOption, prompt: "ndots:2",
                           info: fieldInfo(.networkDNSOptions))
            }
        }
    }

    @ViewBuilder
    private var advancedOptionsSection: some View {
        Section {
            runtimeSection
            securitySection
            fetchSection
            dnsSection
            stringList(AppText.string("runSpec.addMount", defaultValue: "Add mount"), $spec.mounts, prompt: "type=bind,source=/host,target=/container",
                       info: fieldInfo(.storageMounts))
            labelsSection
        } header: {
            formSectionHeader(AppText.string("runSpec.section.advancedOptions", defaultValue: "Advanced Options"), highlighted: spec.hasAdvancedOptions)
        } footer: {
            Text(.init(AppText.string("runSpec.section.advancedOptions.footer", defaultValue: "Less-common run settings. Compose import and Edit reveal these automatically when advanced values are present.")))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var dockerComposeSection: some View {
        let fields = unsupportedFields
        if !fields.isEmpty {
            Section {
                ForEach(fields) { field in
                    formField(label: fieldLabel(field),
                              path: field.path,
                              info: fieldInfo(field.path),
                              error: field.support(for: spec.effectiveRuntimeKind).localizedDisabledReason()) {
                        Text(valueDescription(for: field))
                            .designSecondaryCallout()
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } header: {
                formSectionHeader(AppText.string("runSpec.section.dockerCompose", defaultValue: "Docker & Compose"), highlighted: spec.hasUnsupportedRuntimeValues)
            } footer: {
                Text(.init(AppText.string("runSpec.section.dockerCompose.footer", defaultValue: "Known Docker CLI and Compose fields preserved for future runtimes. Apple container cannot execute these values.")))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unsupportedFields: [Core.Schema.FieldDescriptor] {
        spec.definition.fields.filter { field in
            field.support(for: spec.effectiveRuntimeKind).state == .disabled &&
            !(spec.document.value(field.path, in: spec.definition) ?? field.defaultValue).isEmpty
        }
    }

    private var shmLimitBinding: Binding<Bool> {
        Binding(get: { !spec.shmSize.isEmpty },
                set: { spec.shmSize = $0 ? "64M" : "" })
    }

    private var shmGBBinding: Binding<Double> {
        Binding(get: { Self.parseMemoryGB(spec.shmSize) ?? 0.0625 },
                set: { spec.shmSize = Self.memorySpec(gb: $0) })
    }

    private var maxDownloadsBinding: Binding<Bool> {
        Binding(get: { !spec.maxConcurrentDownloads.isEmpty },
                set: { spec.maxConcurrentDownloads = $0 ? "3" : "" })
    }

    private var maxConcurrentDownloadsBinding: Binding<Int> {
        Binding(get: { max(1, Int(spec.maxConcurrentDownloads) ?? 3) },
                set: { spec.maxConcurrentDownloads = String($0) })
    }

    private var networkMenuTitle: String {
        spec.network.trimmingCharacters(in: .whitespaces).isEmpty ? AppText.string("runSpec.default", defaultValue: "Default") : spec.network
    }

    /// A repeatable single-string list editor (capabilities, DNS servers, tmpfs, ulimits…).
    @ViewBuilder
    private func stringList(_ addTitle: String, _ list: Binding<[String]>, prompt: String, info: String) -> some View {
        ForEach(list.wrappedValue.indices, id: \.self) { idx in
            HStack {
                TextField(prompt, text: stringListBinding(list, index: idx))

                removeButton { list.wrappedValue.remove(at: idx) }
            }
        }
        HStack(spacing: UI.Layout.Spacing.s) {
            addButton(addTitle) { list.wrappedValue.append("") }
            UI.Control.InfoButton(info)
            Spacer()
        }
    }

    @ViewBuilder
    private func addButton(_ title: String, info: String? = nil, action: @escaping () -> Void) -> some View {
        let button = UI.Action.Group(UI.Action.Item(systemName: "plus.circle",
                                                   title: title,
                                                   help: title,
                                                   action: action))
        if let info, !info.isEmpty {
            HStack(spacing: UI.Layout.Spacing.s) {
                button
                UI.Control.InfoButton(info)
                Spacer()
            }
        } else {
            button
        }
    }

    private func elementBinding<Element: Identifiable, Value>(_ list: Binding<[Element]>,
                                                              id: Element.ID,
                                                              _ keyPath: WritableKeyPath<Element, Value>,
                                                              fallback: Value) -> Binding<Value> where Element.ID: Equatable {
        Binding {
            list.wrappedValue.first { $0.id == id }?[keyPath: keyPath] ?? fallback
        } set: { newValue in
            guard let index = list.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
            list.wrappedValue[index][keyPath: keyPath] = newValue
        }
    }

    private func stringListBinding(_ list: Binding<[String]>, index: Int) -> Binding<String> {
        Binding {
            guard list.wrappedValue.indices.contains(index) else { return "" }
            return list.wrappedValue[index]
        } set: { newValue in
            guard list.wrappedValue.indices.contains(index) else { return }
            list.wrappedValue[index] = newValue
        }
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(AppText.string("common.remove", defaultValue: "Remove"))
    }

    private var storageGroupsBinding: Binding<[StorageGroup]> {
        Binding {
            spec.storageGroupsForEditing
        } set: { groups in
            spec.storageGroupsForEditing = groups
        }
    }

    private func storageGroupBinding(id: UUID) -> Binding<StorageGroup> {
        Binding {
            storageGroupsBinding.wrappedValue.first { $0.id == id } ?? StorageGroup(id: id)
        } set: { updated in
            var groups = storageGroupsBinding.wrappedValue
            guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
            groups[index] = updated
            storageGroupsBinding.wrappedValue = groups
        }
    }

    private func fieldLabel(_ field: Core.Schema.FieldDescriptor) -> String {
        field.localizedLabel()
    }

    private func fieldLabel(_ path: Core.Field.Path, fallback: String) -> String {
        guard let field = spec.definition.descriptor(for: path) else { return fallback }
        return fieldLabel(field)
    }

    private func fieldInfo(_ path: Core.Field.Path) -> String {
        guard let field = spec.definition.descriptor(for: path) else { return "" }
        let tip = field.tip(for: spec.effectiveRuntimeKind)
        let body = tip?.localizedText() ?? field.localizedLabel()
        let aliases = field.sourceAliases
            .filter { !$0.name.isEmpty || !$0.example.isEmpty }
            .map { alias -> String in
                let source: String
                switch alias.source {
                case .appleCLI: source = "Apple container"
                case .dockerCLI: source = "Docker CLI"
                case .compose: source = "Compose"
                }
                if alias.example.isEmpty { return "\(source): \(alias.name)" }
                return "\(source): \(alias.name) — \(alias.example)"
            }
        guard !aliases.isEmpty else { return body }
        return ([body, "Source references:", aliases.joined(separator: "\n")]).joined(separator: "\n\n")
    }

    private func valueDescription(for field: Core.Schema.FieldDescriptor) -> String {
        let value = spec.document.value(field.path, in: spec.definition) ?? field.defaultValue
        switch value {
        case .string(let value), .enumeration(let value):
            return value.isEmpty ? AppText.string("schema.value.notSet", defaultValue: "Not set") : value
        case .bool(let value):
            return value ? AppText.string("common.enabled", defaultValue: "Enabled") : AppText.string("common.disabled", defaultValue: "Disabled")
        case .commandLine(let values), .stringList(let values):
            let filtered = values.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return filtered.isEmpty ? AppText.string("schema.value.notSet", defaultValue: "Not set") : filtered.joined(separator: ", ")
        case .keyValueList(let values):
            let rendered = values.filter(\.isValid).map { "\($0.key)=\($0.value)" }
            return rendered.isEmpty ? AppText.string("schema.value.notSet", defaultValue: "Not set") : rendered.joined(separator: ", ")
        case .portList(let values):
            let rendered = values.filter(\.isValid).map(\.spec)
            return rendered.isEmpty ? AppText.string("schema.value.notSet", defaultValue: "Not set") : rendered.joined(separator: ", ")
        case .volumeList(let values):
            let rendered = values.filter(\.isValid).map(\.spec)
            return rendered.isEmpty ? AppText.string("schema.value.notSet", defaultValue: "Not set") : rendered.joined(separator: ", ")
        case .socketList(let values):
            let rendered = values.filter(\.isValid).map(\.spec)
            return rendered.isEmpty ? AppText.string("schema.value.notSet", defaultValue: "Not set") : rendered.joined(separator: ", ")
        }
    }
}

private enum StoragePathMode {
    case bindMount
    case volumeLink
}

private struct StorageGroupEditor: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    let runtimeKind: Core.Runtime.Kind
    @Binding var group: StorageGroup

    var body: some View {
        Group {
            UI.Form.ToggleRow(title: AppText.string("runSpec.storageGroup.useRuntimeVolume", defaultValue: "Use runtime volume"),
                              info: AppText.string("containerForm.storageGroup.useRuntimeVolume.info",
                                                   defaultValue: "Mounts one runtime-owned volume, then lets Contained place host-folder links inside it before the container starts."),
                              isChanged: group.usesRuntimeVolume,
                              isOn: usesRuntimeVolumeBinding)

            if group.usesRuntimeVolume {
                runtimeVolumeFields
            }

            pathRows
        }
        .task(id: runtimeKind) { await app.refreshVolumes() }
    }

    private var runtimeVolumeFields: some View {
        Group {
            UI.Form.Field(label: AppText.string("runSpec.storageGroup.runtimeVolume", defaultValue: "Runtime volume"),
                          error: group.volumeName.trimmedForVolumeLink.isEmpty ? AppText.string("runSpec.storageGroup.runtimeVolume.required", defaultValue: "Select or name a runtime volume.") : nil,
                          isChanged: !group.volumeName.trimmedForVolumeLink.isEmpty) {
                HStack(spacing: UI.Layout.Spacing.s) {
                    Menu(runtimeVolumeMenuTitle) {
                        if runtimeVolumes.isEmpty {
                            Text(AppText.string("runSpec.noRuntimeVolumes", defaultValue: "No runtime volumes found"))
                        } else {
                            ForEach(runtimeVolumes) { volume in
                                Button {
                                    group.volumeName = volume.name
                                } label: {
                                    Label(volume.name, systemImage: group.volumeName == volume.name ? "checkmark" : "externaldrive")
                                }
                            }
                        }
                        Divider()
                        Button {
                            ui.dispatch(.createVolume)
                        } label: {
                            Label(AppText.string("runSpec.createNewVolume", defaultValue: "Create New Volume..."),
                                  systemImage: "plus")
                        }
                    }
                    .fixedSize()
                    TextField("Volume name", text: $group.volumeName)
                }
            }

            UI.Form.Field(label: AppText.string("runSpec.storageGroup.volumeMountPath", defaultValue: "Mounted at"),
                          error: group.volumeTarget.trimmedForVolumeLink.isEmpty ? AppText.string("runSpec.storageGroup.volumeMountPath.required", defaultValue: "Choose where the runtime volume is mounted in the container.") : nil,
                          isChanged: !group.volumeTarget.trimmedForVolumeLink.isEmpty) {
                TextField("Volume path", text: $group.volumeTarget, prompt: Text("/config"))
            }
        }
    }

    private var pathRows: some View {
        Group {
            if group.usesRuntimeVolume {
                Text(AppText.string("runSpec.storageGroup.volumePathsHelp",
                                    defaultValue: "Each path mounts a host folder temporarily and links it inside the runtime volume."))
                    .designSecondaryCaption()
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(group.paths.enumerated()), id: \.element.id) { index, path in
                StoragePathRow(title: "\(AppText.string("runSpec.storagePath", defaultValue: "Path")) \(index + 1)",
                               mode: group.usesRuntimeVolume ? .volumeLink : .bindMount,
                               volumeTarget: group.volumeTarget,
                               path: storagePathBinding(id: path.id),
                               onRemove: { group.paths.removeAll { $0.id == path.id } })
            }

            UI.Action.TextButton(title: AppText.string("runSpec.addStoragePath", defaultValue: "Add Path"),
                                 systemName: "plus.circle") {
                group.paths.append(StoragePath())
            }
        }
    }

    private var usesRuntimeVolumeBinding: Binding<Bool> {
        Binding {
            group.usesRuntimeVolume
        } set: { enabled in
            group.usesRuntimeVolume = enabled
            if enabled {
                if group.volumeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   runtimeVolumes.count == 1,
                   let onlyVolume = runtimeVolumes.first {
                    group.volumeName = onlyVolume.name
                }
                if group.volumeTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    group.volumeTarget = "/config"
                }
            }
            if group.paths.isEmpty {
                group.paths.append(StoragePath())
            }
        }
    }

    private func storagePathBinding(id: UUID) -> Binding<StoragePath> {
        Binding {
            group.paths.first { $0.id == id } ?? StoragePath(id: id)
        } set: { updated in
            guard let index = group.paths.firstIndex(where: { $0.id == id }) else { return }
            group.paths[index] = updated
        }
    }

    private var runtimeVolumes: [Core.Volume.Resource] {
        app.volumes
            .filter { $0.runtimeKind == runtimeKind }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var runtimeVolumeMenuTitle: String {
        let trimmed = group.volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? AppText.string("runSpec.selectVolume", defaultValue: "Select Volume")
            : trimmed
    }

}

private struct StoragePathRow: View {
    @Environment(AppModel.self) private var app
    let title: String
    let mode: StoragePathMode
    let volumeTarget: String
    @Binding var path: StoragePath
    var onRemove: () -> Void
    @State private var choosingHostPath = false

    var body: some View {
        Group {
            UI.Form.Row(title: title) {
                removeButton
            }

            UI.Form.Field(label: AppText.string("runSpec.storagePath.hostFolder", defaultValue: "Host folder"),
                          error: hostPathError,
                          isChanged: !path.hostPath.trimmedForVolumeLink.isEmpty) {
                HStack(spacing: UI.Layout.Spacing.s) {
                    UI.Action.Group(UI.Action.Item(systemName: "folder",
                                                   title: AppText.string("runSpec.chooseFolder", defaultValue: "Choose Folder..."),
                                                   help: AppText.string("runSpec.chooseFolder", defaultValue: "Choose Folder...")) {
                        choosingHostPath = true
                    })
                    TextField("Host folder", text: $path.hostPath)
                }
            }

            UI.Form.Field(label: internalPathLabel,
                          error: internalPathError,
                          isChanged: !path.internalPath.trimmedForVolumeLink.isEmpty) {
                TextField(internalPathPrompt, text: $path.internalPath)
            }

            UI.Form.Row(title: AppText.string("runSpec.mountAccess", defaultValue: "Access"),
                        subtitle: AppText.string("runSpec.storagePath.access.subtitle", defaultValue: "Controls whether the container can write to this host folder."),
                        isChanged: path.readOnly != true) {
                Picker("", selection: accessBinding) {
                    Text(AppText.string("runSpec.access.readOnly", defaultValue: "Read only")).tag(true)
                    Text(AppText.string("runSpec.access.readWrite", defaultValue: "Read/Write")).tag(false)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if mode == .volumeLink && pathIsValid && !resolvedVolumeLinkPath.isEmpty {
                Text("\(resolvedVolumeLinkPath) → \(temporaryMountTarget)")
                    .designSecondaryMonospacedCaption()
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if mode == .volumeLink && pathIsValid {
                UI.State.InlineStatus(AppText.string("runSpec.linkedPaths.outsideVolume",
                                                     defaultValue: "Link paths must stay inside the selected runtime volume."),
                                      systemImage: "exclamationmark.triangle",
                                      tone: .warning)
            }
        }
        .fileImporter(isPresented: $choosingHostPath,
                      allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                path.hostPath = url.path
            case .failure(let error):
                app.flash(error.appDisplayMessage)
            }
        }
    }

    private var accessBinding: Binding<Bool> {
        Binding {
            path.readOnly
        } set: { newValue in
            path.readOnly = newValue
        }
    }

    private var hostPathError: String? {
        if path.hostPath.trimmedForVolumeLink.isEmpty,
           !path.internalPath.trimmedForVolumeLink.isEmpty {
            return AppText.string("runSpec.storagePath.hostFolder.required", defaultValue: "Choose the host folder for this path.")
        }
        return nil
    }

    private var internalPathError: String? {
        if path.internalPath.trimmedForVolumeLink.isEmpty,
           !path.hostPath.trimmedForVolumeLink.isEmpty {
            return AppText.string("runSpec.storagePath.internalPath.required", defaultValue: "Choose where this path appears in the container.")
        }
        if mode == .volumeLink,
           !path.internalPath.trimmedForVolumeLink.isEmpty,
           resolvedVolumeLinkPath.isEmpty {
            return AppText.string("runSpec.linkedPaths.outsideVolume", defaultValue: "Link paths must stay inside the selected runtime volume.")
        }
        return nil
    }

    private var internalPathLabel: String {
        switch mode {
        case .bindMount:
            AppText.string("runSpec.storagePath.internalPath", defaultValue: "Internal path")
        case .volumeLink:
            AppText.string("runSpec.storagePath.insideVolume", defaultValue: "Inside volume")
        }
    }

    private var internalPathPrompt: String {
        switch mode {
        case .bindMount:
            "/media"
        case .volumeLink:
            volumeTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "media" : "\(volumeTarget)/media"
        }
    }

    private var pathIsValid: Bool {
        !path.hostPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !path.internalPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var temporaryMountTarget: String {
        "/run/contained-links/\(path.id.uuidString.lowercased())"
    }

    private var resolvedVolumeLinkPath: String {
        let trimmed = path.internalPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let target = volumeTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            return trimmed.isInsideStorageVolumeTarget(target) ? trimmed : ""
        }
        guard !target.isEmpty else { return "" }
        return target.hasSuffix("/") ? target + trimmed : target + "/" + trimmed
    }

    private var removeButton: some View {
        UI.Action.Group(UI.Action.Item(systemName: "minus.circle.fill",
                                       help: AppText.string("common.remove", defaultValue: "Remove"),
                                       action: onRemove))
    }
}

private extension String {
    var trimmedForVolumeLink: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isInsideStorageVolumeTarget(_ target: String) -> Bool {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else { return false }
        if trimmedTarget == "/" { return hasPrefix("/") }
        let prefix = trimmedTarget.hasSuffix("/") ? trimmedTarget : trimmedTarget + "/"
        return self == trimmedTarget || hasPrefix(prefix)
    }
}
