import Foundation
import ContainedCore

// `RestartPolicy` now lives in ContainedCore (Models/RestartPolicy.swift) so the watchdog's
// decision logic can be unit-tested without the app target.

/// An editable key/value row (env vars, labels).
struct KeyValue: Identifiable, Hashable, Codable {
    let id = UUID()
    var key = ""
    var value = ""
    var isValid: Bool { !key.trimmingCharacters(in: .whitespaces).isEmpty }
    private enum CodingKeys: String, CodingKey { case key, value }
}

/// A port mapping row.
struct PortMap: Identifiable, Hashable, Codable {
    let id = UUID()
    var hostPort = ""
    var containerPort = ""
    var proto = "tcp"
    var isValid: Bool { !hostPort.isEmpty && !containerPort.isEmpty }
    var spec: String {
        let base = "\(hostPort):\(containerPort)"
        return proto == "tcp" ? base : "\(base)/\(proto)"
    }
    private enum CodingKeys: String, CodingKey { case hostPort, containerPort, proto }
}

/// A volume / bind-mount row.
struct VolumeMap: Identifiable, Hashable, Codable {
    let id = UUID()
    var source = ""
    var target = ""
    var readOnly = false
    var isValid: Bool { !source.isEmpty && !target.isEmpty }
    var spec: String {
        let base = "\(source):\(target)"
        return readOnly ? "\(base):ro" : base
    }
    private enum CodingKeys: String, CodingKey { case source, target, readOnly }
}

/// A host socket forwarded into the container.
struct SocketMap: Identifiable, Hashable, Codable {
    let id = UUID()
    var hostPath = ""
    var containerPath = ""
    var isValid: Bool { !hostPath.isEmpty && !containerPath.isEmpty }
    var spec: String { "\(hostPath):\(containerPath)" }
    private enum CodingKeys: String, CodingKey { case hostPath, containerPath }
}

/// The complete state of the Create/Run form. Knows how to render itself as a `container run` argv.
struct RunSpec: Codable {
    var image = ""
    var platform = ""
    var name = ""
    var command = ""          // optional args after the image
    var entrypoint = ""
    var detach = true
    var removeOnExit = false
    var interactive = false
    var tty = false
    var cpus = ""
    var memory = ""
    var env: [KeyValue] = []
    var envFiles: [String] = []
    var ports: [PortMap] = []
    var volumes: [VolumeMap] = []
    var mounts: [String] = []  // --mount type=...,source=...,target=...
    var sockets: [SocketMap] = []
    var labels: [KeyValue] = []
    var readOnly = false
    var useInit = false
    var rosetta = false
    var ssh = false
    var virtualization = false
    var restart: RestartPolicy = .no

    // Advanced (all optional; empty entries are skipped when building argv).
    var workingDir = ""        // -w
    var user = ""              // -u  name|uid[:gid]
    var uid = ""               // --uid
    var gid = ""               // --gid
    var shmSize = ""           // --shm-size  e.g. 64M, 1G
    var capAdd: [String] = []  // --cap-add
    var capDrop: [String] = [] // --cap-drop
    var cidFile = ""           // --cidfile
    var initImage = ""         // --init-image
    var kernel = ""            // --kernel
    var network = ""           // --network
    var noDNS = false          // --no-dns
    var dns: [String] = []     // --dns
    var dnsDomain = ""         // --dns-domain
    var dnsSearch: [String] = []   // --dns-search
    var dnsOption: [String] = []   // --dns-option
    var tmpfs: [String] = []   // --tmpfs
    var ulimits: [String] = [] // --ulimit  type=soft[:hard]
    var runtime = ""           // --runtime
    var scheme = ""            // --scheme
    var progress = ""          // --progress
    var maxConcurrentDownloads = ""   // --max-concurrent-downloads

    // Personalization is stored locally (PersonalizationStore), never injected as labels — this is
    // just the form's working copy, persisted by the sheet after a successful create/save.
    var personalization = Personalization()
    // App-managed healthcheck — also stored locally (HealthCheckStore), not as labels.
    var healthCheck = HealthCheck()

    var validationMessages: [String] {
        var messages: [String] = []
        if image.trimmingCharacters(in: .whitespaces).isEmpty {
            messages.append("Choose an image to run.")
        }
        for port in ports {
            let hasHost = !port.hostPort.trimmingCharacters(in: .whitespaces).isEmpty
            let hasContainer = !port.containerPort.trimmingCharacters(in: .whitespaces).isEmpty
            if hasHost != hasContainer {
                messages.append("Complete or remove partial port mappings.")
                break
            }
        }
        for volume in volumes {
            let hasSource = !volume.source.trimmingCharacters(in: .whitespaces).isEmpty
            let hasTarget = !volume.target.trimmingCharacters(in: .whitespaces).isEmpty
            if hasSource != hasTarget {
                messages.append("Complete or remove partial volume mounts.")
                break
            }
        }
        if env.contains(where: {
            $0.key.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }) {
            messages.append("Environment variables with values need names.")
        }
        if !memory.trimmingCharacters(in: .whitespaces).isEmpty,
           RunSpec.parseMemoryBytes(memory) == nil {
            messages.append("Memory must use a value like 512M or 2G.")
        }
        return messages
    }

