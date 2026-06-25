import Foundation
import Yams

/// A parsed `compose.yaml`, reduced to the subset Contained can launch as a Stack. Anything not
/// translated is recorded in `warnings` so the user knows exactly what to wire up by hand.
public struct ComposeProject: Sendable, Hashable, Identifiable {
    public let name: String
    public let services: [ComposeService]
    public let warnings: [String]
    public var id: String { name }
}

/// One compose service, normalized to the fields that map onto `container run`.
public struct ComposeService: Sendable, Hashable, Identifiable {
    /// The services-map key — what `depends_on` references (distinct from `name`/`container_name`).
    public let key: String
    public let name: String
    public let image: String?
    public let command: String?
    public let ports: [String]        // "host:container[/proto]"
    public let volumes: [String]      // "source:target[:ro]"
    public let environment: [String]  // "KEY=value"
    public let restart: String?
    public let dependsOn: [ComposeDependency]
    public let healthcheck: ComposeHealthcheck?

    public var id: String { key }

    public init(key: String, name: String, image: String?, command: String?, ports: [String],
                volumes: [String], environment: [String], restart: String?,
                dependsOn: [ComposeDependency], healthcheck: ComposeHealthcheck?) {
        self.key = key; self.name = name; self.image = image; self.command = command
        self.ports = ports; self.volumes = volumes; self.environment = environment
        self.restart = restart; self.dependsOn = dependsOn; self.healthcheck = healthcheck
    }
}

/// A `depends_on` edge with its start condition.
public struct ComposeDependency: Sendable, Hashable {
    public let service: String        // the depended-on service key
    public let condition: ComposeCondition
    public init(service: String, condition: ComposeCondition) {
        self.service = service; self.condition = condition
    }
}

public enum ComposeCondition: String, Sendable, Hashable {
    case started = "service_started"
    case healthy = "service_healthy"
    case completed = "service_completed_successfully"
}

/// A parsed compose `healthcheck:` block (the subset Contained can run as an `exec` probe).
public struct ComposeHealthcheck: Sendable, Hashable {
    public let test: [String]         // the probe argv (CMD-SHELL flattened to sh -c form)
    public let intervalSeconds: Int
    public let retries: Int
    public init(test: [String], intervalSeconds: Int, retries: Int) {
        self.test = test; self.intervalSeconds = intervalSeconds; self.retries = retries
    }
}

public enum ComposeError: Error, Sendable { case invalid(String) }

/// Dependency ordering for a stack launch. Pure + testable (factored like `RestartDecision`).
public enum ComposeOrder {
    /// Topologically sort services by `depends_on` (dependencies first). On a cycle, returns the
    /// declared order with `cycle == true` so the caller can warn and fall back gracefully.
    public static func sorted(_ services: [ComposeService]) -> (order: [String], cycle: Bool) {
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

public enum ComposeParser {
    /// Parse compose YAML text. `projectName` defaults from the file's parent folder.
    public static func parse(_ yaml: String, projectName: String) throws -> ComposeProject {
        let loaded: Any?
        do { loaded = try Yams.load(yaml: yaml) } catch { throw ComposeError.invalid(String(describing: error)) }
        guard let root = loaded as? [String: Any] else { throw ComposeError.invalid("Top level is not a mapping.") }

        var warnings: [String] = []
        // Top-level keys we don't translate.
        for key in root.keys where !["services", "version", "name"].contains(key) {
            warnings.append("Top-level `\(key)` isn't translated — set it up manually.")
        }

        guard let servicesMap = root["services"] as? [String: Any] else {
            throw ComposeError.invalid("No `services` section found.")
        }

        var services: [ComposeService] = []
        for name in servicesMap.keys.sorted() {
            guard let body = servicesMap[name] as? [String: Any] else { continue }
            services.append(service(name: name, body: body, warnings: &warnings))
        }
        let resolvedName = (root["name"] as? String) ?? projectName
        return ComposeProject(name: resolvedName, services: services, warnings: warnings)
    }

    private static let supportedKeys: Set<String> =
        ["image", "command", "ports", "volumes", "environment", "restart", "container_name",
         "depends_on", "healthcheck"]

    private static func service(name: String, body: [String: Any], warnings: inout [String]) -> ComposeService {
        for key in body.keys where !supportedKeys.contains(key) {
            warnings.append("`\(name).\(key)` isn't translated.")
        }
        let image = body["image"] as? String
        if image == nil, body["build"] != nil {
            warnings.append("`\(name)` uses `build:` — build the image first, then set its tag here.")
        }
        return ComposeService(
            key: name,
            name: (body["container_name"] as? String) ?? name,
            image: image,
            command: scalarOrJoined(body["command"]),
            ports: stringList(body["ports"], service: name, key: "ports", warnings: &warnings),
            volumes: stringList(body["volumes"], service: name, key: "volumes", warnings: &warnings),
            environment: environment(body["environment"]),
            restart: body["restart"] as? String,
            dependsOn: dependencies(body["depends_on"]),
            healthcheck: healthcheck(body["healthcheck"])
        )
    }

    /// Parse `depends_on` in both the short list form (`[a, b]` → start order) and the long mapping
    /// form (`{a: {condition: service_healthy}}`).
    private static func dependencies(_ value: Any?) -> [ComposeDependency] {
        if let list = value as? [Any] {
            return list.compactMap { $0 as? String }.map { ComposeDependency(service: $0, condition: .started) }
        }
        if let map = value as? [String: Any] {
            return map.keys.sorted().map { service in
                let condition = (map[service] as? [String: Any])?["condition"] as? String
                return ComposeDependency(service: service,
                                         condition: condition.flatMap(ComposeCondition.init) ?? .started)
            }
        }
        return []
    }

    /// Parse a `healthcheck:` block. `test` accepts `["CMD-SHELL", "<cmd>"]`, `["CMD", a, b]`, or a
    /// bare string; we normalize to an `exec` argv.
    private static func healthcheck(_ value: Any?) -> ComposeHealthcheck? {
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
        return ComposeHealthcheck(test: test, intervalSeconds: interval, retries: retries)
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
        if let list = value as? [Any] { return list.compactMap { $0 as? String }.joined(separator: " ") }
        return nil
    }

    /// A list of short-form strings; long-form (mapping) entries are reported, not translated.
    private static func stringList(_ value: Any?, service: String, key: String, warnings: inout [String]) -> [String] {
        guard let list = value as? [Any] else {
            if value != nil { warnings.append("`\(service).\(key)` uses an unsupported shape.") }
            return []
        }
        var out: [String] = []
        for entry in list {
            if let s = entry as? String { out.append(s) }
            else { warnings.append("`\(service).\(key)` long syntax isn't translated.") }
        }
        return out
    }

    /// Environment as a list ("KEY=val") or a mapping ({KEY: val}) → normalized "KEY=value".
    private static func environment(_ value: Any?) -> [String] {
        if let list = value as? [Any] { return list.compactMap { $0 as? String } }
        if let map = value as? [String: Any] {
            return map.keys.sorted().map { "\($0)=\(stringify(map[$0]))" }
        }
        return []
    }

    private static func stringify(_ value: Any?) -> String {
        switch value {
        case let s as String: return s
        case let b as Bool: return b ? "true" : "false"
        case let i as Int: return String(i)
        case let d as Double: return String(d)
        default: return ""
        }
    }
}
