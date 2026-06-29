import SwiftUI
import ContainedCore

/// The shared container Create/Edit form body: progressive-disclosure sections mapping the `run`
/// flags. Reused by `ContainerEditSheet` for both new and edit modes. Field guidance is delivered
/// through tappable `info.circle` popovers (`fieldInfo`), not hover tooltips.
struct RunSpecForm: View {
    @Binding var spec: RunSpec
    @State private var advancedExpanded: Bool

    init(spec: Binding<RunSpec>) {
        self._spec = spec
        let initial = spec.wrappedValue
        self._advancedExpanded = State(initialValue: initial.hasAdvancedOptions)
    }

    var body: some View {
        Form {
            Section("Essentials") {
                generalSection
            }
            Section("Resources") {
                resourcesSection
            }
            Section("Networking") {
                portsSection
                networkSection
                socketsSection
            }
            Section("Storage") {
                volumesSection
            }
            Section("Environment") {
                environmentSection
            }
            Section("App Managed") {
                restartSection
                healthSection
            }
            Section("Appearance") {
                personalizationSection
            }
            advancedOptionsSection
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .onChange(of: spec.hasAdvancedOptions) { _, hasValues in if hasValues { advancedExpanded = true } }
    }

    private var generalSection: some View {
        Group {
            TextField("Image", text: $spec.image, prompt: Text("e.g. nginx:latest"))
                .fieldInfo("The image to run, repo:tag. Pulled automatically if not present locally.")
            Picker("Platform", selection: platformPresetBinding) {
                Text("Default").tag("")
                Text("Linux arm64").tag("linux/arm64")
                Text("Linux amd64").tag("linux/amd64")
                Text("Linux amd64/v2").tag("linux/amd64/v2")
                Text("Custom").tag("custom")
            }
                .fieldInfo("Select an image platform when the image is multi-platform (--platform).")
            if platformPresetBinding.wrappedValue == "custom" {
                TextField("Custom platform", text: $spec.platform, prompt: Text("os/arch[/variant]"))
                    .fieldInfo("Custom platform string passed to --platform.")
            }
            TextField("Name", text: $spec.name, prompt: Text("optional"))
                .fieldInfo("A stable name for the container. Leave blank for a generated one.")
            TextField("Command", text: $spec.command, prompt: Text("override the default command (optional)"))
                .fieldInfo("Arguments passed to the image, replacing its default command.")
            Toggle("Run in the background", isOn: $spec.detach)
                .fieldInfo("Detached (-d): runs without attaching to its output.")
            Toggle("Remove when stopped", isOn: $spec.removeOnExit)
                .fieldInfo("Automatically deletes the container once it stops (--rm).")
        }
    }

    private var resourcesSection: some View {
        Group {
            Picker("CPUs", selection: cpuBinding) {
                Text("Default").tag(0)
                ForEach(1...max(1, hostCPUs), id: \.self) { Text("\($0)").tag($0) }
            }
            .fieldInfo("Virtual CPUs to allocate (--cpus). This Mac has \(hostCPUs) cores.")

            Toggle("Limit memory", isOn: memoryLimitBinding)
                .fieldInfo("Cap the container's memory (--memory). Off uses the runtime default.")
            if !spec.memory.isEmpty {
                LabeledContent("Memory") {
                    Slider(value: memoryGBBinding, in: 0.5...max(0.5, maxMemoryGB), step: 0.5)
                    Text(memoryReadout).monospacedDigit().frame(width: Tokens.FormWidth.memoryReadout)
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
        let gb = Self.parseMemoryGB(spec) ?? fallbackGB
        if gb < 1 { return "\(Int(gb * 1024)) MB" }
        return gb.rounded() == gb ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
    }

    private var platformPresetBinding: Binding<String> {
        let presets = Set(["", "linux/arm64", "linux/amd64", "linux/amd64/v2"])
        return Binding(get: { presets.contains(spec.platform) ? spec.platform : "custom" },
                       set: { if $0 != "custom" { spec.platform = $0 } })
    }

    /// Parse a `--memory` spec ("512M", "1G", "2g", bare bytes) into gigabytes.
    static func parseMemoryGB(_ spec: String) -> Double? {
        let t = spec.trimmingCharacters(in: .whitespaces)
        guard let last = t.last else { return nil }
        if last.isLetter {
            guard let n = Double(t.dropLast()) else { return nil }
            switch last.uppercased() {
            case "G": return n
            case "M": return n / 1024
            case "K": return n / (1024 * 1024)
            case "T": return n * 1024
            default: return nil
            }
        }
        return Double(t).map { $0 / 1_073_741_824 }   // bare number = bytes
    }
    /// Format gigabytes as a `--memory` spec, using `M` for fractional values.
    static func memorySpec(gb: Double) -> String {
        gb.rounded() == gb ? "\(Int(gb))G" : "\(Int(gb * 1024))M"
    }

    private var portsSection: some View {
        Group {
            ForEach($spec.ports) { $port in
                HStack {
                    TextField("Host", text: $port.hostPort).frame(width: Tokens.FormWidth.port)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("Container", text: $port.containerPort).frame(width: Tokens.FormWidth.containerPort)
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
                VStack {
                    HStack {
                        TextField("Source (host path)", text: $vol.source)
                        removeButton { spec.volumes.removeAll { $0.id == vol.id } }
                    }
                    HStack {
                        TextField("Target (container path)", text: $vol.target)
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
                    TextField("KEY", text: $variable.key)
                    Text("=").foregroundStyle(.secondary)
                    TextField("value", text: $variable.value)
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
                VStack {
                    HStack {
                        TextField("Host socket path", text: $socket.hostPath)
                        removeButton { spec.sockets.removeAll { $0.id == socket.id } }
                    }
                    TextField("Container socket path", text: $socket.containerPath)
                }
            }
            addButton("Add socket") { spec.sockets.append(SocketMap()) }
        }
    }

    private var labelsSection: some View {
        Group {
            ForEach($spec.labels) { $label in
                HStack {
                    TextField("KEY", text: $label.key)
                    Text("=").foregroundStyle(.secondary)
                    TextField("value", text: $label.value)
                    removeButton { spec.labels.removeAll { $0.id == label.id } }
                }
            }
            addButton("Add label") { spec.labels.append(KeyValue()) }
        }
    }

    private var personalizationSection: some View {
        Group {
            TextField("Nickname", text: $spec.personalization.nickname, prompt: Text("display name (optional)"))
                .fieldInfo("A friendly display name shown on the card. Stored locally, not on the container.")
            TextField("Icon", text: $spec.personalization.icon, prompt: Text("SF Symbol, e.g. globe, bolt"))
                .fieldInfo("Any SF Symbol name to brand the card's icon chip.")
            LabeledContent("Color") {
                TintSelector(selection: $spec.personalization.tint)
            }
            .fieldInfo("Color for the card's icon and (optionally) its background.")
            Toggle("Color the card background", isOn: $spec.personalization.fillBackground)
                .fieldInfo("Wash the clear glass with the color. Off = clear glass with a colored icon.")
            if spec.personalization.fillBackground {
                LabeledContent("Opacity") {
                    Slider(value: $spec.personalization.backgroundOpacity, in: 0.05...0.6)
                    Text(Format.percent(spec.personalization.backgroundOpacity))
                        .monospacedDigit()
                        .frame(width: Tokens.FormWidth.shortReadout)
                }
                Toggle("Gradient", isOn: $spec.personalization.gradient)
                    .fieldInfo("Fade the background color for a softer look.")
                if spec.personalization.gradient {
                    GradientAngleControl(angle: $spec.personalization.gradientAngle)
                }
            }
        }
    }

    private var restartSection: some View {
        Group {
            Picker("Restart policy", selection: $spec.restart) {
                ForEach(RestartPolicy.allCases) { Text($0.displayName).tag($0) }
            }
            .fieldInfo("Contained restarts the container automatically based on this setting.")
        }
    }

    private var healthSection: some View {
        Group {
            Toggle("Enable healthcheck", isOn: $spec.healthCheck.enabled)
                .fieldInfo("Contained probes the container on an interval (app-managed; the runtime has no native healthcheck).")
            if spec.healthCheck.enabled {
                TextField("Probe command", text: healthCommandBinding,
                          prompt: Text("curl -f http://localhost/ || exit 1"))
                    .fieldInfo("Run inside the container via `sh -c`; a zero exit = healthy. Needs a shell in the image.")
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
            TextField("Entrypoint", text: $spec.entrypoint, prompt: Text("optional"))
                .fieldInfo("Override the image's entrypoint program.")
            Toggle("Keep stdin open", isOn: $spec.interactive)
                .fieldInfo("Keep standard input open even when detached (--interactive).")
            Toggle("Allocate TTY", isOn: $spec.tty)
                .fieldInfo("Allocate a terminal for the process (--tty).")
            TextField("Working directory", text: $spec.workingDir, prompt: Text("optional, e.g. /app"))
                .fieldInfo("Initial working directory inside the container (-w).")
            TextField("User", text: $spec.user, prompt: Text("name | uid[:gid]"))
                .fieldInfo("Run the process as this user (-u). Or set UID/GID below.")
            HStack {
                TextField("UID", text: $spec.uid).frame(width: Tokens.FormWidth.userID)
                TextField("GID", text: $spec.gid).frame(width: Tokens.FormWidth.userID)
                Spacer()
            }
            .fieldInfo("Numeric user / group IDs (--uid / --gid).")
            Toggle("Set shared memory size", isOn: shmLimitBinding)
                .fieldInfo("Size of /dev/shm (--shm-size).")
            if !spec.shmSize.isEmpty {
                LabeledContent("Shared memory") {
                    Slider(value: shmGBBinding, in: 0.0625...max(0.0625, maxMemoryGB), step: 0.0625)
                    Text(memoryReadout(spec.shmSize, fallbackGB: 0.0625))
                        .monospacedDigit()
                        .frame(width: Tokens.FormWidth.memoryReadout)
                }
            }

            stringList("Add capability", $spec.capAdd, prompt: "CAP_NET_RAW or ALL",
                       info: "Add a Linux capability (--cap-add).")
            stringList("Drop capability", $spec.capDrop, prompt: "CAP_NET_RAW or ALL",
                       info: "Drop a Linux capability (--cap-drop).")
            TextField("Container ID file", text: $spec.cidFile, prompt: Text("optional path"))
                .fieldInfo("Write the new container ID to a file (--cidfile).")
            stringList("Add tmpfs mount", $spec.tmpfs, prompt: "/path",
                       info: "Mount a tmpfs at this path (--tmpfs).")
            stringList("Add ulimit", $spec.ulimits, prompt: "nofile=1024:2048",
                       info: "Resource limit, type=soft[:hard] (--ulimit).")
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Group {
            Toggle("Read-only filesystem", isOn: $spec.readOnly)
                .fieldInfo("Mounts the container's root filesystem as read-only.")
            Toggle("Use an init process", isOn: $spec.useInit)
                .fieldInfo("Runs a tiny init that forwards signals and cleans up zombie processes.")
            Toggle("Rosetta (x86 apps)", isOn: $spec.rosetta)
                .fieldInfo("Lets the container run x86-64 binaries via Rosetta.")
            Toggle("Forward SSH agent", isOn: $spec.ssh)
                .fieldInfo("Forwards your host SSH agent into the container.")
            Toggle("Expose virtualization", isOn: $spec.virtualization)
                .fieldInfo("Exposes nested virtualization (needs host + guest support).")
        }
    }

    @ViewBuilder
    private var networkSection: some View {
        Group {
            TextField("Network", text: $spec.network, prompt: Text("optional, e.g. default"))
                .fieldInfo("Attach the container to a network (--network).")
        }
    }

    @ViewBuilder
    private var fetchSection: some View {
        Group {
            TextField("Runtime", text: $spec.runtime, prompt: Text("optional"))
                .fieldInfo("Runtime handler (--runtime).")
            TextField("Init image", text: $spec.initImage, prompt: Text("optional image"))
                .fieldInfo("Use a custom init image (--init-image).")
            TextField("Kernel", text: $spec.kernel, prompt: Text("optional path"))
                .fieldInfo("Use a custom kernel path (--kernel).")
            Picker("Registry scheme", selection: $spec.scheme) {
                Text("Default").tag("")
                Text("Auto").tag("auto")
                Text("HTTPS").tag("https")
                Text("HTTP").tag("http")
            }
                .fieldInfo("Registry connection scheme for image fetches (--scheme).")
            Picker("Progress", selection: $spec.progress) {
                Text("Default").tag("")
                Text("Auto").tag("auto")
                Text("None").tag("none")
                Text("ANSI").tag("ansi")
                Text("Plain").tag("plain")
                Text("Color").tag("color")
            }
                .fieldInfo("Progress display mode for image fetches (--progress).")
            Toggle("Limit parallel downloads", isOn: maxDownloadsBinding)
                .fieldInfo("Maximum concurrent image downloads (--max-concurrent-downloads).")
            if !spec.maxConcurrentDownloads.isEmpty {
                Stepper("Max downloads: \(maxConcurrentDownloadsBinding.wrappedValue)",
                        value: maxConcurrentDownloadsBinding, in: 1...16)
            }
        }
    }

    @ViewBuilder
    private var dnsSection: some View {
        Group {
            Toggle("Disable DNS", isOn: $spec.noDNS)
                .fieldInfo("Do not configure DNS inside the container (--no-dns).")
            if !spec.noDNS {
                stringList("Add nameserver", $spec.dns, prompt: "1.1.1.1",
                           info: "DNS nameserver IP (--dns).")
                TextField("Search domain default", text: $spec.dnsDomain, prompt: Text("optional"))
                    .fieldInfo("Default DNS domain (--dns-domain).")
                stringList("Add search domain", $spec.dnsSearch, prompt: "example.com",
                           info: "DNS search domain (--dns-search).")
                stringList("Add DNS option", $spec.dnsOption, prompt: "ndots:2",
                           info: "DNS resolver option (--dns-option).")
            }
        }
    }

    @ViewBuilder
    private var advancedOptionsSection: some View {
        Section("Advanced Options") {
            Toggle("Show advanced options", isOn: $advancedExpanded)
                .fieldInfo("Shows less-common run settings. Compose import and Edit open this automatically when advanced values are present.")
            if advancedExpanded {
                runtimeSection
                securitySection
                fetchSection
                dnsSection
                stringList("Add mount", $spec.mounts, prompt: "type=bind,source=/host,target=/container",
                           info: "Raw mount spec for advanced mount types (--mount).")
                labelsSection
            }
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

    /// A repeatable single-string list editor (capabilities, DNS servers, tmpfs, ulimits…).
    @ViewBuilder
    private func stringList(_ addTitle: String, _ list: Binding<[String]>, prompt: String, info: String) -> some View {
        ForEach(list.wrappedValue.indices, id: \.self) { idx in
            HStack {
                TextField(prompt, text: Binding(get: { list.wrappedValue[idx] },
                                                set: { list.wrappedValue[idx] = $0 }))
                removeButton { list.wrappedValue.remove(at: idx) }
            }
        }
        addButton(addTitle) { list.wrappedValue.append("") }
            .fieldInfo(info)
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
}

private extension RunSpec {
    var hasResourceOptions: Bool {
        !cpus.isEmpty || !memory.isEmpty
    }

    var hasNetworkingOptions: Bool {
        !ports.isEmpty || !network.isEmpty || !sockets.isEmpty
    }

    var hasStorageOptions: Bool {
        !volumes.isEmpty || !mounts.isEmpty
    }

    var hasEnvironmentOptions: Bool {
        !env.isEmpty || !envFiles.isEmpty
    }

    var hasPersonalizationOptions: Bool {
        !personalization.isDefault
    }

    var hasAdvancedOptions: Bool {
        interactive || tty ||
        !entrypoint.isEmpty ||
        !workingDir.isEmpty ||
        !user.isEmpty ||
        !uid.isEmpty ||
        !gid.isEmpty ||
        !shmSize.isEmpty ||
        !capAdd.isEmpty ||
        !capDrop.isEmpty ||
        !cidFile.isEmpty ||
        !initImage.isEmpty ||
        !kernel.isEmpty ||
        noDNS ||
        !dns.isEmpty ||
        !dnsDomain.isEmpty ||
        !dnsSearch.isEmpty ||
        !dnsOption.isEmpty ||
        !tmpfs.isEmpty ||
        !ulimits.isEmpty ||
        !runtime.isEmpty ||
        !scheme.isEmpty ||
        !progress.isEmpty ||
        !maxConcurrentDownloads.isEmpty ||
        !mounts.isEmpty ||
        !labels.isEmpty ||
        readOnly ||
        useInit ||
        rosetta ||
        ssh ||
        virtualization
    }
}
