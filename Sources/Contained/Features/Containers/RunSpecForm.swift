import SwiftUI
import AppKit
import ContainedCore

/// The shared container Create/Edit form body: progressive-disclosure sections mapping the `run`
/// flags. Reused by `ContainerEditSheet` for both new and edit modes. Built from the unified
/// `PanelSection` glass-card primitives (not `Form`) so it lives inside the shared `MorphPanelScaffold`
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
        VStack(spacing: Tokens.Space.l) {
            Text("Blue sections contain explicit values from an import, edit, template, or manual change.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            PanelSection(header: "Essentials", highlighted: spec.hasGeneralOptions) { generalSection }
            PanelSection(header: "Resources", highlighted: spec.hasResourceOptions) { resourcesSection }
            PanelSection(header: "Networking", highlighted: spec.hasNetworkingOptions) {
                portsSection
                networkSection
                socketsSection
            }
            PanelSection(header: "Storage", highlighted: spec.hasStorageOptions) { volumesSection }
            PanelSection(header: "Environment", highlighted: spec.hasEnvironmentOptions) { environmentSection }
            PanelSection(header: "App Managed", highlighted: spec.hasAppManagedOptions) {
                restartSection
                healthSection
            }
            PanelSection(header: "Appearance", highlighted: spec.hasPersonalizationOptions) { personalizationSection }
            advancedOptionsSection
        }
        .onChange(of: spec.hasAdvancedOptions) { _, hasValues in if hasValues { advancedExpanded = true } }
    }

    private var generalSection: some View {
        Group {
            PanelField(label: "Image",
                       info: "The image to run, repo:tag. Pulled automatically if not present locally.",
                       error: spec.image.trimmingCharacters(in: .whitespaces).isEmpty ? "An image reference is required." : nil) {
                TextField("", text: $spec.image, prompt: Text("e.g. nginx:latest")).textFieldStyle(.roundedBorder)
            }
            PanelRow(title: "Platform", info: "Select an image platform when the image is multi-platform (--platform).") {
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
                PanelField(label: "Custom platform", info: "Custom platform string passed to --platform.") {
                    TextField("", text: $spec.platform, prompt: Text("os/arch[/variant]")).textFieldStyle(.roundedBorder)
                }
            }
            PanelField(label: "Name", info: "A stable name for the container. Leave blank for a generated one.") {
                TextField("", text: $spec.name, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: "Command", info: "Arguments passed to the image, replacing its default command.") {
                TextField("", text: $spec.command, prompt: Text("override the default command (optional)")).textFieldStyle(.roundedBorder)
            }
            PanelToggleRow(title: "Run in the background",
                           info: "Detached (-d): runs without attaching to its output.", isOn: $spec.detach)
            PanelToggleRow(title: "Remove when stopped",
                           info: "Automatically deletes the container once it stops (--rm).", isOn: $spec.removeOnExit)
        }
    }

    private var resourcesSection: some View {
        Group {
            PanelRow(title: "CPUs", info: "Virtual CPUs to allocate (--cpus). This Mac has \(hostCPUs) cores.") {
                Picker("", selection: cpuBinding) {
                    Text("Default").tag(0)
                    ForEach(1...max(1, hostCPUs), id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            PanelToggleRow(title: "Limit memory",
                           info: "Cap the container's memory (--memory). Off uses the runtime default.", isOn: memoryLimitBinding)
            if !spec.memory.isEmpty {
                PanelField(label: "Memory") {
                    HStack(spacing: Tokens.Space.s) {
                        Slider(value: memoryGBBinding, in: 0.5...max(0.5, maxMemoryGB), step: 0.5)
                        Text(memoryReadout).monospacedDigit().frame(width: Tokens.FormWidth.memoryReadout)
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
                    TextField("Host", text: $port.hostPort).textFieldStyle(.roundedBorder).frame(width: Tokens.FormWidth.port)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("Container", text: $port.containerPort).textFieldStyle(.roundedBorder).frame(width: Tokens.FormWidth.containerPort)
                    Picker("", selection: $port.proto) { Text("tcp").tag("tcp"); Text("udp").tag("udp") }
                        .labelsHidden().frame(width: Tokens.FormWidth.port)
                    Spacer()
                    removeButton { spec.ports.removeAll { $0.id == port.id } }
                }
            }
            addButton("Add port") { spec.ports.append(PortMap()) }
        }
    }

    private var volumesSection: some View {
        Group {
            ForEach($spec.volumes) { $vol in
                VStack(spacing: Tokens.Space.xs) {
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
            addButton("Add volume") { spec.volumes.append(VolumeMap()) }
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
            addButton("Add variable") { spec.env.append(KeyValue()) }
            stringList("Add env file", $spec.envFiles, prompt: "/path/to/.env",
                       info: "Read environment variables from a file (--env-file).")
        }
    }

    private var socketsSection: some View {
        Group {
            ForEach($spec.sockets) { $socket in
                VStack(spacing: Tokens.Space.xs) {
                    HStack {
                        TextField("Host socket path", text: $socket.hostPath).textFieldStyle(.roundedBorder)
                        removeButton { spec.sockets.removeAll { $0.id == socket.id } }
                    }
                    TextField("Container socket path", text: $socket.containerPath).textFieldStyle(.roundedBorder)
                }
            }
            addButton("Add socket") { spec.sockets.append(SocketMap()) }
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
            addButton("Add label") { spec.labels.append(KeyValue()) }
        }
    }

    private var personalizationSection: some View {
        Group {
            PanelField(label: "Nickname", info: "A friendly display name shown on the card. Stored locally, not on the container.") {
                TextField("", text: $spec.personalization.nickname, prompt: Text("display name (optional)")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: "Icon", info: "Any SF Symbol name to brand the card's icon chip.") {
                TextField("", text: $spec.personalization.icon, prompt: Text("SF Symbol, e.g. globe, bolt")).textFieldStyle(.roundedBorder)
            }
            PanelRow(title: "Color", info: "Color for the card's icon and (optionally) its background.") {
                TintSelector(selection: $spec.personalization.tint)
            }
            PanelToggleRow(title: "Color the card background",
                           info: "Wash the clear glass with the color. Off = clear glass with a colored icon.",
                           isOn: $spec.personalization.fillBackground)
            if spec.personalization.fillBackground {
                PanelField(label: "Opacity") {
                    HStack(spacing: Tokens.Space.s) {
                        Slider(value: $spec.personalization.backgroundOpacity, in: 0.05...0.6)
                        Text(Format.percent(spec.personalization.backgroundOpacity))
                            .monospacedDigit()
                            .frame(width: Tokens.FormWidth.shortReadout)
                    }
                }
                PanelToggleRow(title: "Gradient",
                               info: "Fade the background color for a softer look.",
                               isOn: $spec.personalization.gradient)
                if spec.personalization.gradient {
                    GradientAngleControl(angle: $spec.personalization.gradientAngle)
                }
            }
        }
    }

    private var restartSection: some View {
        PanelRow(title: "Restart policy", info: "Contained restarts the container automatically based on this setting.") {
            Picker("", selection: $spec.restart) {
                ForEach(RestartPolicy.allCases) { Text($0.displayName).tag($0) }
            }
            .labelsHidden().fixedSize()
        }
    }

    private var healthSection: some View {
        Group {
            PanelToggleRow(title: "Enable healthcheck",
                           info: "Contained probes the container on an interval (app-managed; the runtime has no native healthcheck).",
                           isOn: $spec.healthCheck.enabled)
            if spec.healthCheck.enabled {
                PanelField(label: "Probe command", info: "Run inside the container via `sh -c`; a zero exit = healthy. Needs a shell in the image.") {
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
            PanelField(label: "Entrypoint", info: "Override the image's entrypoint program.") {
                TextField("", text: $spec.entrypoint, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            PanelToggleRow(title: "Keep stdin open",
                           info: "Keep standard input open even when detached (--interactive).", isOn: $spec.interactive)
            PanelToggleRow(title: "Allocate TTY",
                           info: "Allocate a terminal for the process (--tty).", isOn: $spec.tty)
            PanelField(label: "Working directory", info: "Initial working directory inside the container (-w).") {
                TextField("", text: $spec.workingDir, prompt: Text("optional, e.g. /app")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: "User", info: "Run the process as this user (-u). Or set UID/GID below.") {
                TextField("", text: $spec.user, prompt: Text("name | uid[:gid]")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: "User ID", info: "Numeric user / group IDs (--uid / --gid).") {
                HStack {
                    TextField("UID", text: $spec.uid).textFieldStyle(.roundedBorder).frame(width: Tokens.FormWidth.userID)
                    TextField("GID", text: $spec.gid).textFieldStyle(.roundedBorder).frame(width: Tokens.FormWidth.userID)
                    Spacer()
                }
            }
            PanelToggleRow(title: "Set shared memory size",
                           info: "Size of /dev/shm (--shm-size).", isOn: shmLimitBinding)
            if !spec.shmSize.isEmpty {
                PanelField(label: "Shared memory") {
                    HStack(spacing: Tokens.Space.s) {
                        Slider(value: shmGBBinding, in: 0.0625...max(0.0625, maxMemoryGB), step: 0.0625)
                        Text(memoryReadout(spec.shmSize, fallbackGB: 0.0625))
                            .monospacedDigit()
                            .frame(width: Tokens.FormWidth.memoryReadout)
                    }
                }
            }

            stringList("Add capability", $spec.capAdd, prompt: "CAP_NET_RAW or ALL",
                       info: "Add a Linux capability (--cap-add).")
            stringList("Drop capability", $spec.capDrop, prompt: "CAP_NET_RAW or ALL",
                       info: "Drop a Linux capability (--cap-drop).")
            PanelField(label: "Container ID file", info: "Write the new container ID to a file (--cidfile).") {
                TextField("", text: $spec.cidFile, prompt: Text("optional path")).textFieldStyle(.roundedBorder)
            }
            stringList("Add tmpfs mount", $spec.tmpfs, prompt: "/path",
                       info: "Mount a tmpfs at this path (--tmpfs).")
            stringList("Add ulimit", $spec.ulimits, prompt: "nofile=1024:2048",
                       info: "Resource limit, type=soft[:hard] (--ulimit).")
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Group {
            PanelToggleRow(title: "Read-only filesystem",
                           info: "Mounts the container's root filesystem as read-only.", isOn: $spec.readOnly)
            PanelToggleRow(title: "Use an init process",
                           info: "Runs a tiny init that forwards signals and cleans up zombie processes.", isOn: $spec.useInit)
            PanelToggleRow(title: "Rosetta (x86 apps)",
                           info: "Lets the container run x86-64 binaries via Rosetta.", isOn: $spec.rosetta)
            PanelToggleRow(title: "Forward SSH agent",
                           info: "Forwards your host SSH agent into the container.", isOn: $spec.ssh)
            PanelToggleRow(title: "Expose virtualization",
                           info: "Exposes nested virtualization (needs host + guest support).", isOn: $spec.virtualization)
        }
    }

    @ViewBuilder
    private var networkSection: some View {
        PanelRow(title: "Network", info: "Attach the container to a network (--network).") {
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
                .frame(width: 180)
        }
        .task { await app.refreshNetworks() }
    }

    @ViewBuilder
    private var fetchSection: some View {
        Group {
            PanelField(label: "Runtime", info: "Runtime handler (--runtime).") {
                TextField("", text: $spec.runtime, prompt: Text("optional")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: "Init image", info: "Use a custom init image (--init-image).") {
                TextField("", text: $spec.initImage, prompt: Text("optional image")).textFieldStyle(.roundedBorder)
            }
            PanelField(label: "Kernel", info: "Use a custom kernel path (--kernel).") {
                TextField("", text: $spec.kernel, prompt: Text("optional path")).textFieldStyle(.roundedBorder)
            }
            PanelRow(title: "Registry scheme", info: "Registry connection scheme for image fetches (--scheme).") {
                Picker("", selection: $spec.scheme) {
                    Text("Default").tag("")
                    Text("Auto").tag("auto")
                    Text("HTTPS").tag("https")
                    Text("HTTP").tag("http")
                }
                .labelsHidden().fixedSize()
            }
            PanelRow(title: "Progress", info: "Progress display mode for image fetches (--progress).") {
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
            PanelToggleRow(title: "Limit parallel downloads",
                           info: "Maximum concurrent image downloads (--max-concurrent-downloads).", isOn: maxDownloadsBinding)
            if !spec.maxConcurrentDownloads.isEmpty {
                Stepper("Max downloads: \(maxConcurrentDownloadsBinding.wrappedValue)",
                        value: maxConcurrentDownloadsBinding, in: 1...16)
            }
        }
    }

    @ViewBuilder
    private var dnsSection: some View {
        Group {
            PanelToggleRow(title: "Disable DNS",
                           info: "Do not configure DNS inside the container (--no-dns).", isOn: $spec.noDNS)
            if !spec.noDNS {
                stringList("Add nameserver", $spec.dns, prompt: "1.1.1.1",
                           info: "DNS nameserver IP (--dns).")
                PanelField(label: "Search domain", info: "Default DNS domain (--dns-domain).") {
                    TextField("", text: $spec.dnsDomain, prompt: Text("optional")).textFieldStyle(.roundedBorder)
                }
                stringList("Add search domain", $spec.dnsSearch, prompt: "example.com",
                           info: "DNS search domain (--dns-search).")
                stringList("Add DNS option", $spec.dnsOption, prompt: "ndots:2",
                           info: "DNS resolver option (--dns-option).")
            }
        }
    }

    @ViewBuilder
    private var advancedOptionsSection: some View {
        // The header switch shows/hides the less-common run settings (Compose import and Edit flip it on
        // automatically when advanced values are present).
        PanelSection(header: "Advanced Options",
                     footer: "Less-common run settings. Compose import and Edit reveal these automatically when advanced values are present.",
                     highlighted: spec.hasAdvancedOptions,
                     enabled: $advancedExpanded) {
            runtimeSection
            securitySection
            fetchSection
            dnsSection
            stringList("Add mount", $spec.mounts, prompt: "type=bind,source=/host,target=/container",
                       info: "Raw mount spec for advanced mount types (--mount).")
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
        spec.network.trimmingCharacters(in: .whitespaces).isEmpty ? "Default" : spec.network
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
        HStack {
            addButton(addTitle) { list.wrappedValue.append("") }
            Spacer()
            InfoButton(info)
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: "plus.circle") }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "minus.circle.fill") }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
    }

    private func sourcePicker(source: Binding<String>) -> some View {
        Menu {
            Button {
                pickHostSource(into: source)
            } label: {
                Label("Choose File or Folder…", systemImage: "folder")
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
                Label("Create New Volume…", systemImage: "plus")
            }
        } label: {
            Image(systemName: "folder.badge.gearshape")
        }
        .buttonStyle(.borderless)
        .help("Choose a host path, existing volume, or create a new volume")
        .task { await app.refreshVolumes() }
    }

    private func pickHostSource(into source: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a host file or folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        source.wrappedValue = url.path
    }
}
