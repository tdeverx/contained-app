import Foundation
import Yams

/// A parsed `compose.yaml`, reduced to the subset Contained can prefill into Run specs. Anything not
/// translated is recorded in `warnings` so the user knows exactly what to wire up by hand.
public extension Core.Compose {
struct Project: Sendable, Hashable, Identifiable {
    public let name: String
    public let services: [Core.Compose.Service]
    public let warnings: [String]
    public var id: String { name }
}

/// One compose service, normalized to the fields that map onto `container run`.
struct Service: Sendable, Hashable, Identifiable {
    /// The services-map key — what `depends_on` references (distinct from `name`/`container_name`).
    public let key: String
    public let name: String
    public let image: String?
    public let platform: String?
    public let command: String?
    public let entrypoint: String?
    public let workingDir: String?
    public let user: String?
    public let cpus: String?
    public let memory: String?
    public let ports: [String]        // "host:container[/proto]"
    public let volumes: [String]      // "source:target[:ro]"
    public let environment: [String]  // "KEY=value"
    public let envFiles: [String]
    public let labels: [String]       // "KEY=value"
    public let restart: String?
    public let network: String?
    public let networkMode: String?
    public let readOnly: Bool
    public let initProcess: Bool
    public let interactive: Bool
    public let tty: Bool
    public let capAdd: [String]
    public let capDrop: [String]
    public let dns: [String]
    public let dnsSearch: [String]
    public let dnsOptions: [String]
    public let tmpfs: [String]
    public let ulimits: [String]
    public let dependsOn: [Core.Compose.Dependency]
    public let healthcheck: Core.Compose.Healthcheck?
    public let preservedFields: [Core.Field.Path: Core.Schema.Value]

    public var id: String { key }

    public init(key: String, name: String, image: String?, platform: String?, command: String?,
                entrypoint: String? = nil, workingDir: String? = nil, user: String? = nil,
                cpus: String? = nil, memory: String? = nil, ports: [String], volumes: [String],
                environment: [String], envFiles: [String] = [], labels: [String] = [], restart: String?,
                network: String? = nil, networkMode: String? = nil, readOnly: Bool = false, initProcess: Bool = false,
                interactive: Bool = false, tty: Bool = false, capAdd: [String] = [],
                capDrop: [String] = [], dns: [String] = [], dnsSearch: [String] = [],
                dnsOptions: [String] = [], tmpfs: [String] = [], ulimits: [String] = [],
                dependsOn: [Core.Compose.Dependency], healthcheck: Core.Compose.Healthcheck?,
                preservedFields: [Core.Field.Path: Core.Schema.Value] = [:]) {
        self.key = key; self.name = name; self.image = image; self.platform = platform; self.command = command
        self.entrypoint = entrypoint; self.workingDir = workingDir; self.user = user; self.cpus = cpus
        self.memory = memory; self.ports = ports; self.volumes = volumes; self.environment = environment
        self.envFiles = envFiles
        self.labels = labels; self.restart = restart; self.network = network; self.networkMode = networkMode; self.readOnly = readOnly
        self.initProcess = initProcess; self.interactive = interactive; self.tty = tty
        self.capAdd = capAdd; self.capDrop = capDrop; self.dns = dns; self.dnsSearch = dnsSearch
        self.dnsOptions = dnsOptions; self.tmpfs = tmpfs; self.ulimits = ulimits
        self.dependsOn = dependsOn; self.healthcheck = healthcheck
        self.preservedFields = preservedFields
    }
}

/// A `depends_on` edge with its start condition.
struct Dependency: Sendable, Hashable {
    public let service: String        // the depended-on service key
    public let condition: Core.Compose.Condition
    public init(service: String, condition: Core.Compose.Condition) {
        self.service = service; self.condition = condition
    }
}

enum Condition: String, Sendable, Hashable {
    case started = "service_started"
    case healthy = "service_healthy"
    case completed = "service_completed_successfully"
}

/// A parsed compose `healthcheck:` block (the subset Contained can run as an `exec` probe).
struct Healthcheck: Sendable, Hashable {
    public let test: [String]         // the probe argv (CMD-SHELL flattened to sh -c form)
    public let intervalSeconds: Int
    public let retries: Int
    public init(test: [String], intervalSeconds: Int, retries: Int) {
        self.test = test; self.intervalSeconds = intervalSeconds; self.retries = retries
    }
}

enum Error: Core.Error.PackageError, Equatable {
    case invalid(String)

