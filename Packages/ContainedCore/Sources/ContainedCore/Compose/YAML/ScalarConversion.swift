import Foundation

extension Core.Compose.Parser {
    /// A scalar string, or a list joined with spaces (compose `command` accepts both).
    static func scalarOrJoined(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let list = value as? [Any] { return list.compactMap(stringValue).joined(separator: " ") }
        return nil
    }

    /// A scalar string/number/bool rendered as text.
    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let s as String: return s
        case let i as Int: return String(i)
        case let d as Double: return String(d)
        case let b as Bool: return b ? "true" : "false"
        default: return nil
        }
    }

    /// A list of short-form strings; long-form (mapping) entries are reported, not translated.
    static func stringList(_ value: Any?, service: String, key: String, warnings: inout [String]) -> [String] {
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

    /// Environment as a list ("KEY=val") or a mapping ({KEY: val}) -> normalized "KEY=value".
    static func environment(_ value: Any?) -> [String] {
        if let list = value as? [Any] { return list.compactMap(stringValue) }
        return keyValues(value)
    }

    /// Labels as a list ("KEY=val") or a mapping ({KEY: val}) -> normalized "KEY=value".
    static func keyValues(_ value: Any?) -> [String] {
        if let list = value as? [Any] { return list.compactMap(stringValue) }
        if let map = value as? [String: Any] {
            return map.keys.sorted().map { "\($0)=\(stringify(map[$0]))" }
        }
        return []
    }

    static func stringify(_ value: Any?) -> String {
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
