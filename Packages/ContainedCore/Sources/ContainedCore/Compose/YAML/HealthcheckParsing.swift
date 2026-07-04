import Foundation

extension Core.Compose.Parser {
    /// Parse a `healthcheck:` block. `test` accepts `["CMD-SHELL", "<cmd>"]`, `["CMD", a, b]`, or a
    /// bare string; we normalize to an `exec` argv.
    static func healthcheck(_ value: Any?) -> Core.Compose.Healthcheck? {
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
    static func duration(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        guard let s = value as? String else { return nil }
        var total = 0
        var number = ""
        for ch in s {
            if ch.isNumber {
                number.append(ch)
            } else {
                let n = Int(number) ?? 0
                number = ""
                switch ch {
                case "h": total += n * 3600
                case "m": total += n * 60
                case "s": total += n
                default: break
                }
            }
        }
        if let trailing = Int(number) { total += trailing }
        return total > 0 ? total : nil
    }
}
