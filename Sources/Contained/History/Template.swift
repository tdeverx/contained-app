import Foundation
import SwiftData

/// A saved container recipe — a named `RunSpec`, persisted (encoded) so it can prefill the edit form
/// later. Stored in the same SwiftData container as the history models.
@Model
final class Template {
    var name: String
    var createdAt: Date
    var specData: Data

    init(name: String, spec: RunSpec, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
        self.specData = (try? JSONEncoder().encode(spec)) ?? Data()
    }

    var spec: RunSpec? { try? JSONDecoder().decode(RunSpec.self, from: specData) }
}

/// A few ready-to-run starters offered alongside the user's saved templates.
enum BuiltinTemplate {
    static let all: [(name: String, symbol: String, spec: RunSpec)] = [
        make("Postgres", symbol: "cylinder.split.1x2", image: "postgres:16",
             ports: [("5432", "5432")], env: [("POSTGRES_PASSWORD", "postgres")]),
        make("Redis", symbol: "bolt.horizontal", image: "redis:7", ports: [("6379", "6379")]),
        make("nginx", symbol: "globe", image: "nginx:latest", ports: [("8080", "80")]),
        make("Alpine (shell)", symbol: "terminal", image: "alpine:latest", command: "sleep infinity"),
    ]

    private static func make(_ name: String, symbol: String, image: String,
                             command: String = "", ports: [(String, String)] = [],
                             env: [(String, String)] = []) -> (name: String, symbol: String, spec: RunSpec) {
        var spec = RunSpec()
        spec.image = image
        spec.command = command
        spec.ports = ports.map { PortMap(hostPort: $0.0, containerPort: $0.1, proto: "tcp") }
        spec.env = env.map { KeyValue(key: $0.0, value: $0.1) }
        return (name, symbol, spec)
    }
}
