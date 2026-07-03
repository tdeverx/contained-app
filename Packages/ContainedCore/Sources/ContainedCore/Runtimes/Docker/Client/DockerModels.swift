import Foundation

enum DockerJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = Core.Container.JSON.parseDate(raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(raw)")
        }
        return decoder
    }()

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    static func decodeJSONLines<T: Decodable>(_ type: T.Type, from data: Data) throws -> [T] {
        try String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { Data($0.utf8) }
            .map { try decoder.decode(type, from: $0) }
    }
}

struct DockerContainerInspect: Decodable {
    var id: String
    var name: String?
    var config: Config
    var state: State?
    var hostConfig: HostConfig?
    var networkSettings: NetworkSettings?
    var mounts: [Mount]?
    var platform: String?
    var created: Date?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case config = "Config"
        case state = "State"
        case hostConfig = "HostConfig"
        case networkSettings = "NetworkSettings"
        case mounts = "Mounts"
        case platform = "Platform"
        case created = "Created"
    }

    struct Config: Decodable {
        var image: String?
        var cmd: [String]?
        var entrypoint: DockerStringList?
        var env: [String]?
        var workingDir: String?
        var user: String?
        var labels: [String: String]?
        var tty: Bool?

        enum CodingKeys: String, CodingKey {
            case image = "Image"
            case cmd = "Cmd"
            case entrypoint = "Entrypoint"
            case env = "Env"
            case workingDir = "WorkingDir"
            case user = "User"
            case labels = "Labels"
            case tty = "Tty"
        }
    }

    struct State: Decodable {
        var status: String?
        var running: Bool?
        var startedAt: String?

        enum CodingKeys: String, CodingKey {
            case status = "Status"
            case running = "Running"
            case startedAt = "StartedAt"
        }
    }

    struct HostConfig: Decodable {
        var networkMode: String?
        var portBindings: [String: [PortBinding]?]?
        var readonlyRootfs: Bool?
        var initProcess: Bool?
        var shmSize: UInt64?
        var capAdd: [String]?
        var capDrop: [String]?
        var runtime: String?

        enum CodingKeys: String, CodingKey {
            case networkMode = "NetworkMode"
            case portBindings = "PortBindings"
            case readonlyRootfs = "ReadonlyRootfs"
            case initProcess = "Init"
            case shmSize = "ShmSize"
            case capAdd = "CapAdd"
            case capDrop = "CapDrop"
            case runtime = "Runtime"
        }
    }

    struct PortBinding: Decodable {
        var hostIP: String?
        var hostPort: String?

        enum CodingKeys: String, CodingKey {
            case hostIP = "HostIp"
            case hostPort = "HostPort"
        }
    }

    struct NetworkSettings: Decodable {
        var networks: [String: Network]?

        enum CodingKeys: String, CodingKey { case networks = "Networks" }
    }

    struct Network: Decodable {
        var ipAddress: String?
        var gateway: String?
        var globalIPv6Address: String?
        var macAddress: String?

        enum CodingKeys: String, CodingKey {
            case ipAddress = "IPAddress"
            case gateway = "Gateway"
            case globalIPv6Address = "GlobalIPv6Address"
            case macAddress = "MacAddress"
        }
    }

    struct Mount: Decodable {
        var type: String?
        var source: String?
        var destination: String?
        var rw: Bool?

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case source = "Source"
            case destination = "Destination"
            case rw = "RW"
        }
    }

    func coreSnapshot() throws -> Core.Container.Snapshot {
        let status = mappedStatus
        let name = normalizedName
        let reference = config.image ?? ""
        let command = (config.entrypoint?.values ?? []) + (config.cmd ?? [])
        let platformParts = parsedPlatform()
        let payload = DockerContainerSnapshotPayload(
            runtimeKind: Core.Runtime.Kind.docker,
            id: name.isEmpty ? shortID : name,
            status: .init(state: status.rawValue,
                          networks: networkStatuses(),
                          startedDate: parsedStartedDate()),
            configuration: .init(runtimeKind: Core.Runtime.Kind.docker,
                                 id: name.isEmpty ? shortID : name,
                                 image: .init(reference: reference),
                                 initProcess: .init(executable: command.first,
                                                    arguments: command,
                                                    environment: config.env ?? [],
                                                    workingDirectory: nilIfEmpty(config.workingDir),
                                                    terminal: config.tty ?? false),
                                 resources: .init(cpus: 0,
                                                  memoryInBytes: 0,
                                                  cpuOverhead: nil,
                                                  storage: nil),
                                 platform: .init(architecture: platformParts.architecture,
                                                 os: platformParts.os,
                                                 variant: platformParts.variant),
                                 labels: config.labels ?? [:],
                                 mounts: mountPayloads(),
                                 networks: networkAttachments(),
                                 publishedPorts: publishedPorts(),
                                 publishedSockets: [],
                                 dns: nil,
                                 sysctls: [:],
                                 capAdd: hostConfig?.capAdd ?? [],
                                 capDrop: hostConfig?.capDrop ?? [],
                                 rosetta: false,
                                 runtimeHandler: nilIfEmpty(hostConfig?.runtime),
                                 ssh: false,
                                 readOnly: hostConfig?.readonlyRootfs ?? false,
                                 useInit: hostConfig?.initProcess ?? false,
                                 virtualization: false,
                                 shmSize: hostConfig?.shmSize,
                                 stopSignal: nil,
                                 creationDate: created))
        let data = try Core.Container.JSON.encoder.encode(payload)
        return try Core.Container.JSON.decode(Core.Container.Snapshot.self, from: data)
    }

    private var normalizedName: String {
        (name ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private var shortID: String {
        String(id.prefix(12))
    }

    private var mappedStatus: Core.Runtime.Status {
        if state?.running == true { return .running }
        switch (state?.status ?? "").lowercased() {
        case "created", "paused", "exited", "dead": return .stopped
        case "running": return .running
        case "restarting": return .running
        case "removing": return .stopping
        default: return .unknown
        }
    }

    private func parsedStartedDate() -> Date? {
        guard let raw = state?.startedAt, !raw.isEmpty, !raw.hasPrefix("0001-") else { return nil }
        return Core.Container.JSON.parseDate(raw)
    }

    private func parsedPlatform() -> (os: String, architecture: String, variant: String?) {
        let parts = (platform ?? "linux/unknown").split(separator: "/").map(String.init)
        return (parts.first ?? "linux", parts.dropFirst().first ?? "unknown", parts.dropFirst(2).first)
    }

    private func networkStatuses() -> [DockerContainerSnapshotPayload.Status.Network] {
        (networkSettings?.networks ?? [:]).keys.sorted().map { key in
            let value = networkSettings?.networks?[key]
            return .init(network: key,
                         hostname: nil,
                         ipv4Address: nilIfEmpty(value?.ipAddress),
                         ipv4Gateway: nilIfEmpty(value?.gateway),
                         ipv6Address: nilIfEmpty(value?.globalIPv6Address),
                         macAddress: nilIfEmpty(value?.macAddress),
                         mtu: nil)
        }
    }

    private func networkAttachments() -> [DockerContainerSnapshotPayload.Configuration.NetworkAttachment] {
        let networks = networkSettings?.networks?.keys.sorted() ?? []
        if !networks.isEmpty {
            return networks.map { .init(network: $0) }
        }
        guard let mode = hostConfig?.networkMode, !mode.isEmpty else { return [] }
        return [.init(network: mode)]
    }

    private func mountPayloads() -> [DockerContainerSnapshotPayload.Configuration.Mount] {
        (mounts ?? []).compactMap { mount in
            guard let destination = mount.destination else { return nil }
            return .init(type: mount.type,
                         source: mount.source,
                         destination: destination,
                         target: destination,
                         readonly: mount.rw.map { !$0 })
        }
    }

    private func publishedPorts() -> [DockerContainerSnapshotPayload.Configuration.PublishedPort] {
        (hostConfig?.portBindings ?? [:]).flatMap { key, bindings -> [DockerContainerSnapshotPayload.Configuration.PublishedPort] in
            let parts = key.split(separator: "/").map(String.init)
            guard let containerPort = Int(parts.first ?? "") else { return [] }
            let proto = parts.dropFirst().first ?? "tcp"
            return (bindings ?? []).compactMap { binding in
                guard let host = binding.hostPort, let hostPort = Int(host) else { return nil }
                return .init(containerPort: containerPort,
                             hostPort: hostPort,
                             hostAddress: nilIfEmpty(binding.hostIP),
                             proto: proto,
                             count: nil)
            }
        }
    }
}

struct DockerImageListRow: Decodable {
    var repository: String
    var tag: String
    var digest: String
    var id: String

    enum CodingKeys: String, CodingKey {
        case repository = "Repository"
        case tag = "Tag"
        case digest = "Digest"
        case id = "ID"
    }

    var reference: String? {
        guard repository != "<none>", tag != "<none>" else { return nil }
        return "\(repository):\(tag)"
    }

    func coreImage() -> Core.Image.Resource? {
        guard let reference else { return nil }
        let descriptor = digest == "<none>" ? nil : Core.Container.Descriptor(digest: digest, mediaType: nil, size: nil)
        let configuration = Core.Image.Configuration(name: reference, descriptor: descriptor, creationDate: nil)
        return Core.Image.Resource(configuration: configuration,
                                   id: id,
                                   variants: [],
                                   runtimeKind: .docker)
    }
}

struct DockerImageInspect: Decodable {
    var id: String
    var repoTags: [String]?
    var repoDigests: [String]?
    var created: Date?
    var architecture: String?
    var os: String?
    var variant: String?
    var config: Config?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case repoDigests = "RepoDigests"
        case created = "Created"
        case architecture = "Architecture"
        case os = "Os"
        case variant = "Variant"
        case config = "Config"
    }

    struct Config: Decodable {
        var cmd: [String]?
        var entrypoint: DockerStringList?
        var env: [String]?
        var workingDir: String?
        var user: String?

        enum CodingKeys: String, CodingKey {
            case cmd = "Cmd"
            case entrypoint = "Entrypoint"
            case env = "Env"
            case workingDir = "WorkingDir"
            case user = "User"
        }
    }

    func coreImages(fallbackReference: String) -> [Core.Image.Resource] {
        let refs = (repoTags ?? []).isEmpty ? [fallbackReference] : (repoTags ?? [])
        let digest = repoDigests?.compactMap { $0.split(separator: "@").dropFirst().first.map(String.init) }.first
        return refs.map { reference in
            let descriptor = digest.map { Core.Container.Descriptor(digest: $0, mediaType: nil, size: nil) }
            let platform = Core.Container.Platform(architecture: architecture ?? "unknown",
                                                   os: os ?? "linux",
                                                   variant: nilIfEmpty(variant))
            let oci = Core.Image.VariantConfig.OCIConfig(cmd: config?.cmd,
                                                         entrypoint: config?.entrypoint?.values,
                                                         env: config?.env,
                                                         workingDir: nilIfEmpty(config?.workingDir),
                                                         user: nilIfEmpty(config?.user))
            let variant = Core.Image.Variant(digest: digest ?? id,
                                             size: nil,
                                             platform: platform,
                                             config: Core.Image.VariantConfig(architecture: architecture,
                                                                              os: os,
                                                                              created: created,
                                                                              config: oci,
                                                                              history: nil,
                                                                              rootfs: nil))
            return Core.Image.Resource(configuration: Core.Image.Configuration(name: reference,
                                                                               descriptor: descriptor,
                                                                               creationDate: created),
                                       id: id,
                                       variants: [variant],
                                       runtimeKind: .docker)
        }
    }
}

