import Foundation

extension Core.Compose.Parser {
    /// Parse ports in short syntax or Compose long syntax into `container run --publish` specs.
    static func ports(_ value: Any?, service: String, warnings: inout [String]) -> [String] {
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
    static func volumes(_ value: Any?, service: String, warnings: inout [String]) -> [String] {
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
    static func ulimits(_ value: Any?, service: String, warnings: inout [String]) -> [String] {
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
    static func restart(_ value: Any?) -> String? {
        let raw = stringValue(value)
        return raw == "unless-stopped" ? "always" : raw
    }

    /// Prefer explicit `network_mode`; otherwise use the first named service network. Compose
    /// `host` matches the default run form network for Apple's runtime, so leave it blank.
    static func network(mode: Any?, networks: Any?) -> String? {
        if let mode = stringValue(mode) { return mode == "host" ? nil : mode }
        if let list = networks as? [Any] { return list.compactMap(stringValue).first }
        if let map = networks as? [String: Any] { return map.keys.sorted().first }
        return nil
    }
}
