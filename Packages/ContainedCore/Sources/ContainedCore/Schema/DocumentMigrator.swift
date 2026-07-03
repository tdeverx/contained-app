import Foundation

public extension Core.Schema {
struct DocumentMigrator: Sendable {
    public init() {}

    public func migrate(_ document: Core.Schema.Document,
                        to definition: Core.Schema.Definition) -> Core.Schema.Document {
        var migrated = document
        migrated.operation = definition.operation
        migrated.runtimeKind = definition.runtimeKind
        migrated.schemaVersion = definition.version

        let knownPaths = Set(definition.fields.map(\.path))
        var consumedLegacyPaths = Set<Core.Field.Path>()

        for field in definition.fields where migrated.values[field.path] == nil {
            guard let legacyPath = field.legacyPaths.first(where: { migrated.values[$0] != nil }),
                  let legacyValue = migrated.values[legacyPath] else { continue }
            migrated.values[field.path] = coerce(legacyValue, to: field.valueKind) ?? legacyValue
            if let source = migrated.provenance.sources[legacyPath] {
                migrated.provenance.sources[field.path] = source
            }
            consumedLegacyPaths.insert(legacyPath)
        }

        for field in definition.fields {
            guard let value = migrated.values[field.path],
                  value.valueKind != field.valueKind,
                  let coerced = coerce(value, to: field.valueKind) else { continue }
            migrated.values[field.path] = coerced
        }

        for legacyPath in consumedLegacyPaths where !knownPaths.contains(legacyPath) {
            migrated.values.removeValue(forKey: legacyPath)
            migrated.provenance.sources.removeValue(forKey: legacyPath)
        }

        return migrated
    }

    private func coerce(_ value: Core.Schema.Value,
                        to valueKind: Core.Schema.ValueKind) -> Core.Schema.Value? {
        switch (value, valueKind) {
        case (.enumeration(let value), .string):
            return .string(value)
        case (.string(let value), .enumeration):
            return .enumeration(value)
        case (.string(let value), .commandLine):
            return .commandLine(splitCommand(value))
        case (.stringList(let value), .commandLine):
            return .commandLine(value)
        case (.string(let value), .stringList):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .stringList([]) : .stringList([value])
        case (.commandLine(let value), .stringList):
            return .stringList(value)
        case (.string(let value), .bool):
            return bool(value).map(Core.Schema.Value.bool)
        case (.enumeration(let value), .bool):
            return bool(value).map(Core.Schema.Value.bool)
        case (.stringList(let value), .keyValueList):
            let pairs = value.compactMap(keyValue)
            return pairs.count == value.count ? .keyValueList(pairs) : nil
        case (.keyValueList(let value), .stringList):
            return .stringList(value.filter(\.isValid).map { "\($0.key)=\($0.value)" })
        default:
            return nil
        }
    }

    private func splitCommand(_ value: String) -> [String] {
        value.split(separator: " ").map(String.init)
    }

    private func bool(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "1", "on": return true
        case "false", "no", "0", "off", "": return false
        default: return nil
        }
    }

    private func keyValue(_ value: String) -> Core.Container.KeyValue? {
        guard let eq = value.firstIndex(of: "=") else { return nil }
        return Core.Container.KeyValue(key: String(value[..<eq]),
                                       value: String(value[value.index(after: eq)...]))
    }
}
}

public extension Core.Schema.Document {
    func migrated(to definition: Core.Schema.Definition,
                  using migrator: Core.Schema.DocumentMigrator = Core.Schema.DocumentMigrator()) -> Core.Schema.Document {
        migrator.migrate(self, to: definition)
    }
}
