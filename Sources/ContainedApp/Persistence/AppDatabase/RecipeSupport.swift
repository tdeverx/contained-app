import Foundation
import ContainedCore

/// A saved container recipe — a named `ContainerFormState`, persisted (encoded) so it can prefill the edit form
/// later. Stored as a `RecipeRecord` in the app database.
extension RecipeRecord {
    static func make(name: String, spec: ContainerFormState, createdAt: Date = Date()) throws -> RecipeRecord {
        let data = try JSONEncoder().encode(spec)
        return RecipeRecord(name: name,
                            createdAt: createdAt,
                            updatedAt: createdAt,
                            documentData: data,
                            sourceRaw: "recipe")
    }

    convenience init(name: String, spec: ContainerFormState, createdAt: Date = Date()) {
        let data = (try? JSONEncoder().encode(spec)) ?? Data()
        self.init(name: name,
                  createdAt: createdAt,
                  updatedAt: createdAt,
                  documentData: data,
                  sourceRaw: "recipe")
    }

    convenience init(snapshot: RecipeSnapshot) {
        self.init(name: snapshot.name, spec: snapshot.spec, createdAt: snapshot.createdAt)
    }

    var spec: ContainerFormState? {
        let decoder = JSONDecoder()
        return try? decoder.decode(ContainerFormState.self, from: documentData)
    }
}

struct RecipeSnapshot: Codable {
    var name: String
    var createdAt: Date
    var spec: ContainerFormState

    init?(_ recipe: RecipeRecord) {
        guard let spec = recipe.spec else { return nil }
        self.name = recipe.name
        self.createdAt = recipe.createdAt
        self.spec = spec
    }
}

/// A few ready-to-run starters offered alongside the user's saved templates.
enum BuiltinTemplate {
    static let all: [(name: String, symbol: String, spec: ContainerFormState)] = [
        make("Postgres", symbol: "cylinder.split.1x2", image: "postgres:16",
             ports: [("5432", "5432")], env: [("POSTGRES_PASSWORD", "postgres")]),
        make("Redis", symbol: "bolt.horizontal", image: "redis:7", ports: [("6379", "6379")]),
        make("nginx", symbol: "globe", image: "nginx:latest", ports: [("8080", "80")]),
        make("Alpine (shell)", symbol: "terminal", image: "alpine:latest", command: "sleep infinity"),
    ]

    private static func make(_ name: String, symbol: String, image: String,
                             command: String = "", ports: [(String, String)] = [],
                             env: [(String, String)] = []) -> (name: String, symbol: String, spec: ContainerFormState) {
        var spec = ContainerFormState(runtimeKind: AppRuntimeIntent.placeholderKind)
        spec.image = image
        spec.command = command
        spec.ports = ports.map { PortMap(hostPort: $0.0, containerPort: $0.1, proto: "tcp") }
        spec.env = env.map { KeyValue(key: $0.0, value: $0.1) }
        return (name, symbol, spec)
    }
}
