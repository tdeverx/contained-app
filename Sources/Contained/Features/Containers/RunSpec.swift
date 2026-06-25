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
}

/// The complete state of the Create/Run form. Knows how to render itself as a `container run` argv.
struct RunSpec: Codable {
    var image = ""
    var name = ""
    var command = ""          // optional args after the image
    var entrypoint = ""
    var detach = true
    var removeOnExit = false
    var cpus = ""
    var memory = ""
    var env: [KeyValue] = []
    var ports: [PortMap] = []
    var volumes: [VolumeMap] = []
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
    var dns: [String] = []     // --dns
    var dnsDomain = ""         // --dns-domain
    var dnsSearch: [String] = []   // --dns-search
    var dnsOption: [String] = []   // --dns-option
    var tmpfs: [String] = []   // --tmpfs
    var ulimits: [String] = [] // --ulimit  type=soft[:hard]

    // Personalization is stored locally (PersonalizationStore), never injected as labels — this is
    // just the form's working copy, persisted by the sheet after a successful create/save.
    var personalization = Personalization()
    // App-managed healthcheck — also stored locally (HealthCheckStore), not as labels.
    var healthCheck = HealthCheck()

    var isRunnable: Bool { !image.trimmingCharacters(in: .whitespaces).isEmpty }

    init() {}

    /// Prefill from an existing container's configuration — the basis of the Recreate macro
    /// (container config is immutable, so "editing" means delete + re-run from this spec).
    /// Best-effort: reproduces the reversible run flags; the image's baked-in command is kept by
    /// re-passing the recorded arguments.
    init(from config: ContainerConfiguration) {
        image = config.image.reference
        name = config.id
        command = config.initProcess.arguments.joined(separator: " ")
        cpus = String(config.resources.cpus)
        memory = Format.memorySpec(config.resources.memoryInBytes)
        readOnly = config.readOnly
        useInit = config.useInit
        rosetta = config.rosetta
        ssh = config.ssh
        virtualization = config.virtualization
        workingDir = config.initProcess.workingDirectory ?? ""

        ports = config.publishedPorts.map {
            PortMap(hostPort: String($0.hostPort), containerPort: String($0.containerPort),
                    proto: $0.proto ?? "tcp")
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
        if !name.isEmpty { args += ["--name", name] }
        if !cpus.isEmpty { args += ["--cpus", cpus] }
        if !memory.isEmpty { args += ["--memory", memory] }
        if !entrypoint.isEmpty { args += ["--entrypoint", entrypoint] }
        if readOnly { args.append("--read-only") }
        if useInit { args.append("--init") }
        if rosetta { args.append("--rosetta") }
        if ssh { args.append("--ssh") }
        if virtualization { args.append("--virtualization") }

        // Advanced
        if !workingDir.isEmpty { args += ["--workdir", workingDir] }
        if !user.isEmpty { args += ["--user", user] }
        if !uid.isEmpty { args += ["--uid", uid] }
        if !gid.isEmpty { args += ["--gid", gid] }
        if !shmSize.isEmpty { args += ["--shm-size", shmSize] }
        for cap in capAdd where !cap.isEmpty { args += ["--cap-add", cap] }
        for cap in capDrop where !cap.isEmpty { args += ["--cap-drop", cap] }
        for server in dns where !server.isEmpty { args += ["--dns", server] }
        if !dnsDomain.isEmpty { args += ["--dns-domain", dnsDomain] }
        for domain in dnsSearch where !domain.isEmpty { args += ["--dns-search", domain] }
        for option in dnsOption where !option.isEmpty { args += ["--dns-option", option] }
        for mount in tmpfs where !mount.isEmpty { args += ["--tmpfs", mount] }
        for limit in ulimits where !limit.isEmpty { args += ["--ulimit", limit] }

        for port in ports where port.isValid { args += ["--publish", port.spec] }
        for volume in volumes where volume.isValid { args += ["--volume", volume.spec] }
        for variable in env where variable.isValid { args += ["--env", "\(variable.key)=\(variable.value)"] }

        for label in allLabels() { args += ["--label", label] }

        args.append(image)
        let extra = command.split(separator: " ").map(String.init)
        args += extra
        return args
    }

    /// Build a run spec from a compose service, tagged with `contained.stack` so the launched
    /// containers group as a Stack.
    init(service: ComposeService, projectName: String) {
        image = service.image ?? ""
        name = service.name
        command = service.command ?? ""
        detach = true
        restart = RestartPolicy(label: service.restart)
        ports = service.ports.map { spec in
            let parts = spec.split(separator: ":").map(String.init)
            let host = parts.count > 1 ? parts[0] : ""
            let containerPart = parts.count > 1 ? parts[1] : parts.first ?? ""
            let proto = containerPart.contains("/udp") ? "udp" : "tcp"
            return PortMap(hostPort: host, containerPort: containerPart.replacingOccurrences(of: "/udp", with: ""), proto: proto)
        }
        volumes = service.volumes.map { spec in
            let parts = spec.split(separator: ":").map(String.init)
            return VolumeMap(source: parts.first ?? "", target: parts.count > 1 ? parts[1] : "",
                             readOnly: parts.count > 2 && parts[2] == "ro")
        }
        env = service.environment.compactMap { entry in
            guard let eq = entry.firstIndex(of: "=") else { return nil }
            return KeyValue(key: String(entry[..<eq]), value: String(entry[entry.index(after: eq)...]))
        }
        labels = [KeyValue(key: "contained.stack", value: projectName)]
        if let hc = service.healthcheck {
            healthCheck = HealthCheck(command: hc.test, intervalSeconds: hc.intervalSeconds,
                                      retries: hc.retries, enabled: true)
        }
    }

    /// Personalization + restart + user labels, deduped, as `key=value` strings.
    private func allLabels() -> [String] {
        var result: [String: String] = [:]
        for label in labels where label.isValid { result[label.key] = label.value }
        if restart != .no { result["contained.restart"] = restart.rawValue }
        return result.map { "\($0.key)=\($0.value)" }.sorted()
    }
}