    var isRunnable: Bool { validationMessages.isEmpty }

    private static func parseMemoryBytes(_ spec: String) -> UInt64? {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let suffix = trimmed.last?.isLetter == true ? trimmed.last! : nil
        let numberPart = suffix == nil ? trimmed : String(trimmed.dropLast())
        guard let value = Double(numberPart), value > 0 else { return nil }
        let multiplier: Double
        switch suffix?.uppercased() {
        case nil: multiplier = 1
        case "K": multiplier = 1024
        case "M": multiplier = 1024 * 1024
        case "G": multiplier = 1024 * 1024 * 1024
        case "T": multiplier = 1024 * 1024 * 1024 * 1024
        default: return nil
        }
        return UInt64(value * multiplier)
    }

    init() {}

    /// Prefill from an existing container's configuration — the basis of the Recreate macro
    /// (container config is immutable, so "editing" means delete + re-run from this spec).
    /// Best-effort: reproduces the reversible run flags; the image's baked-in command is kept by
    /// re-passing the recorded arguments.
    init(from config: ContainerConfiguration) {
        image = config.image.reference
        platform = config.platform.display
        name = config.id
        command = config.initProcess.arguments.joined(separator: " ")
        tty = config.initProcess.terminal
        cpus = String(config.resources.cpus)
        memory = Format.memorySpec(config.resources.memoryInBytes)
        readOnly = config.readOnly
        useInit = config.useInit
        rosetta = config.rosetta
        ssh = config.ssh
        virtualization = config.virtualization
        workingDir = config.initProcess.workingDirectory ?? ""
        shmSize = config.shmSize.map(Format.memorySpec) ?? ""
        capAdd = config.capAdd
        capDrop = config.capDrop
        runtime = config.runtimeHandler ?? ""
        network = config.networks.first?.network ?? ""
        dns = config.dns?.nameservers ?? []
        dnsDomain = config.dns?.domain ?? ""
        dnsSearch = config.dns?.searchDomains ?? []
        dnsOption = config.dns?.options ?? []

        ports = config.publishedPorts.map {
            let hostPrefix = ($0.hostAddress ?? "").isEmpty || $0.hostAddress == "0.0.0.0" ? "" : "\($0.hostAddress!):"
            return PortMap(hostPort: "\(hostPrefix)\($0.hostPort)", containerPort: String($0.containerPort),
                    proto: $0.proto ?? "tcp")
        }
        sockets = config.publishedSockets.compactMap { socket in
            guard let hostPath = socket.hostPath, let containerPath = socket.containerPath else { return nil }
            return SocketMap(hostPath: hostPath, containerPath: containerPath)
        }
        volumes = config.mounts.compactMap { mount in
            guard let source = mount.source, let target = mount.effectiveDestination else { return nil }
            return VolumeMap(source: source, target: target, readOnly: mount.readonly ?? false)
        }
        env = config.initProcess.environment.compactMap { entry in
            guard let eq = entry.firstIndex(of: "=") else { return nil }
            return KeyValue(key: String(entry[..<eq]), value: String(entry[entry.index(after: eq)...]))
        }
        // User labels only (our functional contained.* labels are never surfaced as editable rows).
        labels = config.labels
            .filter { !$0.key.hasPrefix("contained.") }
            .sorted { $0.key < $1.key }
            .map { KeyValue(key: $0.key, value: $0.value) }
        restart = RestartPolicy(label: config.labels["contained.restart"])
        // Personalization is resolved from the local store by the edit sheet, not from labels.
    }

