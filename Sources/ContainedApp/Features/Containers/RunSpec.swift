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

/// The complete app-owned state of the Create/Run form. Runtime adapters translate the derived
/// `ContainerCreateRequest` into backend-specific commands.
struct RunSpec: Codable {
    var runtimeKind: RuntimeKind? = .appleContainer
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
            messages.append(AppText.runSpecChooseImageToRun)
        }
        for port in ports {
            let hasHost = !port.hostPort.trimmingCharacters(in: .whitespaces).isEmpty
            let hasContainer = !port.containerPort.trimmingCharacters(in: .whitespaces).isEmpty
            if hasHost != hasContainer {
                messages.append(AppText.runSpecCompletePortMappings)
                break
            }
        }
        for volume in volumes {
            let hasSource = !volume.source.trimmingCharacters(in: .whitespaces).isEmpty
            let hasTarget = !volume.target.trimmingCharacters(in: .whitespaces).isEmpty
            if hasSource != hasTarget {
                messages.append(AppText.runSpecCompleteVolumeMounts)
                break
            }
        }
        if env.contains(where: {
            $0.key.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }) {
            messages.append(AppText.runSpecEnvironmentNeedsNames)
        }
        if !memory.trimmingCharacters(in: .whitespaces).isEmpty,
           RunSpec.parseMemoryBytes(memory) == nil {
            messages.append(AppText.runSpecMemoryFormat)
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

    /// Command-preview compatibility for the Apple runtime while the form still presents a shell
    /// preview. The backend boundary remains the runtime-neutral `createRequest`.
    func arguments() -> [String] {
        ContainerCommands.run(createRequest)
    }

    var createRequest: ContainerCreateRequest {
        var request = ContainerCreateRequest()
        request.runtimeKind = effectiveRuntimeKind
        request.image = image
        request.platform = platform
        request.name = name
        request.command = command.split(separator: " ").map(String.init)
        request.entrypoint = entrypoint
        request.detach = detach
        request.removeOnExit = removeOnExit
        request.interactive = interactive
        request.tty = tty
        request.cpus = cpus
        request.memory = memory
        request.env = env.map { ContainerCreateKeyValue(key: $0.key, value: $0.value) }
        request.envFiles = envFiles
        request.ports = ports.map { ContainerCreatePort(hostPort: $0.hostPort, containerPort: $0.containerPort, proto: $0.proto) }
        request.volumes = volumes.map { ContainerCreateVolume(source: $0.source, target: $0.target, readOnly: $0.readOnly) }
        request.mounts = mounts
        request.sockets = sockets.map { ContainerCreateSocket(hostPath: $0.hostPath, containerPath: $0.containerPath) }
        request.labels = labels.map { ContainerCreateKeyValue(key: $0.key, value: $0.value) }
        request.restart = restart
        request.readOnly = readOnly
        request.useInit = useInit
        request.rosetta = rosetta
        request.ssh = ssh
        request.virtualization = virtualization
        request.workingDir = workingDir
        request.user = user
        request.uid = uid
        request.gid = gid
        request.shmSize = shmSize
        request.capAdd = capAdd
        request.capDrop = capDrop
        request.cidFile = cidFile
        request.initImage = initImage
        request.kernel = kernel
        request.network = network
        request.noDNS = noDNS
        request.dns = dns
        request.dnsDomain = dnsDomain
        request.dnsSearch = dnsSearch
        request.dnsOption = dnsOption
        request.tmpfs = tmpfs
        request.ulimits = ulimits
        request.runtime = runtime
        request.scheme = scheme
        request.progress = progress
        request.maxConcurrentDownloads = maxConcurrentDownloads
        return request
    }

    init(request: ContainerCreateRequest, healthCheck: HealthCheck? = nil) {
        runtimeKind = request.runtimeKind
        image = request.image
        platform = request.platform
        name = request.name
        command = request.command.joined(separator: " ")
        entrypoint = request.entrypoint
        detach = request.detach
        removeOnExit = request.removeOnExit
        interactive = request.interactive
        tty = request.tty
        cpus = request.cpus
        memory = request.memory
        env = request.env.map { KeyValue(key: $0.key, value: $0.value) }
        envFiles = request.envFiles
        ports = request.ports.map { PortMap(hostPort: $0.hostPort, containerPort: $0.containerPort, proto: $0.proto) }
        volumes = request.volumes.map { VolumeMap(source: $0.source, target: $0.target, readOnly: $0.readOnly) }
        mounts = request.mounts
        sockets = request.sockets.map { SocketMap(hostPath: $0.hostPath, containerPath: $0.containerPath) }
        labels = request.labels.map { KeyValue(key: $0.key, value: $0.value) }
        restart = request.restart
        readOnly = request.readOnly
        useInit = request.useInit
        rosetta = request.rosetta
        ssh = request.ssh
        virtualization = request.virtualization
        workingDir = request.workingDir
        user = request.user
        uid = request.uid
        gid = request.gid
        shmSize = request.shmSize
        capAdd = request.capAdd
        capDrop = request.capDrop
        cidFile = request.cidFile
        initImage = request.initImage
        kernel = request.kernel
        network = request.network
        noDNS = request.noDNS
        dns = request.dns
        dnsDomain = request.dnsDomain
        dnsSearch = request.dnsSearch
        dnsOption = request.dnsOption
        tmpfs = request.tmpfs
        ulimits = request.ulimits
        runtime = request.runtime
        scheme = request.scheme
        progress = request.progress
        maxConcurrentDownloads = request.maxConcurrentDownloads
        if let healthCheck { self.healthCheck = healthCheck }
    }

    var effectiveRuntimeKind: RuntimeKind {
        runtimeKind ?? .appleContainer
    }
}