struct DockerNetworkRow: Decodable {
    var id: String
    var name: String
    var driver: String?
    var labels: String?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "Name"
        case driver = "Driver"
        case labels = "Labels"
    }

    func coreNetwork() -> Core.Network.Resource {
        Core.Network.Resource(configuration: Core.Network.Configuration(name: name,
                                                                        mode: nil,
                                                                        plugin: driver,
                                                                        creationDate: nil,
                                                                        labels: parseLabels(labels),
                                                                        options: nil),
                              id: id,
                              status: nil,
                              runtimeKind: .docker)
    }
}

struct DockerVolumeRow: Decodable {
    var name: String
    var driver: String?
    var labels: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case driver = "Driver"
        case labels = "Labels"
    }

    func coreVolume() -> Core.Volume.Resource {
        Core.Volume.Resource(configuration: Core.Volume.Configuration(name: name,
                                                                      source: nil,
                                                                      format: driver,
                                                                      sizeInBytes: nil,
                                                                      creationDate: nil,
                                                                      labels: parseLabels(labels)),
                             runtimeKind: .docker)
    }
}

struct DockerInfo: Decodable {
    var serverVersion: String?
    var operatingSystem: String?
    var architecture: String?
    var ncpu: Int?
    var memTotal: UInt64?

    enum CodingKeys: String, CodingKey {
        case serverVersion = "ServerVersion"
        case operatingSystem = "OperatingSystem"
        case architecture = "Architecture"
        case ncpu = "NCPU"
        case memTotal = "MemTotal"
    }