    /// Build the `container run …` argument vector. Single source of truth for the live preview
    /// and the actual execution.
    func arguments() -> [String] {
        var args = ["run"]
        if detach { args.append("--detach") }
        if removeOnExit { args.append("--rm") }
        if interactive { args.append("--interactive") }
        if tty { args.append("--tty") }
        if !name.isEmpty { args += ["--name", name] }
        if !cpus.isEmpty { args += ["--cpus", cpus] }
        if !memory.isEmpty { args += ["--memory", memory] }
        if !entrypoint.isEmpty { args += ["--entrypoint", entrypoint] }
        if readOnly { args.append("--read-only") }
        if useInit { args.append("--init") }
        if rosetta { args.append("--rosetta") }
        if ssh { args.append("--ssh") }
        if virtualization { args.append("--virtualization") }
        if !platform.isEmpty { args += ["--platform", platform] }

        // Advanced
        if !workingDir.isEmpty { args += ["--workdir", workingDir] }
        if !user.isEmpty { args += ["--user", user] }
        if !uid.isEmpty { args += ["--uid", uid] }
        if !gid.isEmpty { args += ["--gid", gid] }
        if !shmSize.isEmpty { args += ["--shm-size", shmSize] }
        for cap in capAdd where !cap.isEmpty { args += ["--cap-add", cap] }
        for cap in capDrop where !cap.isEmpty { args += ["--cap-drop", cap] }
        if !cidFile.isEmpty { args += ["--cidfile", cidFile] }
        if !initImage.isEmpty { args += ["--init-image", initImage] }
        if !kernel.isEmpty { args += ["--kernel", kernel] }
        if !network.isEmpty { args += ["--network", network] }
        if noDNS { args.append("--no-dns") }
        if !noDNS {
            for server in dns where !server.isEmpty { args += ["--dns", server] }
            if !dnsDomain.isEmpty { args += ["--dns-domain", dnsDomain] }
            for domain in dnsSearch where !domain.isEmpty { args += ["--dns-search", domain] }
            for option in dnsOption where !option.isEmpty { args += ["--dns-option", option] }
        }
        for mount in tmpfs where !mount.isEmpty { args += ["--tmpfs", mount] }
        for limit in ulimits where !limit.isEmpty { args += ["--ulimit", limit] }
        if !runtime.isEmpty { args += ["--runtime", runtime] }
        if !scheme.isEmpty { args += ["--scheme", scheme] }
        if !progress.isEmpty { args += ["--progress", progress] }
        if !maxConcurrentDownloads.isEmpty { args += ["--max-concurrent-downloads", maxConcurrentDownloads] }

        for port in ports where port.isValid { args += ["--publish", port.spec] }
        for volume in volumes where volume.isValid { args += ["--volume", volume.spec] }
        for mount in mounts where !mount.isEmpty { args += ["--mount", mount] }
        for socket in sockets where socket.isValid { args += ["--publish-socket", socket.spec] }
        for file in envFiles where !file.isEmpty { args += ["--env-file", file] }
        for variable in env where variable.isValid { args += ["--env", "\(variable.key)=\(variable.value)"] }

        for label in allLabels() { args += ["--label", label] }

        args.append(image)
        let extra = command.split(separator: " ").map(String.init)
        args += extra
        return args
    }

    /// Build a run spec from a compose service, tagged with `contained.stack` so the launched
    /// containers retain their imported Compose group.
    init(service: ComposeService, projectName: String) {
        image = service.image ?? ""
        platform = service.platform ?? ""
        name = service.name
        command = service.command ?? ""
        entrypoint = service.entrypoint ?? ""
        detach = true
        interactive = service.interactive
        tty = service.tty
        restart = RestartPolicy(label: service.restart)
        cpus = service.cpus ?? ""
        memory = service.memory ?? ""
        readOnly = service.readOnly
        useInit = service.initProcess
        workingDir = service.workingDir ?? ""
        user = service.user ?? ""
        capAdd = service.capAdd
        capDrop = service.capDrop
        network = service.network ?? ""
        dns = service.dns
        dnsSearch = service.dnsSearch
        dnsOption = service.dnsOptions
        tmpfs = service.tmpfs
        ulimits = service.ulimits
        ports = service.ports.compactMap(Self.portMap)
        volumes = service.volumes.compactMap { spec in
            let parts = spec.split(separator: ":", maxSplits: 2).map(String.init)
            guard parts.count > 1 else { return nil }
            return VolumeMap(source: parts.first ?? "", target: parts.count > 1 ? parts[1] : "",
                             readOnly: parts.count > 2 && parts[2] == "ro")
        }
        env = service.environment.compactMap { entry in
            guard let eq = entry.firstIndex(of: "=") else { return nil }
            return KeyValue(key: String(entry[..<eq]), value: String(entry[entry.index(after: eq)...]))
        }
        envFiles = service.envFiles
        labels = service.labels.compactMap(Self.keyValue)
        labels.append(KeyValue(key: "contained.stack", value: projectName))
        if let hc = service.healthcheck {
            healthCheck = HealthCheck(command: hc.test, intervalSeconds: hc.intervalSeconds,
                                      retries: hc.retries, enabled: true)
        }
    }

    private static func portMap(_ spec: String) -> PortMap? {
        var raw = spec
        let proto: String
        if let slash = raw.lastIndex(of: "/") {
            proto = String(raw[raw.index(after: slash)...])
            raw = String(raw[..<slash])
        } else {
            proto = "tcp"
        }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return nil }
        let host = parts.dropLast().joined(separator: ":")
        let container = parts[parts.count - 1]
        guard !host.isEmpty, !container.isEmpty else { return nil }
        return PortMap(hostPort: host, containerPort: container, proto: proto)
    }

    private static func keyValue(_ entry: String) -> KeyValue? {
        guard let eq = entry.firstIndex(of: "=") else { return nil }
        return KeyValue(key: String(entry[..<eq]), value: String(entry[entry.index(after: eq)...]))
    }

    /// Personalization + restart + user labels, deduped, as `key=value` strings.
    private func allLabels() -> [String] {
        var result: [String: String] = [:]
        for label in labels where label.isValid { result[label.key] = label.value }
        if restart != .no { result["contained.restart"] = restart.rawValue }
        return result.map { "\($0.key)=\($0.value)" }.sorted()
    }
}
