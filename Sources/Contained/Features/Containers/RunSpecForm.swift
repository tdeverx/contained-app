import SwiftUI
import ContainedCore

/// The shared container Create/Edit form body: progressive-disclosure sections mapping the `run`
/// flags. Reused by `ContainerEditSheet` for both new and edit modes. Field guidance is delivered
/// through tappable `info.circle` popovers (`fieldInfo`), not hover tooltips.
struct RunSpecForm: View {
    @Binding var spec: RunSpec

    var body: some View {
        Form {
            generalSection
            resourcesSection
            portsSection
            volumesSection
            environmentSection
            healthSection
            personalizationSection
            advancedSection
            runtimeSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private var generalSection: some View {
        Section("General") {
            TextField("Image", text: $spec.image, prompt: Text("e.g. nginx:latest"))
                .fieldInfo("The image to run, repo:tag. Pulled automatically if not present locally.")
            TextField("Name", text: $spec.name, prompt: Text("optional"))
                .fieldInfo("A stable name for the container. Leave blank for a generated one.")
            TextField("Command", text: $spec.command, prompt: Text("override the default command (optional)"))
                .fieldInfo("Arguments passed to the image, replacing its default command.")
            TextField("Entrypoint", text: $spec.entrypoint, prompt: Text("optional"))
                .fieldInfo("Override the image's entrypoint program.")
            Toggle("Run in the background", isOn: $spec.detach)
                .fieldInfo("Detached (-d): runs without attaching to its output.")
            Toggle("Remove when stopped", isOn: $spec.removeOnExit)
                .fieldInfo("Automatically deletes the container once it stops (--rm).")
        }
    }

    private var resourcesSection: some View {
        Section("Resources") {
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
                    Text(memoryReadout).monospacedDigit().frame(width: 64)
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
        let gb = Self.parseMemoryGB(spec.memory) ?? 2
        if gb < 1 { return "\(Int(gb * 1024)) MB" }
        return gb.rounded() == gb ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
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
        Section("Ports") {
            ForEach($spec.ports) { $port in
                HStack {
                    TextField("Host", text: $port.hostPort).frame(width: 70)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField("Container", text: $port.containerPort).frame(width: 80)
                    Picker("", selection: $port.proto) { Text("tcp").tag("tcp"); Text("udp").tag("udp") }
                        .labelsHidden().frame(width: 70)
                    Spacer()
                    removeButton { spec.ports.removeAll { $0.id == port.id } }
                }
            }
            addButton("Add port") { spec.ports.append(PortMap()) }
        }
    }

    private var volumesSection: some View {
        Section("Volumes & mounts") {
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
        Section("Environment") {
            ForEach($spec.env) { $variable in
                HStack {
                    TextField("KEY", text: $variable.key)
                    Text("=").foregroundStyle(.secondary)
                    TextField("value", text: $variable.value)
                    removeButton { spec.env.removeAll { $0.id == variable.id } }
                }
            }
            addButton("Add variable") { spec.env.append(KeyValue()) }
        }
    }

    private var personalizationSection: some View {
        Section("Personalization") {
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
                    Text(Format.percent(spec.personalization.backgroundOpacity)).monospacedDigit().frame(width: 44)
                }
                Toggle("Gradient", isOn: $spec.personalization.gradient)
                    .fieldInfo("Fade the background color for a softer look.")
                if spec.personalization.gradient {
                    GradientAngleControl(angle: $spec.personalization.gradientAngle)
                }
            }
        }
    }

    private var advancedSection: some View {
        Section("Security & advanced") {
            Picker("Restart policy", selection: $spec.restart) {
                ForEach(RestartPolicy.allCases) { Text($0.displayName).tag($0) }
            }
            .fieldInfo("Contained restarts the container automatically based on this setting.")
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

    private var healthSection: some View {
        Section("Health check") {
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
        Section("Advanced") {
            TextField("Working directory", text: $spec.workingDir, prompt: Text("optional, e.g. /app"))
                .fieldInfo("Initial working directory inside the container (-w).")
            TextField("User", text: $spec.user, prompt: Text("name | uid[:gid]"))
                .fieldInfo("Run the process as this user (-u). Or set UID/GID below.")
            HStack {
                TextField("UID", text: $spec.uid).frame(width: 90)
                TextField("GID", text: $spec.gid).frame(width: 90)
                Spacer()
            }
            .fieldInfo("Numeric user / group IDs (--uid / --gid).")
            TextField("Shared memory size", text: $spec.shmSize, prompt: Text("optional, e.g. 64M, 1G"))
                .fieldInfo("Size of /dev/shm (--shm-size).")

            stringList("Add capability", $spec.capAdd, prompt: "CAP_NET_RAW or ALL",
                       info: "Add a Linux capability (--cap-add).")
            stringList("Drop capability", $spec.capDrop, prompt: "CAP_NET_RAW or ALL",
                       info: "Drop a Linux capability (--cap-drop).")
            stringList("Add tmpfs mount", $spec.tmpfs, prompt: "/path",
                       info: "Mount a tmpfs at this path (--tmpfs).")
            stringList("Add ulimit", $spec.ulimits, prompt: "nofile=1024:2048",
                       info: "Resource limit, type=soft[:hard] (--ulimit).")
        }

        Section("DNS") {
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
