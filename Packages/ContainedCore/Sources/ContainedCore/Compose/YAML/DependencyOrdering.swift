import Foundation

public extension Core.Compose {
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
}

extension Core.Compose.Parser {
    /// Parse `depends_on` in both the short list form (`[a, b]` -> start order) and the long mapping
    /// form (`{a: {condition: service_healthy}}`).
    static func dependencies(_ value: Any?) -> [Core.Compose.Dependency] {
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
}
