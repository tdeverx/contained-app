import SwiftUI
import ContainedNavigation
import ContainedDesignSystem
import AppKit
import ContainedCore

/// The shared container Create/Edit form body: progressive-disclosure sections mapping the `run`
/// flags. Reused by `ContainerEditSheet` for both new and edit modes. Built from the unified
/// `PanelSection` glass-card primitives (not `Form`) so it lives inside the shared `DesignPanelScaffold`
/// and measures/scrolls consistently. Field guidance is delivered through tappable `info.circle`
/// popovers, not hover tooltips.
struct RunSpecForm: View {
    @Environment(AppModel.self) private var app
    @Environment(UIState.self) private var ui
    @Binding var spec: RunSpec
    @State private var advancedExpanded: Bool

    init(spec: Binding<RunSpec>) {
        self._spec = spec
        let initial = spec.wrappedValue
        self._advancedExpanded = State(initialValue: initial.hasAdvancedOptions)
    }

    var body: some View {
        LazyVStack(spacing: DesignTokens.Space.l) {
            Text(AppText.string("runSpec.importedValuesHint", defaultValue: "Blue sections contain explicit values from an import, edit, template, or manual change."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            PanelSection(header: AppText.string("runSpec.section.essentials", defaultValue: "Essentials"), highlighted: spec.hasGeneralOptions) { generalSection }
            PanelSection(header: AppText.string("runSpec.section.resources", defaultValue: "Resources"), highlighted: spec.hasResourceOptions) { resourcesSection }
            PanelSection(header: AppText.string("runSpec.section.networking", defaultValue: "Networking"), highlighted: spec.hasNetworkingOptions) {
                portsSection
                networkSection
                socketsSection
            }
            PanelSection(header: AppText.string("runSpec.section.storage", defaultValue: "Storage"), highlighted: spec.hasStorageOptions) { volumesSection }
            PanelSection(header: AppText.string("runSpec.section.environment", defaultValue: "Environment"), highlighted: spec.hasEnvironmentOptions) { environmentSection }
            PanelSection(header: AppText.string("runSpec.section.appManaged", defaultValue: "App Managed"), highlighted: spec.hasAppManagedOptions) {
                restartSection
                healthSection
            }
            PanelSection(header: AppText.sectionSettingsAppearance, highlighted: spec.hasPersonalizationOptions) { personalizationSection }
            advancedOptionsSection
        }
        .onChange(of: spec.hasAdvancedOptions) { _, hasValues in if hasValues { advancedExpanded = true } }
        .task(id: spec.normalizedImageReference) {
            guard !spec.image.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            await app.refreshImagesIfStale()
        }
    }

    private var generalSection: some View {
        Group {
            PanelRow(title: AppText.runtimeCore,
                     subtitle: app.runtimeCoreSelectorIsEnabled ? AppText.runtimeCoreSubtitle : app.runtimeCoreSelectorDisabledReason) {
                Picker("", selection: runtimeKindBinding) {
                    ForEach(app.availableRuntimeDescriptors, id: \.kind) { descriptor in
                        Text(descriptor.displayName).tag(descriptor.kind)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!app.runtimeCoreSelectorIsEnabled)
            }
            PanelField(label: AppText.string("runSpec.image", defaultValue: "Image"),
                       info: AppText.string("runSpec.image.info", defaultValue: "The container image to start, such as `nginx:latest`. If it is not on this Mac yet, Contained pulls it before running."),
                       error: spec.image.trimmingCharacters(in: .whitespaces).isEmpty ? AppText.string("runSpec.image.required", defaultValue: "An image reference is required.") : nil) {
                TextField("", text: $spec.image, prompt: Text("e.g. nginx:latest")).textFieldStyle(.roundedBorder)
            }
            if imageDefaults != nil {
                PanelRow(title: AppText.string("runSpec.imageDefaults", defaultValue: "Image defaults"),
                         subtitle: AppText.string("runSpec.imageDefaults.subtitle", defaultValue: "Fill empty command, entrypoint, user, working directory, and environment fields from the pulled image config."),
                         info: AppText.string("runSpec.imageDefaults.info", defaultValue: "Images can define default startup settings. Adopt copies those defaults into this form so you can see and edit them before running.")) {
                    DesignTextActionButton(title: AppText.string("runSpec.adopt", defaultValue: "Adopt"),
                                           systemName: "wand.and.stars") {
                        adoptImageDefaults()
                    }
                }
            }
            PanelRow(title: AppText.string("runSpec.platform", defaultValue: "Platform"),
                     info: AppText.string("runSpec.platform.info", defaultValue: "Use this only when an image supports more than one CPU type. Leave Default unless you specifically need arm64 or amd64.")) {
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
                PanelField(label: AppText.string("runSpec.customPlatform", defaultValue: "Custom platform"),
                           info: AppText.string("runSpec.customPlatform.info", defaultValue: "Advanced platform value in `os/arch` form, for example `linux/arm64`.")) {
                    TextField("", text: $spec.platform, prompt: Text("os/arch[/variant]")).textFieldStyle(.roundedBorder)
                }
            }
            PanelField(label: AppText.string("runSpec.name", defaultValue: "Name"),
                       info: AppText.string("runSpec.name.info", defaultValue: "Optional friendly runtime name. Leave it blank and the container runtime will generate one.")) {
                TextField("", text: $spec.name, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: AppText.string("runSpec.command", defaultValue: "Command"),
                       info: AppText.string("runSpec.command.info", defaultValue: "Optional command to run instead of the image's normal startup command.")) {
                TextField("", text: $spec.command, prompt: Text("override the default command (optional)")).textFieldStyle(.roundedBorder)
            }
            PanelToggleRow(title: AppText.string("runSpec.detach", defaultValue: "Run in the background"),
                           info: AppText.string("runSpec.detach.info", defaultValue: "Detached (-d): runs without attaching to its output."), isOn: $spec.detach)
            PanelToggleRow(title: AppText.string("runSpec.removeWhenStopped", defaultValue: "Remove when stopped"),
                           info: AppText.string("runSpec.removeWhenStopped.info", defaultValue: "Deletes the container record when it stops. Use volumes if you need data to survive."), isOn: $spec.removeOnExit)
        }
    }

    private var resourcesSection: some View {
        Group {
            PanelRow(title: AppText.string("runSpec.cpus", defaultValue: "CPUs"),
                     info: AppText.string("runSpec.cpus.info", defaultValue: "Limit how much CPU the container can use. Default lets the runtime decide. This Mac has \(hostCPUs) cores.")) {
                Picker("", selection: cpuBinding) {
                    Text("Default").tag(0)
                    ForEach(1...max(1, hostCPUs), id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            PanelToggleRow(title: AppText.string("runSpec.limitMemory", defaultValue: "Limit memory"),
                           info: AppText.string("runSpec.limitMemory.info", defaultValue: "Set a memory ceiling for the container. If it goes past the limit, the runtime may stop it."), isOn: memoryLimitBinding)
            if !spec.memory.isEmpty {
                PanelField(label: AppText.string("runSpec.memory", defaultValue: "Memory")) {
                    HStack(spacing: DesignTokens.Space.s) {
                        Slider(value: memoryGBBinding, in: 0.5...max(0.5, maxMemoryGB), step: 0.5)
                        Text(memoryReadout).monospacedDigit().frame(width: DesignTokens.FormWidth.memoryReadout)
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
        RunSpecMemoryFormatter.readout(spec, fallbackGB: fallbackGB)
    }

    private var platformPresetBinding: Binding<String> {
        let presets = Set(["", "linux/arm64", "linux/amd64", "linux/amd64/v2"])
        return Binding(get: { presets.contains(spec.platform) ? spec.platform : "custom" },
                       set: { if $0 != "custom" { spec.platform = $0 } })
    }

    private var imageDefaults: ContainerImageDefaults? {
        app.imageDefaults(for: spec)
    }

    private var runtimeKindBinding: Binding<RuntimeKind> {
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
        RunSpecMemoryFormatter.parseGB(spec)
    }

    static func memorySpec(gb: Double) -> String {
        RunSpecMemoryFormatter.spec(gb: gb)
    }

    private var portsSection: some View {
        Group {
            ForEach($spec.ports) { $port in
                HStack {
                    TextField("Host", text: $port.hostPort).textFieldStyle(.roundedBorder).frame(width: DesignTokens.FormWidth.port)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("Container", text: $port.containerPort).textFieldStyle(.roundedBorder).frame(width: DesignTokens.FormWidth.containerPort)
                    Picker("", selection: $port.proto) { Text("tcp").tag("tcp"); Text("udp").tag("udp") }
                        .labelsHidden().frame(width: DesignTokens.FormWidth.port)
                    Spacer()
                    removeButton { spec.ports.removeAll { $0.id == port.id } }
                }
            }
            addButton(AppText.string("runSpec.addPort", defaultValue: "Add port")) { spec.ports.append(PortMap()) }
        }
    }

    private var volumesSection: some View {
        Group {
            ForEach($spec.volumes) { $vol in
                LazyVStack(spacing: DesignTokens.Space.xs) {
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
            addButton(AppText.string("runSpec.addVolume", defaultValue: "Add volume")) { spec.volumes.append(VolumeMap()) }
        }
    }

    private var environmentSection: some View {
        Group {
            ForEach($spec.env) { $variable in
                HStack {
                    TextField("KEY", text: $variable.key).textFieldStyle(.roundedBorder)
                    Text("=").foregroundStyle(.secondary)
                    TextField("value", text: $variable.value).textFieldStyle(.roundedBorder)
                    removeButton { spec.env.removeAll { $0.id == variable.id } }
                }
            }
            addButton(AppText.string("runSpec.addVariable", defaultValue: "Add variable")) { spec.env.append(KeyValue()) }
            stringList(AppText.string("runSpec.addEnvFile", defaultValue: "Add env file"), $spec.envFiles, prompt: "/path/to/.env",
                       info: AppText.string("runSpec.addEnvFile.info", defaultValue: "Read environment variables from a file (--env-file)."))
        }
    }

    private var socketsSection: some View {
        Group {
            ForEach($spec.sockets) { $socket in
                LazyVStack(spacing: DesignTokens.Space.xs) {
                    HStack {
                        TextField("Host socket path", text: $socket.hostPath).textFieldStyle(.roundedBorder)
                        removeButton { spec.sockets.removeAll { $0.id == socket.id } }
                    }
                    TextField("Container socket path", text: $socket.containerPath).textFieldStyle(.roundedBorder)
                }
            }
            addButton(AppText.string("runSpec.addSocket", defaultValue: "Add socket")) { spec.sockets.append(SocketMap()) }
        }
    }

    private var labelsSection: some View {
        Group {
            ForEach($spec.labels) { $label in
                HStack {
                    TextField("KEY", text: $label.key).textFieldStyle(.roundedBorder)
                    Text("=").foregroundStyle(.secondary)
                    TextField("value", text: $label.value).textFieldStyle(.roundedBorder)
                    removeButton { spec.labels.removeAll { $0.id == label.id } }
                }
            }
            addButton(AppText.string("runSpec.addLabel", defaultValue: "Add label")) { spec.labels.append(KeyValue()) }
        }
    }

    private var personalizationSection: some View {
        Group {
            PanelField(label: AppText.string("runSpec.nickname", defaultValue: "Nickname"),
                       info: AppText.string("runSpec.nickname.info", defaultValue: "A display name for the card only. It does not rename the real container.")) {
                TextField("", text: $spec.personalization.nickname, prompt: Text("display name (optional)")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: AppText.string("runSpec.icon", defaultValue: "Icon"),
                       info: AppText.string("runSpec.icon.info", defaultValue: "An SF Symbol name for the card icon, such as `shippingbox` or `bolt`.")) {
                TextField("", text: $spec.personalization.icon, prompt: Text("SF Symbol, e.g. globe, bolt")).textFieldStyle(.roundedBorder)
            }
            PanelRow(title: AppText.string("runSpec.color", defaultValue: "Color"),
                     info: AppText.string("runSpec.color.info", defaultValue: "Sets the card icon color. If background color is enabled, it also tints the glass card.")) {
                TintSelector(selection: $spec.personalization.tint) { $0.localizedDisplayName }
            }
            PanelToggleRow(title: AppText.string("runSpec.colorCardBackground", defaultValue: "Color the card background"),
                           info: AppText.string("runSpec.colorCardBackground.info", defaultValue: "Adds a soft color wash behind the glass. Turn it off for clear glass with only a colored icon."),
                           isOn: $spec.personalization.fillBackground)
            if spec.personalization.fillBackground {
                PanelField(label: AppText.string("runSpec.opacity", defaultValue: "Opacity")) {
                    HStack(spacing: DesignTokens.Space.s) {
                        Slider(value: $spec.personalization.backgroundOpacity, in: 0.05...0.6)
                        Text(Format.percent(spec.personalization.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: DesignTokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: AppText.string("runSpec.gradient", defaultValue: "Gradient"),
                               info: AppText.string("runSpec.gradient.info", defaultValue: "Blends the color across the card instead of using one flat wash."),
                               isOn: $spec.personalization.gradient)
                if spec.personalization.gradient {
                    GradientAngleControl(angle: $spec.personalization.gradientAngle, title: AppText.direction)
                }
                PanelRow(title: AppText.string("runSpec.blendMode", defaultValue: "Blend mode"),
                         info: AppText.string("runSpec.blendMode.info", defaultValue: "Controls how the card color wash blends with the glass behind it.")) {
                    Picker("", selection: $spec.personalization.backgroundBlendMode) {
                        ForEach(ColorLayerBlendMode.allCases) { mode in
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
        PanelRow(title: AppText.string("runSpec.restartPolicy", defaultValue: "Restart policy"),
                 info: AppText.string("runSpec.restartPolicy.info", defaultValue: "Contained restarts the container automatically based on this setting.")) {
            Picker("", selection: $spec.restart) {
                ForEach(RestartPolicy.allCases) { Text($0.localizedDisplayName).tag($0) }
            }
            .labelsHidden().fixedSize()
        }
    }

    private var healthSection: some View {
        Group {
            PanelToggleRow(title: AppText.string("runSpec.enableHealthcheck", defaultValue: "Enable healthcheck"),
                           info: AppText.string("runSpec.enableHealthcheck.info", defaultValue: "Contained probes the container on an interval (app-managed; the runtime has no native healthcheck)."),
                           isOn: $spec.healthCheck.enabled)
            if spec.healthCheck.enabled {
                PanelField(label: AppText.string("runSpec.probeCommand", defaultValue: "Probe command"),
                           info: AppText.string("runSpec.probeCommand.info", defaultValue: "Run inside the container via `sh -c`; a zero exit = healthy. Needs a shell in the image.")) {
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
            PanelField(label: AppText.string("runSpec.entrypoint", defaultValue: "Entrypoint"),
                       info: AppText.string("runSpec.entrypoint.info", defaultValue: "Override the image's entrypoint program.")) {
                TextField("", text: $spec.entrypoint, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            PanelToggleRow(title: AppText.string("runSpec.keepStdinOpen", defaultValue: "Keep stdin open"),
                           info: AppText.string("runSpec.keepStdinOpen.info", defaultValue: "Keep standard input open even when detached (--interactive)."), isOn: $spec.interactive)
            PanelToggleRow(title: AppText.string("runSpec.allocateTTY", defaultValue: "Allocate TTY"),
                           info: AppText.string("runSpec.allocateTTY.info", defaultValue: "Allocate a terminal for the process (--tty)."), isOn: $spec.tty)
            PanelField(label: AppText.string("runSpec.workingDirectory", defaultValue: "Working directory"),
                       info: AppText.string("runSpec.workingDirectory.info", defaultValue: "Initial working directory inside the container (-w).")) {
                TextField("", text: $spec.workingDir, prompt: Text("optional, e.g. /app")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: AppText.string("runSpec.user", defaultValue: "User"),
                       info: AppText.string("runSpec.user.info", defaultValue: "Run the process as this user (-u). Or set UID/GID below.")) {
                TextField("", text: $spec.user, prompt: Text("name | uid[:gid]")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: AppText.string("runSpec.userID", defaultValue: "User ID"),
                       info: AppText.string("runSpec.userID.info", defaultValue: "Numeric user / group IDs (--uid / --gid).")) {
                HStack {
                    TextField("UID", text: $spec.uid).textFieldStyle(.roundedBorder).frame(width: DesignTokens.FormWidth.userID)
                    TextField("GID", text: $spec.gid).textFieldStyle(.roundedBorder).frame(width: DesignTokens.FormWidth.userID)
                    Spacer()
                }
            }
            PanelToggleRow(title: AppText.string("runSpec.setSharedMemorySize", defaultValue: "Set shared memory size"),
                           info: AppText.string("runSpec.setSharedMemorySize.info", defaultValue: "Size of /dev/shm (--shm-size)."), isOn: shmLimitBinding)
            if !spec.shmSize.isEmpty {
                PanelField(label: AppText.string("runSpec.sharedMemory", defaultValue: "Shared memory")) {
                    HStack(spacing: DesignTokens.Space.s) {
                        Slider(value: shmGBBinding, in: 0.0625...max(0.0625, maxMemoryGB), step: 0.0625)
                        Text(memoryReadout(spec.shmSize, fallbackGB: 0.0625))
                            .monospacedDigit()
                            .frame(width: DesignTokens.FormWidth.memoryReadout)
                    }
                }
            }

            stringList(AppText.string("runSpec.addCapability", defaultValue: "Add capability"), $spec.capAdd, prompt: "CAP_NET_RAW or ALL",
                       info: AppText.string("runSpec.addCapability.info", defaultValue: "Add a Linux capability (--cap-add)."))
            stringList(AppText.string("runSpec.dropCapability", defaultValue: "Drop capability"), $spec.capDrop, prompt: "CAP_NET_RAW or ALL",
                       info: AppText.string("runSpec.dropCapability.info", defaultValue: "Drop a Linux capability (--cap-drop)."))
            PanelField(label: AppText.string("runSpec.containerIDFile", defaultValue: "Container ID file"),
                       info: AppText.string("runSpec.containerIDFile.info", defaultValue: "Write the new container ID to a file (--cidfile).")) {
                TextField("", text: $spec.cidFile, prompt: Text("optional path")).textFieldStyle(.roundedBorder)
            }
            stringList(AppText.string("runSpec.addTmpfsMount", defaultValue: "Add tmpfs mount"), $spec.tmpfs, prompt: "/path",
                       info: AppText.string("runSpec.addTmpfsMount.info", defaultValue: "Mount a tmpfs at this path (--tmpfs)."))
            stringList(AppText.string("runSpec.addUlimit", defaultValue: "Add ulimit"), $spec.ulimits, prompt: "nofile=1024:2048",
                       info: AppText.string("runSpec.addUlimit.info", defaultValue: "Resource limit, type=soft[:hard] (--ulimit)."))
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Group {
            PanelToggleRow(title: AppText.string("runSpec.readOnlyFilesystem", defaultValue: "Read-only filesystem"),
                           info: AppText.string("runSpec.readOnlyFilesystem.info", defaultValue: "Mounts the container's root filesystem as read-only."), isOn: $spec.readOnly)
            PanelToggleRow(title: AppText.string("runSpec.useInitProcess", defaultValue: "Use an init process"),
                           info: AppText.string("runSpec.useInitProcess.info", defaultValue: "Runs a tiny init that forwards signals and cleans up zombie processes."), isOn: $spec.useInit)
            PanelToggleRow(title: AppText.string("runSpec.rosetta", defaultValue: "Rosetta (x86 apps)"),
                           info: AppText.string("runSpec.rosetta.info", defaultValue: "Lets the container run x86-64 binaries via Rosetta."), isOn: $spec.rosetta)
            PanelToggleRow(title: AppText.string("runSpec.forwardSSHAgent", defaultValue: "Forward SSH agent"),
                           info: AppText.string("runSpec.forwardSSHAgent.info", defaultValue: "Forwards your host SSH agent into the container."), isOn: $spec.ssh)
            PanelToggleRow(title: AppText.string("runSpec.exposeVirtualization", defaultValue: "Expose virtualization"),
                           info: AppText.string("runSpec.exposeVirtualization.info", defaultValue: "Exposes nested virtualization (needs host + guest support)."), isOn: $spec.virtualization)
        }
    }

    @ViewBuilder
    private var networkSection: some View {
        PanelRow(title: AppText.string("runSpec.network", defaultValue: "Network"),
                 info: AppText.string("runSpec.network.info", defaultValue: "Attach the container to a network (--network).")) {
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
                .frame(width: DesignTokens.FormWidth.networkName)
        }
        .task { await app.refreshNetworks() }
    }

    @ViewBuilder
    private var fetchSection: some View {
        Group {
            PanelField(label: AppText.string("runSpec.runtime", defaultValue: "Runtime"),
                       info: AppText.string("runSpec.runtime.info", defaultValue: "Runtime handler (--runtime).")) {
                TextField("", text: $spec.runtime, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: AppText.string("runSpec.initImage", defaultValue: "Init image"),
                       info: AppText.string("runSpec.initImage.info", defaultValue: "Use a custom init image (--init-image).")) {
                TextField("", text: $spec.initImage, prompt: Text("optional image")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: AppText.string("runSpec.kernel", defaultValue: "Kernel"),
                       info: AppText.string("runSpec.kernel.info", defaultValue: "Use a custom kernel path (--kernel).")) {
                TextField("", text: $spec.kernel, prompt: Text("optional path")).textFieldStyle(.roundedBorder)
            }
            PanelRow(title: AppText.string("runSpec.registryScheme", defaultValue: "Registry scheme"),
                     info: AppText.string("runSpec.registryScheme.info", defaultValue: "Registry connection scheme for image fetches (--scheme).")) {
                Picker("", selection: $spec.scheme) {
                    Text("Default").tag("")
                    Text("Auto").tag("auto")
                    Text("HTTPS").tag("https")
                    Text("HTTP").tag("http")
                }
                .labelsHidden().fixedSize()
            }
            PanelRow(title: AppText.string("runSpec.progress", defaultValue: "Progress"),
                     info: AppText.string("runSpec.progress.info", defaultValue: "Progress display mode for image fetches (--progress).")) {
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
            PanelToggleRow(title: AppText.string("runSpec.limitParallelDownloads", defaultValue: "Limit parallel downloads"),
                           info: AppText.string("runSpec.limitParallelDownloads.info", defaultValue: "Maximum concurrent image downloads (--max-concurrent-downloads)."), isOn: maxDownloadsBinding)
            if !spec.maxConcurrentDownloads.isEmpty {
                Stepper("Max downloads: \(maxConcurrentDownloadsBinding.wrappedValue)",
                        value: maxConcurrentDownloadsBinding, in: 1...16)
            }
        }
    }

    @ViewBuilder
    private var dnsSection: some View {
        Group {
            PanelToggleRow(title: AppText.string("runSpec.disableDNS", defaultValue: "Disable DNS"),
                           info: AppText.string("runSpec.disableDNS.info", defaultValue: "Do not configure DNS inside the container (--no-dns)."), isOn: $spec.noDNS)
            if !spec.noDNS {
                stringList(AppText.string("runSpec.addNameserver", defaultValue: "Add nameserver"), $spec.dns, prompt: "1.1.1.1",
                           info: AppText.string("runSpec.addNameserver.info", defaultValue: "DNS nameserver IP (--dns)."))
                PanelField(label: AppText.string("runSpec.searchDomain", defaultValue: "Search domain"),
                           info: AppText.string("runSpec.searchDomain.info", defaultValue: "Default DNS domain (--dns-domain).")) {
                    TextField("", text: $spec.dnsDomain, prompt: Text("optional")).textFieldStyle(.roundedBorder)
                }
                stringList(AppText.string("runSpec.addSearchDomain", defaultValue: "Add search domain"), $spec.dnsSearch, prompt: "example.com",
                           info: AppText.string("runSpec.addSearchDomain.info", defaultValue: "DNS search domain (--dns-search)."))
                stringList(AppText.string("runSpec.addDNSOption", defaultValue: "Add DNS option"), $spec.dnsOption, prompt: "ndots:2",
                           info: AppText.string("runSpec.addDNSOption.info", defaultValue: "DNS resolver option (--dns-option)."))
            }
        }
    }

    @ViewBuilder
    private var advancedOptionsSection: some View {
        // The header switch shows/hides the less-common run settings (Compose import and Edit flip it on
        // automatically when advanced values are present).
        PanelSection(header: AppText.string("runSpec.section.advancedOptions", defaultValue: "Advanced Options"),
                     footer: AppText.string("runSpec.section.advancedOptions.footer", defaultValue: "Less-common run settings. Compose import and Edit reveal these automatically when advanced values are present."),
                     highlighted: spec.hasAdvancedOptions,
                     enabled: $advancedExpanded) {
            runtimeSection
            securitySection
            fetchSection
            dnsSection
            stringList(AppText.string("runSpec.addMount", defaultValue: "Add mount"), $spec.mounts, prompt: "type=bind,source=/host,target=/container",
                       info: AppText.string("runSpec.addMount.info", defaultValue: "Raw mount spec for advanced mount types (--mount)."))
            labelsSection
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
        HStack(spacing: DesignTokens.Space.s) {
            addButton(addTitle) { list.wrappedValue.append("") }
            InfoButton(info)
            Spacer()
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        DesignActionGroup(DesignAction(systemName: "plus.circle",
                                       title: title,
                                       help: title,
                                       action: action))
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        DesignActionGroup(DesignAction(systemName: "minus.circle.fill",
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
}