    public var packageName: String { "ContainedCore" }
    public var packageErrorCode: String { "composeInvalid" }
    public var packageErrorContext: [String: String] {
        switch self {
        case .invalid(let reason): return ["reason": reason]
        }
    }
}

enum Parser {
    /// Parse compose YAML text. `projectName` defaults from the file's parent folder.
    public static func parse(_ yaml: String, projectName: String) throws -> Core.Compose.Project {
        let loaded: Any?
        do { loaded = try Yams.load(yaml: yaml) } catch { throw Core.Compose.Error.invalid(String(describing: error)) }
        guard let root = loaded as? [String: Any] else { throw Core.Compose.Error.invalid("Top level is not a mapping.") }

        var warnings: [String] = []
        // Top-level keys we don't translate.
        for key in root.keys where !["services", "version", "name"].contains(key) {
            warnings.append("Top-level `\(key)` isn't translated — set it up manually.")
        }

        guard let servicesMap = root["services"] as? [String: Any] else {
            throw Core.Compose.Error.invalid("No `services` section found.")
        }

        var services: [Core.Compose.Service] = []
        for name in servicesMap.keys.sorted() {
            guard let body = servicesMap[name] as? [String: Any] else { continue }
            services.append(service(name: name, body: body, warnings: &warnings))
        }
        let resolvedName = (root["name"] as? String) ?? projectName
        return Core.Compose.Project(name: resolvedName, services: services, warnings: warnings)
    }

    private static let supportedKeys: Set<String> =
        ["image", "command", "ports", "volumes", "environment", "restart", "container_name",
         "depends_on", "healthcheck", "platform", "entrypoint", "working_dir", "user", "cpus",
         "mem_limit", "env_file", "labels", "read_only", "init", "stdin_open",
         "tty", "cap_add", "cap_drop", "dns", "dns_search", "dns_opt", "tmpfs", "ulimits",
         "network_mode", "networks",
         "extra_hosts", "hostname", "domainname", "mac_address", "expose", "pull_policy",
         "attach", "logging", "label_file", "stop_signal", "stop_grace_period",
         "devices", "gpus", "group_add", "privileged", "security_opt", "sysctls",
         "cgroup", "userns_mode", "pid", "ipc", "uts", "cpu_shares", "cpu_quota",
         "cpu_period", "cpuset", "cpu_rt_runtime", "cpu_rt_period", "mem_reservation",
         "memswap_limit", "mem_swappiness", "oom_kill_disable", "oom_score_adj",
         "blkio_config", "storage_opt", "volumes_from", "secrets", "configs",
         "profiles", "deploy", "scale", "links", "provider", "models", "use_api_socket"]

    private static func service(name: String, body: [String: Any], warnings: inout [String]) -> Core.Compose.Service {
        for key in body.keys where !supportedKeys.contains(key) {
            warnings.append("`\(name).\(key)` isn't translated.")
        }
        let image = body["image"] as? String
        if image == nil, body["build"] != nil {
            warnings.append("`\(name)` uses `build:` — build the image first, then set its tag here.")
        }
        return Core.Compose.Service(
            key: name,
            name: (body["container_name"] as? String) ?? name,
            image: image,
            platform: body["platform"] as? String,
            command: Self.scalarOrJoined(body["command"]),
            entrypoint: Self.scalarOrJoined(body["entrypoint"]),
            workingDir: body["working_dir"] as? String,
            user: Self.stringValue(body["user"]),
            cpus: Self.stringValue(body["cpus"]),
            memory: Self.stringValue(body["mem_limit"]),
            ports: Self.ports(body["ports"], service: name, warnings: &warnings),
            volumes: Self.volumes(body["volumes"], service: name, warnings: &warnings),
            environment: Self.environment(body["environment"]),
            envFiles: Self.stringList(body["env_file"], service: name, key: "env_file", warnings: &warnings),
            labels: Self.keyValues(body["labels"]),
            restart: Self.restart(body["restart"]),
            network: Self.network(mode: body["network_mode"], networks: body["networks"]),
            networkMode: Self.stringValue(body["network_mode"]),
            readOnly: body["read_only"] as? Bool ?? false,
            initProcess: body["init"] as? Bool ?? false,
            interactive: body["stdin_open"] as? Bool ?? false,
            tty: body["tty"] as? Bool ?? false,
            capAdd: Self.stringList(body["cap_add"], service: name, key: "cap_add", warnings: &warnings),
            capDrop: Self.stringList(body["cap_drop"], service: name, key: "cap_drop", warnings: &warnings),
            dns: Self.stringList(body["dns"], service: name, key: "dns", warnings: &warnings),
            dnsSearch: Self.stringList(body["dns_search"], service: name, key: "dns_search", warnings: &warnings),
            dnsOptions: Self.stringList(body["dns_opt"], service: name, key: "dns_opt", warnings: &warnings),
            tmpfs: Self.stringList(body["tmpfs"], service: name, key: "tmpfs", warnings: &warnings),
            ulimits: Self.ulimits(body["ulimits"], service: name, warnings: &warnings),
            dependsOn: Self.dependencies(body["depends_on"]),
            healthcheck: Self.healthcheck(body["healthcheck"]),
            preservedFields: Self.preservedFields(body, service: name)
        )
    }

}

}
