import Foundation

public struct ContainerCreateKeyValue: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var key: String
    public var value: String

    public init(key: String = "", value: String = "") {
        self.key = key
        self.value = value
    }

    public var isValid: Bool {
        !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

public struct ContainerCreatePort: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var hostPort: String
    public var containerPort: String
    public var proto: String

    public init(hostPort: String = "", containerPort: String = "", proto: String = "tcp") {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.proto = proto
    }

    public var isValid: Bool {
        !hostPort.isEmpty && !containerPort.isEmpty
    }

    public var spec: String {
        let base = "\(hostPort):\(containerPort)"
        return proto == "tcp" ? base : "\(base)/\(proto)"
    }

    private enum CodingKeys: String, CodingKey {
        case hostPort
        case containerPort
        case proto
    }
}

public struct ContainerCreateVolume: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var source: String
    public var target: String
    public var readOnly: Bool

    public init(source: String = "", target: String = "", readOnly: Bool = false) {
        self.source = source
        self.target = target
        self.readOnly = readOnly
    }

    public var isValid: Bool {
        !source.isEmpty && !target.isEmpty
    }

    public var spec: String {
        let base = "\(source):\(target)"
        return readOnly ? "\(base):ro" : base
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case target
        case readOnly
    }
}

public struct ContainerCreateSocket: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var hostPath: String
    public var containerPath: String

    public init(hostPath: String = "", containerPath: String = "") {
        self.hostPath = hostPath
        self.containerPath = containerPath
    }

    public var isValid: Bool {
        !hostPath.isEmpty && !containerPath.isEmpty
    }

    public var spec: String {
        "\(hostPath):\(containerPath)"
    }

    private enum CodingKeys: String, CodingKey {
        case hostPath
        case containerPath
    }
}

public struct ContainerImageDefaults: Codable, Equatable, Sendable {
    public var command: [String]
    public var entrypoint: [String]
    public var workingDirectory: String?
    public var user: String?
    public var environment: [ContainerCreateKeyValue]

    public init(command: [String] = [],
                entrypoint: [String] = [],
                workingDirectory: String? = nil,
                user: String? = nil,
                environment: [ContainerCreateKeyValue] = []) {
        self.command = command
        self.entrypoint = entrypoint
        self.workingDirectory = workingDirectory
        self.user = user
        self.environment = environment
    }
}

public struct ContainerCreateResult: Codable, Equatable, Sendable {
    public var id: String?
    public var output: String

    public init(id: String? = nil, output: String = "") {
        self.id = id
        self.output = output
    }
}

public struct ContainerCreateRequest: Codable, Equatable, Sendable {
    public var runtimeKind: RuntimeKind = .appleContainer
    public var image = ""
    public var platform = ""
    public var name = ""
    public var command: [String] = []
    public var entrypoint = ""
    public var detach = true
    public var removeOnExit = false
    public var interactive = false
    public var tty = false
    public var cpus = ""
    public var memory = ""
    public var env: [ContainerCreateKeyValue] = []
    public var envFiles: [String] = []
    public var ports: [ContainerCreatePort] = []
    public var volumes: [ContainerCreateVolume] = []
    public var mounts: [String] = []
    public var sockets: [ContainerCreateSocket] = []
    public var labels: [ContainerCreateKeyValue] = []
    public var restart: RestartPolicy = .no
    public var readOnly = false
    public var useInit = false
    public var rosetta = false
    public var ssh = false
    public var virtualization = false
    public var workingDir = ""
    public var user = ""
    public var uid = ""
    public var gid = ""
    public var shmSize = ""
    public var capAdd: [String] = []
    public var capDrop: [String] = []
    public var cidFile = ""
    public var initImage = ""
    public var kernel = ""
    public var network = ""
    public var noDNS = false
    public var dns: [String] = []
    public var dnsDomain = ""
    public var dnsSearch: [String] = []
    public var dnsOption: [String] = []
    public var tmpfs: [String] = []
    public var ulimits: [String] = []
    public var runtime = ""
    public var scheme = ""
    public var progress = ""
    public var maxConcurrentDownloads = ""

    public init() {}

    public var effectiveName: String? {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
    }

    public func allLabelArguments() -> [String] {
        var result: [String: String] = [:]
        for label in labels where label.isValid {
            result[label.key] = label.value
        }
        if restart != .no {
            result["contained.restart"] = restart.rawValue
        }
        return result.map { "\($0.key)=\($0.value)" }.sorted()
    }
}
