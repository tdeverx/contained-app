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

/// Dependency ordering for a stack launch. Pure + testable (factored like `Core.Container.RestartDecision`).
enum Order {
    /// Topologically sort services by `depends_on` (dependencies first). On a cycle, returns the
    /// declared order with `cycle == true` so the caller can warn and fall back gracefully.
    public static func sorted(_ services: [Core.Compose.Service]) -> (order: [String], cycle: Bool) {
        let keys = services.map(\.key)
        let known = Set(keys)
        var edges: [String: [String]] = [:]
        for service in services {
            edges[service.key] = service.dependsOn.map(\.service).filter { known.contains($0) }
        }
        var state: [String: Int] = [:]   // 0 = unseen, 1 = visiting, 2 = done
        var result: [String] = []
        var cycle = false

        func visit(_ key: String) {
            switch state[key] ?? 0 {
            case 1: cycle = true; return
            case 2: return
            default: state[key] = 1
            }
            for dep in edges[key] ?? [] { visit(dep) }
            state[key] = 2
            result.append(key)
        }
        for key in keys { visit(key) }
        return cycle ? (keys, true) : (result, false)
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
            command: scalarOrJoined(body["command"]),
            entrypoint: scalarOrJoined(body["entrypoint"]),
            workingDir: body["working_dir"] as? String,
            user: stringValue(body["user"]),
            cpus: stringValue(body["cpus"]),
            memory: stringValue(body["mem_limit"]),
            ports: ports(body["ports"], service: name, warnings: &warnings),
            volumes: volumes(body["volumes"], service: name, warnings: &warnings),
            environment: environment(body["environment"]),
            envFiles: stringList(body["env_file"], service: name, key: "env_file", warnings: &warnings),
            labels: keyValues(body["labels"]),
            restart: restart(body["restart"]),
            network: network(mode: body["network_mode"], networks: body["networks"]),
            networkMode: stringValue(body["network_mode"]),
            readOnly: body["read_only"] as? Bool ?? false,
            initProcess: body["init"] as? Bool ?? false,
            interactive: body["stdin_open"] as? Bool ?? false,
            tty: body["tty"] as? Bool ?? false,
            capAdd: stringList(body["cap_add"], service: name, key: "cap_add", warnings: &warnings),
            capDrop: stringList(body["cap_drop"], service: name, key: "cap_drop", warnings: &warnings),
            dns: stringList(body["dns"], service: name, key: "dns", warnings: &warnings),
            dnsSearch: stringList(body["dns_search"], service: name, key: "dns_search", warnings: &warnings),
            dnsOptions: stringList(body["dns_opt"], service: name, key: "dns_opt", warnings: &warnings),
            tmpfs: stringList(body["tmpfs"], service: name, key: "tmpfs", warnings: &warnings),
            ulimits: ulimits(body["ulimits"], service: name, warnings: &warnings),
            dependsOn: dependencies(body["depends_on"]),
            healthcheck: healthcheck(body["healthcheck"]),
            preservedFields: preservedFields(body, service: name)
        )
    }

    /// Parse `depends_on` in both the short list form (`[a, b]` → start order) and the long mapping
    /// form (`{a: {condition: service_healthy}}`).
    private static func dependencies(_ value: Any?) -> [Core.Compose.Dependency] {
        if let list = value as? [Any] {
            return list.compactMap { $0 as? String }.map { Core.Compose.Dependency(service: $0, condition: .started) }
        }
        if let map = value as? [String: Any] {
            return map.keys.sorted().map { service in
                let condition = (map[service] as? [String: Any])?["condition"] as? String
                return Core.Compose.Dependency(service: service,
                                         condition: condition.flatMap(Core.Compose.Condition.init) ?? .started)
            }
        }
        return []
    }

    private static func preservedFields(_ body: [String: Any], service: String) -> [Core.Field.Path: Core.Schema.Value] {
        var fields: [Core.Field.Path: Core.Schema.Value] = [:]
        putStringList(&fields, .networkExtraHosts, body["extra_hosts"])
        putString(&fields, .networkHostname, body["hostname"])
        putString(&fields, .networkDomainName, body["domainname"])
        putString(&fields, .networkMacAddress, body["mac_address"])
        putStringList(&fields, .networkExpose, body["expose"])
        putString(&fields, .imagePullPolicy, body["pull_policy"])
        putStringOrBoolList(&fields, .processAttachStreams, body["attach"])
        putLogging(&fields, body["logging"])
        putStringList(&fields, .metadataLabelFiles, body["label_file"])
        putString(&fields, .lifecycleStopSignal, body["stop_signal"])
        putString(&fields, .lifecycleStopGracePeriod, body["stop_grace_period"])
        putStringList(&fields, .devices, body["devices"])
        putString(&fields, .gpus, body["gpus"])
        putStringList(&fields, .processSupplementalGroups, body["group_add"])
        putBool(&fields, .securityPrivileged, body["privileged"])
        putStringList(&fields, .securityOptions, body["security_opt"])
        putKeyValues(&fields, .kernelSysctls, body["sysctls"])
        putString(&fields, .namespaceCgroup, body["cgroup"])
        putString(&fields, .namespaceUser, body["userns_mode"])
        putString(&fields, .namespacePID, body["pid"])
        putString(&fields, .namespaceIPC, body["ipc"])
        putString(&fields, .namespaceUTS, body["uts"])
        putString(&fields, .resourcesCPUShares, body["cpu_shares"])
        putString(&fields, .resourcesCPUQuota, body["cpu_quota"])
        putString(&fields, .resourcesCPUPeriod, body["cpu_period"])
        putString(&fields, .resourcesCPUSet, body["cpuset"])
        putString(&fields, .resourcesCPURealtimeRuntime, body["cpu_rt_runtime"])
        putString(&fields, .resourcesCPURealtimePeriod, body["cpu_rt_period"])
        putString(&fields, .resourcesMemoryReservation, body["mem_reservation"])
        putString(&fields, .resourcesMemorySwapLimit, body["memswap_limit"])
        putString(&fields, .resourcesMemorySwappiness, body["mem_swappiness"])
        putBool(&fields, .resourcesOOMKillDisable, body["oom_kill_disable"])
        putString(&fields, .resourcesOOMScoreAdjust, body["oom_score_adj"])
        putString(&fields, .resourcesBlockIO, body["blkio_config"].map(stringify))
        putKeyValues(&fields, .storageOptions, body["storage_opt"])
        putStringList(&fields, .storageVolumesFrom, body["volumes_from"])
        putStringList(&fields, .composeSecrets, body["secrets"])
        putStringList(&fields, .composeConfigs, body["configs"])
        putStringList(&fields, .composeProfiles, body["profiles"])
        putString(&fields, .composeDeploy, body["deploy"].map(stringify))
        putString(&fields, .composeScale, body["scale"])
        putStringList(&fields, .composeLinks, body["links"])
        let dependencies = dependencies(body["depends_on"])
        if !dependencies.isEmpty {
            fields[.composeDependsOn] = .stringList(dependencies.map { "\($0.service)=\($0.condition.rawValue)" })
        }
        putString(&fields, .composeProvider, body["provider"].map(stringify))
        putStringList(&fields, .composeModels, body["models"])
        putBool(&fields, .composeUseAPISocket, body["use_api_socket"])
        return fields
    }

    /// Parse a `healthcheck:` block. `test` accepts `["CMD-SHELL", "<cmd>"]`, `["CMD", a, b]`, or a
    /// bare string; we normalize to an `exec` argv.
    private static func healthcheck(_ value: Any?) -> Core.Compose.Healthcheck? {
        guard let map = value as? [String: Any] else { return nil }
        if (map["disable"] as? Bool) == true { return nil }
        let test: [String]
        switch map["test"] {
        case let s as String: test = ["sh", "-c", s]
        case let list as [Any]:
            let parts = list.compactMap { $0 as? String }
            if parts.first == "CMD-SHELL" { test = ["sh", "-c", parts.dropFirst().joined(separator: " ")] }
            else if parts.first == "CMD" { test = Array(parts.dropFirst()) }
            else { test = parts }
        default: return nil
        }
        guard !test.isEmpty else { return nil }
        let interval = duration(map["interval"]) ?? 30
        let retries = (map["retries"] as? Int) ?? 3
        return Core.Compose.Healthcheck(test: test, intervalSeconds: interval, retries: retries)
    }

    /// Parse a compose duration like "30s", "1m30s", or a bare number of seconds.
    private static func duration(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        guard let s = value as? String else { return nil }
        var total = 0, number = ""
        for ch in s {
            if ch.isNumber { number.append(ch) }
            else {
                let n = Int(number) ?? 0; number = ""
                switch ch { case "h": total += n * 3600; case "m": total += n * 60; case "s": total += n; default: break }
            }
        }
        if let trailing = Int(number) { total += trailing }   // bare seconds
        return total > 0 ? total : nil
    }

    /// A scalar string, or a list joined with spaces (compose `command` accepts both).
    private static func scalarOrJoined(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let list = value as? [Any] { return list.compactMap(stringValue).joined(separator: " ") }
        return nil
    }

    /// A scalar string/number/bool rendered as text.
    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let s as String: return s
        case let i as Int: return String(i)
        case let d as Double: return String(d)
        case let b as Bool: return b ? "true" : "false"
        default: return nil
        }
    }

    /// A list of short-form strings; long-form (mapping) entries are reported, not translated.
    private static func stringList(_ value: Any?, service: String, key: String, warnings: inout [String]) -> [String] {
        if let scalar = stringValue(value) { return [scalar] }
        guard let list = value as? [Any] else {
            if value != nil { warnings.append("`\(service).\(key)` uses an unsupported shape.") }
            return []
        }
        var out: [String] = []
        for entry in list {
            if let s = stringValue(entry) { out.append(s) }
            else { warnings.append("`\(service).\(key)` long syntax isn't translated.") }
        }
        return out
    }

    /// Environment as a list ("KEY=val") or a mapping ({KEY: val}) → normalized "KEY=value".
    private static func environment(_ value: Any?) -> [String] {
        if let list = value as? [Any] { return list.compactMap(stringValue) }
        return keyValues(value)
    }

    /// Labels as a list ("KEY=val") or a mapping ({KEY: val}) → normalized "KEY=value".
    private static func keyValues(_ value: Any?) -> [String] {
        if let list = value as? [Any] { return list.compactMap(stringValue) }
        if let map = value as? [String: Any] {
            return map.keys.sorted().map { "\($0)=\(stringify(map[$0]))" }
        }
        return []
    }

    /// Parse ports in short syntax or Compose long syntax into `container run --publish` specs.
    private static func ports(_ value: Any?, service: String, warnings: inout [String]) -> [String] {
        guard let list = value as? [Any] else {
            if value != nil { warnings.append("`\(service).ports` uses an unsupported shape.") }
            return []
        }
        var out: [String] = []
        for entry in list {
            if let s = stringValue(entry) {
                if s.contains(":") {
                    out.append(s)
                } else {
                    warnings.append("`\(service).ports` entry `\(s)` has no host port to publish.")
                }
            } else if let map = entry as? [String: Any] {
                guard let target = stringValue(map["target"]) else {
                    warnings.append("`\(service).ports` long syntax is missing `target`.")
                    continue
                }
                guard let published = stringValue(map["published"]) else {
                    warnings.append("`\(service).ports` entry for target `\(target)` has no published host port.")
                    continue
                }
                let hostIP = stringValue(map["host_ip"])
                let protocolName = (stringValue(map["protocol"]) ?? "tcp").lowercased()
                var spec = [hostIP, published, target].compactMap { value in
                    let trimmed = value?.trimmingCharacters(in: .whitespaces)
                    return trimmed?.isEmpty == false ? trimmed : nil
                }.joined(separator: ":")
                if protocolName != "tcp" { spec += "/\(protocolName)" }
                out.append(spec)
            } else {
                warnings.append("`\(service).ports` entry isn't translated.")
            }
        }
        return out
    }

    /// Parse bind/volume mounts in short syntax or Compose long syntax into `--volume` specs.
    private static func volumes(_ value: Any?, service: String, warnings: inout [String]) -> [String] {
        guard let list = value as? [Any] else {
            if value != nil { warnings.append("`\(service).volumes` uses an unsupported shape.") }
            return []
        }
        var out: [String] = []
        for entry in list {
            if let s = stringValue(entry) {
                out.append(s)
            } else if let map = entry as? [String: Any],
                      let source = stringValue(map["source"]),
                      let target = stringValue(map["target"]) {
                var spec = "\(source):\(target)"
                if (map["read_only"] as? Bool) == true { spec += ":ro" }
                out.append(spec)
            } else {
                warnings.append("`\(service).volumes` entry isn't translated.")
            }
        }
        return out
    }

    /// Parse Compose ulimits into `type=soft[:hard]` entries.
    private static func ulimits(_ value: Any?, service: String, warnings: inout [String]) -> [String] {
        if let list = value as? [Any] { return list.compactMap(stringValue) }
        guard let map = value as? [String: Any] else {
            if value != nil { warnings.append("`\(service).ulimits` uses an unsupported shape.") }
            return []
        }
        return map.keys.sorted().compactMap { key in
            if let scalar = stringValue(map[key]) { return "\(key)=\(scalar)" }
            if let limits = map[key] as? [String: Any],
               let soft = stringValue(limits["soft"]) {
                let hard = stringValue(limits["hard"])
                return hard == nil ? "\(key)=\(soft)" : "\(key)=\(soft):\(hard!)"
            }
            warnings.append("`\(service).ulimits.\(key)` isn't translated.")
            return nil
        }
    }

    /// Compose `unless-stopped` matches the app's existing `always` policy because user-initiated
    /// stops are already suppressed by the watchdog.
    private static func restart(_ value: Any?) -> String? {
        let raw = stringValue(value)
        return raw == "unless-stopped" ? "always" : raw
    }

    /// Prefer explicit `network_mode`; otherwise use the first named service network. Compose
    /// `host` matches the default run form network for Apple's runtime, so leave it blank.
    private static func network(mode: Any?, networks: Any?) -> String? {
        if let mode = stringValue(mode) { return mode == "host" ? nil : mode }
        if let list = networks as? [Any] { return list.compactMap(stringValue).first }
        if let map = networks as? [String: Any] { return map.keys.sorted().first }
        return nil
    }

    private static func putString(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                  _ path: Core.Field.Path,
                                  _ value: Any?) {
        guard let string = stringValue(value), !string.isEmpty else { return }
        fields[path] = .string(string)
    }

    private static func putBool(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                _ path: Core.Field.Path,
                                _ value: Any?) {
        guard let bool = value as? Bool else { return }
        fields[path] = .bool(bool)
    }

    private static func putStringList(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                      _ path: Core.Field.Path,
                                      _ value: Any?) {
        let values: [String]
        if let scalar = stringValue(value) {
            values = [scalar]
        } else if let list = value as? [Any] {
            values = list.map(stringify).filter { !$0.isEmpty }
        } else if let map = value as? [String: Any] {
            values = map.keys.sorted().map { key in
                let rendered = stringify(map[key])
                return rendered.isEmpty ? key : "\(key)=\(rendered)"
            }
        } else {
            values = []
        }
        guard !values.isEmpty else { return }
        fields[path] = .stringList(values)
    }

    private static func putStringOrBoolList(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                            _ path: Core.Field.Path,
                                            _ value: Any?) {
        if let bool = value as? Bool {
            fields[path] = .stringList([String(bool)])
            return
        }
        putStringList(&fields, path, value)
    }

    private static func putKeyValues(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                     _ path: Core.Field.Path,
                                     _ value: Any?) {
        let values = keyValues(value).compactMap { entry -> Core.Container.KeyValue? in
            guard let eq = entry.firstIndex(of: "=") else { return nil }
            return Core.Container.KeyValue(key: String(entry[..<eq]),
                                           value: String(entry[entry.index(after: eq)...]))
        }
        guard !values.isEmpty else { return }
        fields[path] = .keyValueList(values)
    }

    private static func putLogging(_ fields: inout [Core.Field.Path: Core.Schema.Value],
                                   _ value: Any?) {
        guard let map = value as? [String: Any] else { return }
        putString(&fields, .loggingDriver, map["driver"])
        putKeyValues(&fields, .loggingOptions, map["options"])
    }

    private static func stringify(_ value: Any?) -> String {
        switch value {
        case let s as String: return s
        case let b as Bool: return b ? "true" : "false"
        case let i as Int: return String(i)
        case let d as Double: return String(d)
        case let list as [Any]: return list.map(stringify).joined(separator: ",")
        case let map as [String: Any]:
            return map.keys.sorted().map { "\($0)=\(stringify(map[$0]))" }.joined(separator: ",")
        default: return ""
        }
    }
}

}