    var systemStatus: Core.System.Status {
        Core.System.Status(status: "running",
                           appRoot: nil,
                           installRoot: nil,
                           apiServerVersion: serverVersion,
                           apiServerCommit: nil,
                           apiServerBuild: nil,
                           apiServerAppName: "Docker")
    }

    var systemProperties: Core.System.Properties {
        Core.System.Properties(build: nil,
                               container: nil,
                               machine: .init(cpus: ncpu, memory: memTotal.map(String.init)),
                               kernel: nil)
    }
}

struct DockerStatsRow: Decodable {
    var id: String?
    var container: String?
    var name: String?
    var cpuPerc: String?
    var memUsage: String?
    var netIO: String?
    var blockIO: String?
    var pids: String?

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case container = "Container"
        case name = "Name"
        case cpuPerc = "CPUPerc"
        case memUsage = "MemUsage"
        case netIO = "NetIO"
        case blockIO = "BlockIO"
        case pids = "PIDs"
    }

    var snapshot: Core.Metrics.RuntimeStatsSnapshot {
        let memory = splitPair(memUsage).map { (parseByteSpec($0.0), parseByteSpec($0.1)) }
        let net = splitPair(netIO).map { (parseByteSpec($0.0), parseByteSpec($0.1)) }
        let block = splitPair(blockIO).map { (parseByteSpec($0.0), parseByteSpec($0.1)) }
        return Core.Metrics.RuntimeStatsSnapshot(
            id: name ?? container ?? id ?? "",
            cpuCoreFraction: parsePercent(cpuPerc).map { $0 / 100 },
            memoryUsageBytes: memory?.0,
            memoryLimitBytes: memory?.1,
            blockReadBytes: block?.0,
            blockWriteBytes: block?.1,
            networkRxBytes: net?.0,
            networkTxBytes: net?.1,
            numProcesses: pids.flatMap { UInt64($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }
}

enum DockerStringList: Decodable, Hashable {
    case string(String)
    case list([String])

    var values: [String] {
        switch self {
        case .string(let value): return value.isEmpty ? [] : [value]
        case .list(let values): return values
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([String].self) {
            self = .list(list)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            self = .list([])
        }
    }
}

private struct DockerContainerSnapshotPayload: Encodable {
    var runtimeKind: Core.Runtime.Kind
    var id: String
    var status: Status
    var configuration: Configuration

    struct Status: Encodable {
        var state: String
        var networks: [Network]
        var startedDate: Date?

        struct Network: Encodable {
            var network: String
            var hostname: String?
            var ipv4Address: String?
            var ipv4Gateway: String?
            var ipv6Address: String?
            var macAddress: String?
            var mtu: Int?
        }
    }

    struct Configuration: Encodable {
        var runtimeKind: Core.Runtime.Kind
        var id: String
        var image: Image
        var initProcess: InitProcess
        var resources: Resources
        var platform: Platform
        var labels: [String: String]
        var mounts: [Mount]
        var networks: [NetworkAttachment]
        var publishedPorts: [PublishedPort]
        var publishedSockets: [PublishedSocket]
        var dns: DNS?
        var sysctls: [String: String]
        var capAdd: [String]
        var capDrop: [String]
        var rosetta: Bool
        var runtimeHandler: String?
        var ssh: Bool
        var readOnly: Bool
        var useInit: Bool
        var virtualization: Bool
        var shmSize: UInt64?
        var stopSignal: String?
        var creationDate: Date?

        struct Image: Encodable { var reference: String }
        struct InitProcess: Encodable {
            var executable: String?
            var arguments: [String]
            var environment: [String]
            var workingDirectory: String?
            var terminal: Bool
        }
        struct Resources: Encodable {
            var cpus: Int
            var memoryInBytes: UInt64
            var cpuOverhead: Int?
            var storage: UInt64?
        }
        struct Platform: Encodable {
            var architecture: String
            var os: String
            var variant: String?
        }
        struct Mount: Encodable {
            var type: String?
            var source: String?
            var destination: String?
            var target: String?
            var readonly: Bool?
        }
        struct NetworkAttachment: Encodable {
            var network: String
            var options: Options? = nil
            struct Options: Encodable {
                var hostname: String?
                var mtu: Int?
            }
        }
        struct PublishedPort: Encodable {
            var containerPort: Int
            var hostPort: Int
            var hostAddress: String?
            var proto: String?
            var count: Int?
        }
        struct PublishedSocket: Encodable {
            var hostPath: String?
            var containerPath: String?
        }
        struct DNS: Encodable {
            var nameservers: [String]
            var searchDomains: [String]
            var options: [String]
            var domain: String?
        }
    }
}

private func nilIfEmpty(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
}

private func parseLabels(_ raw: String?) -> [String: String] {
    guard let raw, !raw.isEmpty else { return [:] }
    return raw.split(separator: ",").reduce(into: [:]) { result, part in
        let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
        guard let key = pieces.first, !key.isEmpty else { return }
        result[key] = pieces.count > 1 ? pieces[1] : ""
    }
}

private func splitPair(_ raw: String?) -> (String, String)? {
    guard let raw else { return nil }
    let parts = raw.components(separatedBy: " / ")
    guard parts.count == 2 else { return nil }
    return (parts[0], parts[1])
}

private func parsePercent(_ raw: String?) -> Double? {
    guard let raw else { return nil }
    return Double(raw.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
}

func parseByteSpec(_ raw: String) -> UInt64? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let range = trimmed.range(of: #"^[0-9]+(\.[0-9]+)?"#, options: .regularExpression),
          let number = Double(trimmed[range]) else { return nil }
    let suffix = trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces).lowercased()
    let multiplier: Double
    switch suffix {
    case "b", "": multiplier = 1
    case "kb": multiplier = 1_000
    case "mb": multiplier = 1_000_000
    case "gb": multiplier = 1_000_000_000
    case "tb": multiplier = 1_000_000_000_000
    case "kib": multiplier = 1_024
    case "mib": multiplier = 1_048_576
    case "gib": multiplier = 1_073_741_824
    case "tib": multiplier = 1_099_511_627_776
    default: multiplier = 1
    }
    return UInt64(number * multiplier)
}
