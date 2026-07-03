import SwiftUI
import ContainedUX
import ContainedUI
import AppKit
import ContainedCore

/// The shared container Create/Edit form body: progressive-disclosure sections mapping the `run`
/// flags. Reused by `ContainerEditSheet` for both new and edit modes. Built from the unified
/// `UI.Panel.Section` glass-card primitives (not `Form`) so it lives inside the shared `UI.Panel.Scaffold`
/// and measures/scrolls consistently. Field guidance is delivered through tappable `info.circle`
/// popovers, not hover tooltips.
struct ContainerSchemaForm: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Binding var spec: ContainerFormState
    @State private var advancedExpanded: Bool
    @State private var dockerComposeExpanded: Bool

    init(spec: Binding<ContainerFormState>) {
        self._spec = spec
        let initial = spec.wrappedValue
        self._advancedExpanded = State(initialValue: initial.hasAdvancedOptions)
        self._dockerComposeExpanded = State(initialValue: initial.hasUnsupportedRuntimeValues)
    }

    var body: some View {
        LazyVStack(spacing: UI.Layout.Spacing.l) {
            Text(AppText.string("runSpec.importedValuesHint", defaultValue: "Blue sections contain explicit values from an import, edit, template, or manual change."))
                .designSecondaryCaption()
                .frame(maxWidth: .infinity, alignment: .leading)
            UI.Panel.Section(header: AppText.string("runSpec.section.essentials", defaultValue: "Essentials"), highlighted: spec.hasGeneralOptions) { generalSection }
            UI.Panel.Section(header: AppText.string("runSpec.section.resources", defaultValue: "Resources"), highlighted: spec.hasResourceOptions) { resourcesSection }
            UI.Panel.Section(header: AppText.string("runSpec.section.networking", defaultValue: "Networking"), highlighted: spec.hasNetworkingOptions) {
                portsSection
                networkSection
                socketsSection
            }
            UI.Panel.Section(header: AppText.string("runSpec.section.storage", defaultValue: "Storage"), highlighted: spec.hasStorageOptions) { volumesSection }
            UI.Panel.Section(header: AppText.string("runSpec.section.environment", defaultValue: "Environment"), highlighted: spec.hasEnvironmentOptions) { environmentSection }
            UI.Panel.Section(header: AppText.string("runSpec.section.appManaged", defaultValue: "App Managed"), highlighted: spec.hasAppManagedOptions) {
                restartSection
                healthSection
            }
            UI.Panel.Section(header: AppText.sectionSettingsAppearance, highlighted: spec.hasPersonalizationOptions) { personalizationSection }
            advancedOptionsSection
            dockerComposeSection
        }
        .onChange(of: spec.hasAdvancedOptions) { _, hasValues in if hasValues { advancedExpanded = true } }
        .onChange(of: spec.hasUnsupportedRuntimeValues) { _, hasValues in if hasValues { dockerComposeExpanded = true } }
        .task(id: spec.normalizedImageReference) {
            guard !spec.image.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            await app.refreshImagesIfNeeded()
        }
    }

    private var generalSection: some View {
        Group {
            UI.Panel.Row(title: AppText.runtime,
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
            UI.Panel.Field(label: AppText.string("runSpec.image", defaultValue: "Image"),
                       info: fieldInfo(.imageReference),
                       error: spec.image.trimmingCharacters(in: .whitespaces).isEmpty ? AppText.string("runSpec.image.required", defaultValue: "An image reference is required.") : nil) {
                TextField("", text: $spec.image, prompt: Text("e.g. nginx:latest")).textFieldStyle(.roundedBorder)
            }
            if imageDefaults != nil {
                UI.Panel.Row(title: AppText.string("runSpec.imageDefaults", defaultValue: "Image defaults"),
                         subtitle: AppText.string("runSpec.imageDefaults.subtitle", defaultValue: "Fill empty command, entrypoint, user, working directory, and environment fields from the pulled image config."),
                         info: AppText.string("containerForm.imageDefaults.info", defaultValue: "Images can define default startup settings. Adopt copies those defaults into this form so you can see and edit them before running.")) {
                    UI.Action.TextButton(title: AppText.string("runSpec.adopt", defaultValue: "Adopt"),
                                           systemName: "wand.and.stars") {
                        adoptImageDefaults()
                    }
                }
            }
            UI.Panel.Row(title: AppText.string("runSpec.platform", defaultValue: "Platform"),
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
                UI.Panel.Field(label: AppText.string("runSpec.customPlatform", defaultValue: "Custom platform"),
                           info: fieldInfo(.imagePlatform)) {
                    TextField("", text: $spec.platform, prompt: Text("os/arch[/variant]")).textFieldStyle(.roundedBorder)
                }
            }
            UI.Panel.Field(label: fieldLabel(.imageOS, fallback: "Image OS"),
                       info: fieldInfo(.imageOS)) {
                TextField("", text: $spec.imageOS, prompt: Text("linux")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: fieldLabel(.imageArchitecture, fallback: "Image architecture"),
                       info: fieldInfo(.imageArchitecture)) {
                TextField("", text: $spec.imageArchitecture, prompt: Text("arm64")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("runSpec.name", defaultValue: "Name"),
                       info: fieldInfo(.containerName)) {
                TextField("", text: $spec.name, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("runSpec.command", defaultValue: "Command"),
                       info: fieldInfo(.processCommand)) {
                TextField("", text: $spec.command, prompt: Text("override the default command (optional)")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.ToggleRow(title: AppText.string("runSpec.detach", defaultValue: "Run in the background"),
                           info: fieldInfo(.processDetach), isOn: $spec.detach)
            UI.Panel.ToggleRow(title: AppText.string("runSpec.removeWhenStopped", defaultValue: "Remove when stopped"),
                           info: fieldInfo(.processRemoveOnExit), isOn: $spec.removeOnExit)
        }
    }

    private var resourcesSection: some View {
        Group {
            UI.Panel.Row(title: AppText.string("runSpec.cpus", defaultValue: "CPUs"),
                     info: fieldInfo(.resourcesCPULimit)) {
                Picker("", selection: cpuBinding) {
                    Text("Default").tag(0)
                    ForEach(1...max(1, hostCPUs), id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            UI.Panel.ToggleRow(title: AppText.string("runSpec.limitMemory", defaultValue: "Limit memory"),
                           info: fieldInfo(.resourcesMemoryLimit), isOn: memoryLimitBinding)
            if !spec.memory.isEmpty {
                UI.Panel.Field(label: AppText.string("runSpec.memory", defaultValue: "Memory")) {
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
            ForEach($spec.ports) { $port in
                HStack {
                    TextField("Host", text: $port.hostPort).textFieldStyle(.roundedBorder).frame(width: UI.Form.Width.port)
                    UI.Symbol.Image(systemName: "arrow.right")
                    TextField("Container", text: $port.containerPort).textFieldStyle(.roundedBorder).frame(width: UI.Form.Width.containerPort)
                    Picker("", selection: $port.proto) { Text("tcp").tag("tcp"); Text("udp").tag("udp") }
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

    private var volumesSection: some View {
        Group {
            ForEach($spec.volumes) { $vol in
                LazyVStack(spacing: UI.Layout.Spacing.xs) {
                    HStack {
                        sourcePicker(source: $vol.source)
                        TextField("Source (host path or volume)", text: $vol.source).textFieldStyle(.roundedBorder)
                        removeButton { spec.volumes.removeAll { $0.id == vol.id } }
                    }
                    HStack {
                        TextField("Target (container path)", text: $vol.target).textFieldStyle(.roundedBorder)
                        Toggle("RO", isOn: $vol.readOnly).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    }
                }
            }
            addButton(AppText.string("runSpec.addVolume", defaultValue: "Add volume"), info: fieldInfo(.storageVolumes)) {
                spec.volumes.append(VolumeMap())
            }
        }
    }

    private var environmentSection: some View {
        Group {
            ForEach($spec.env) { $variable in
                HStack {
                    TextField("KEY", text: $variable.key).textFieldStyle(.roundedBorder)
                    UI.State.StatusText("=")
                    TextField("value", text: $variable.value).textFieldStyle(.roundedBorder)
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
            ForEach($spec.sockets) { $socket in
                LazyVStack(spacing: UI.Layout.Spacing.xs) {
                    HStack {
                        TextField("Host socket path", text: $socket.hostPath).textFieldStyle(.roundedBorder)
                        removeButton { spec.sockets.removeAll { $0.id == socket.id } }
                    }
                    TextField("Container socket path", text: $socket.containerPath).textFieldStyle(.roundedBorder)
                }
            }
            addButton(AppText.string("runSpec.addSocket", defaultValue: "Add socket"), info: fieldInfo(.networkSockets)) {
                spec.sockets.append(SocketMap())
            }
        }
    }

    private var labelsSection: some View {
        Group {
            ForEach($spec.labels) { $label in
                HStack {
                    TextField("KEY", text: $label.key).textFieldStyle(.roundedBorder)
                    UI.State.StatusText("=")
                    TextField("value", text: $label.value).textFieldStyle(.roundedBorder)
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
            UI.Panel.Field(label: AppText.string("runSpec.nickname", defaultValue: "Nickname"),
                       info: AppText.string("containerForm.personalization.nickname.info", defaultValue: "A display name for the card only. It does not rename the real container.")) {
                TextField("", text: $spec.personalization.nickname, prompt: Text("display name (optional)")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("runSpec.icon", defaultValue: "Icon"),
                       info: AppText.string("containerForm.personalization.icon.info", defaultValue: "An SF Symbol name for the card icon, such as `shippingbox` or `bolt`.")) {
                TextField("", text: $spec.personalization.icon, prompt: Text("SF Symbol, e.g. globe, bolt")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Row(title: AppText.string("runSpec.color", defaultValue: "Color"),
                     info: AppText.string("containerForm.personalization.color.info", defaultValue: "Sets the card icon color. If background color is enabled, it also tints the glass card.")) {
                UI.Control.TintSelector(selection: $spec.personalization.tint) { $0.localizedDisplayName }
            }
            UI.Panel.ToggleRow(title: AppText.string("runSpec.colorCardBackground", defaultValue: "Color the card background"),
                           info: AppText.string("containerForm.personalization.colorCardBackground.info", defaultValue: "Adds a soft color wash behind the glass. Turn it off for clear glass with only a colored icon."),
                           isOn: $spec.personalization.fillBackground)
            if spec.personalization.fillBackground {
                UI.Panel.Field(label: AppText.string("runSpec.opacity", defaultValue: "Opacity")) {
                    HStack(spacing: UI.Layout.Spacing.s) {
                        Slider(value: $spec.personalization.backgroundOpacity, in: 0.05...0.6)
                        Text(Format.percent(spec.personalization.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: UI.Form.Width.shortReadout)
                    }
                }
                UI.Panel.ToggleRow(title: AppText.string("runSpec.gradient", defaultValue: "Gradient"),
                               info: AppText.string("containerForm.personalization.gradient.info", defaultValue: "Blends the color across the card instead of using one flat wash."),
                               isOn: $spec.personalization.gradient)
                if spec.personalization.gradient {
                    UI.Control.GradientAngle(angle: $spec.personalization.gradientAngle, title: AppText.direction)
                }
                UI.Panel.Row(title: AppText.string("runSpec.blendMode", defaultValue: "Blend mode"),
                         info: AppText.string("containerForm.personalization.blendMode.info", defaultValue: "Controls how the card color wash blends with the glass behind it.")) {
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
        UI.Panel.Row(title: AppText.string("runSpec.restartPolicy", defaultValue: "Restart policy"),
                 info: AppText.string("containerForm.restartPolicy.info", defaultValue: "Contained restarts the container automatically based on this setting.")) {
            Picker("", selection: $spec.restart) {
                ForEach(Core.Container.RestartPolicy.allCases) { Text($0.localizedDisplayName).tag($0) }
            }
            .labelsHidden().fixedSize()
        }
    }

    private var healthSection: some View {
        Group {
            UI.Panel.ToggleRow(title: AppText.string("runSpec.enableHealthcheck", defaultValue: "Enable healthcheck"),
                           info: AppText.string("containerForm.healthcheck.enabled.info", defaultValue: "Contained probes the container on an interval (app-managed; the runtime has no native healthcheck)."),
                           isOn: $spec.healthCheck.enabled)
            if spec.healthCheck.enabled {
                UI.Panel.Field(label: AppText.string("runSpec.probeCommand", defaultValue: "Probe command"),
                           info: AppText.string("containerForm.healthcheck.probeCommand.info", defaultValue: "Run inside the container via `sh -c`; a zero exit = healthy. Needs a shell in the image.")) {
                    TextField("", text: healthCommandBinding, prompt: Text("curl -f http://localhost/ || exit 1")).textFieldStyle(.roundedBorder)
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
            UI.Panel.Field(label: AppText.string("runSpec.entrypoint", defaultValue: "Entrypoint"),
                       info: fieldInfo(.processEntrypoint)) {
                TextField("", text: $spec.entrypoint, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.ToggleRow(title: AppText.string("runSpec.keepStdinOpen", defaultValue: "Keep stdin open"),
                           info: fieldInfo(.processInteractive), isOn: $spec.interactive)
            UI.Panel.ToggleRow(title: AppText.string("runSpec.allocateTTY", defaultValue: "Allocate TTY"),
                           info: fieldInfo(.processTTY), isOn: $spec.tty)
            UI.Panel.Field(label: AppText.string("runSpec.workingDirectory", defaultValue: "Working directory"),
                       info: fieldInfo(.processWorkingDirectory)) {
                TextField("", text: $spec.workingDir, prompt: Text("optional, e.g. /app")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("runSpec.user", defaultValue: "User"),
                       info: fieldInfo(.processUser)) {
                TextField("", text: $spec.user, prompt: Text("name | uid[:gid]")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("runSpec.userID", defaultValue: "User ID"),
                       info: "\(fieldInfo(.processUserID))\n\n\(fieldInfo(.processGroupID))") {
                HStack {
                    TextField("UID", text: $spec.uid).textFieldStyle(.roundedBorder).frame(width: UI.Form.Width.userID)
                    TextField("GID", text: $spec.gid).textFieldStyle(.roundedBorder).frame(width: UI.Form.Width.userID)
                    Spacer()
                }
            }
            UI.Panel.ToggleRow(title: AppText.string("runSpec.setSharedMemorySize", defaultValue: "Set shared memory size"),
                           info: fieldInfo(.resourcesSharedMemorySize), isOn: shmLimitBinding)
            if !spec.shmSize.isEmpty {
                UI.Panel.Field(label: AppText.string("runSpec.sharedMemory", defaultValue: "Shared memory")) {
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
            UI.Panel.Field(label: AppText.string("runSpec.containerIDFile", defaultValue: "Container ID file"),
                       info: fieldInfo(.outputContainerIDFile)) {
                TextField("", text: $spec.cidFile, prompt: Text("optional path")).textFieldStyle(.roundedBorder)
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
            UI.Panel.ToggleRow(title: AppText.string("runSpec.readOnlyFilesystem", defaultValue: "Read-only filesystem"),
                           info: fieldInfo(.securityReadOnlyRootFS), isOn: $spec.readOnly)
            UI.Panel.ToggleRow(title: AppText.string("runSpec.useInitProcess", defaultValue: "Use an init process"),
                           info: fieldInfo(.securityUseInit), isOn: $spec.useInit)
            UI.Panel.ToggleRow(title: AppText.string("runSpec.rosetta", defaultValue: "Rosetta (x86 apps)"),
                           info: fieldInfo(.securityRosetta), isOn: $spec.rosetta)
            UI.Panel.ToggleRow(title: AppText.string("runSpec.forwardSSHAgent", defaultValue: "Forward SSH agent"),
                           info: fieldInfo(.securitySSHAgent), isOn: $spec.ssh)
            UI.Panel.ToggleRow(title: AppText.string("runSpec.exposeVirtualization", defaultValue: "Expose virtualization"),
                           info: fieldInfo(.securityVirtualization), isOn: $spec.virtualization)
        }
    }

    @ViewBuilder
    private var networkSection: some View {
        UI.Panel.Row(title: AppText.string("runSpec.network", defaultValue: "Network"),
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
            TextField("", text: $spec.network, prompt: Text("custom network")).textFieldStyle(.roundedBorder)
                .frame(width: UI.Form.Width.networkName)
        }
        .task { await app.refreshNetworks() }
    }

    @ViewBuilder
    private var fetchSection: some View {
        Group {
            UI.Panel.Field(label: AppText.string("runSpec.runtime", defaultValue: "Runtime"),
                       info: fieldInfo(.runtimeHandler)) {
                TextField("", text: $spec.runtime, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("runSpec.initImage", defaultValue: "Init image"),
                       info: fieldInfo(.imageInitReference)) {
                TextField("", text: $spec.initImage, prompt: Text("optional image")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Field(label: AppText.string("runSpec.kernel", defaultValue: "Kernel"),
                       info: fieldInfo(.kernelPath)) {
                TextField("", text: $spec.kernel, prompt: Text("optional path")).textFieldStyle(.roundedBorder)
            }
            UI.Panel.Row(title: AppText.string("runSpec.registryScheme", defaultValue: "Registry scheme"),
                     info: fieldInfo(.registryScheme)) {
                Picker("", selection: $spec.scheme) {
                    Text("Default").tag("")
                    Text("Auto").tag("auto")
                    Text("HTTPS").tag("https")
                    Text("HTTP").tag("http")
                }
                .labelsHidden().fixedSize()
            }
            UI.Panel.Row(title: AppText.string("runSpec.progress", defaultValue: "Progress"),
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
            UI.Panel.ToggleRow(title: AppText.string("runSpec.limitParallelDownloads", defaultValue: "Limit parallel downloads"),
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
            UI.Panel.ToggleRow(title: AppText.string("runSpec.disableDNS", defaultValue: "Disable DNS"),
                           info: fieldInfo(.networkDNSDisabled), isOn: $spec.noDNS)
            if !spec.noDNS {
                stringList(AppText.string("runSpec.addNameserver", defaultValue: "Add nameserver"), $spec.dns, prompt: "1.1.1.1",
                           info: fieldInfo(.networkDNSServers))
                UI.Panel.Field(label: AppText.string("runSpec.searchDomain", defaultValue: "Search domain"),
                           info: fieldInfo(.networkDNSDomain)) {
                    TextField("", text: $spec.dnsDomain, prompt: Text("optional")).textFieldStyle(.roundedBorder)
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
        // The header switch shows/hides the less-common run settings (Compose import and Edit flip it on
        // automatically when advanced values are present).
        UI.Panel.Section(header: AppText.string("runSpec.section.advancedOptions", defaultValue: "Advanced Options"),
                     footer: AppText.string("runSpec.section.advancedOptions.footer", defaultValue: "Less-common run settings. Compose import and Edit reveal these automatically when advanced values are present."),
                     highlighted: spec.hasAdvancedOptions,
                     enabled: $advancedExpanded) {
            runtimeSection
            securitySection
            fetchSection
            dnsSection
            stringList(AppText.string("runSpec.addMount", defaultValue: "Add mount"), $spec.mounts, prompt: "type=bind,source=/host,target=/container",
                       info: fieldInfo(.storageMounts))
            labelsSection
        }
    }

    @ViewBuilder
    private var dockerComposeSection: some View {
        let fields = unsupportedFields
        if !fields.isEmpty {
            UI.Panel.Section(header: AppText.string("runSpec.section.dockerCompose", defaultValue: "Docker & Compose"),
                         footer: AppText.string("runSpec.section.dockerCompose.footer", defaultValue: "Known Docker CLI and Compose fields preserved for future cores. Apple container cannot execute these values."),
                         highlighted: spec.hasUnsupportedRuntimeValues,
                         enabled: $dockerComposeExpanded) {
                ForEach(fields) { field in
                    UI.Panel.Field(label: fieldLabel(field),
                               info: fieldInfo(field.path),
                               error: field.support(for: spec.effectiveRuntimeKind).localizedDisabledReason()) {
                        Text(valueDescription(for: field))
                            .designSecondaryCallout()
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
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
                TextField(prompt, text: Binding(get: { list.wrappedValue[idx] },
                                                set: { list.wrappedValue[idx] = $0 }))
                    .textFieldStyle(.roundedBorder)
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

    private func removeButton(action: @escaping () -> Void) -> some View {
        UI.Action.Group(UI.Action.Item(systemName: "minus.circle.fill",
                                       help: AppText.string("common.remove", defaultValue: "Remove"),
                                       action: action))
    }

    private func sourcePicker(source: Binding<String>) -> some View {
        Menu {
            Button {
                pickHostSource(into: source)
            } label: {
                Label(AppText.string("runSpec.chooseFileOrFolder", defaultValue: "Choose File or Folder..."), systemImage: "folder")
            }
            if !app.volumes.isEmpty {
                Divider()
                ForEach(app.volumes) { volume in
                    Button {
                        source.wrappedValue = volume.name
                    } label: {
                        Label(volume.name, systemImage: source.wrappedValue == volume.name ? "checkmark" : "externaldrive")
                    }
                }
            }
            Divider()
            Button {
                ui.dispatch(.createVolume)
            } label: {
                Label(AppText.string("runSpec.createNewVolume", defaultValue: "Create New Volume..."), systemImage: "plus")
            }
        } label: {
            Image(systemName: "folder.badge.gearshape")
        }
        .buttonStyle(.borderless)
        .help(AppText.string("runSpec.sourcePicker.help", defaultValue: "Choose a host path, existing volume, or create a new volume"))
        .task { await app.refreshVolumes() }
    }

    private func pickHostSource(into source: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = AppText.chooseHostFileOrFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        source.wrappedValue = url.path
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
