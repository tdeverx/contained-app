import Foundation

public extension Core.Schema {
enum Operation: String, Codable, Equatable, Hashable, Sendable {
    case containerCreate = "container.create"
    case containerEdit = "container.edit"
}

enum FieldSection: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case runtime
    case essentials
    case resources
    case networking
    case storage
    case environment
    case process
    case security
    case imageFetch
    case metadata
    case dockerCompose
}

enum ValueKind: String, Codable, Equatable, Hashable, Sendable {
    case string
    case bool
    case enumeration
    case commandLine
    case stringList
    case keyValueList
    case portList
    case volumeList
    case socketList
}

enum Value: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case bool(Bool)
    case enumeration(String)
    case commandLine([String])
    case stringList([String])
    case keyValueList([Core.Container.KeyValue])
    case portList([Core.Container.Port])
    case volumeList([Core.Container.VolumeMount])
    case socketList([Core.Container.Socket])

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    public var valueKind: Core.Schema.ValueKind {
        switch self {
        case .string: return .string
        case .bool: return .bool
        case .enumeration: return .enumeration
        case .commandLine: return .commandLine
        case .stringList: return .stringList
        case .keyValueList: return .keyValueList
        case .portList: return .portList
        case .volumeList: return .volumeList
        case .socketList: return .socketList
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .string(let value), .enumeration(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .bool(let value):
            return value == false
        case .commandLine(let values), .stringList(let values):
            return values.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .keyValueList(let values):
            return values.allSatisfy { !$0.isValid }
        case .portList(let values):
            return values.allSatisfy { !$0.isValid }
        case .volumeList(let values):
            return values.allSatisfy { !$0.isValid }
        case .socketList(let values):
            return values.allSatisfy { !$0.isValid }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Core.Schema.ValueKind.self, forKey: .kind)
        switch kind {
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .enumeration:
            self = .enumeration(try container.decode(String.self, forKey: .value))
        case .commandLine:
            self = .commandLine(try container.decode([String].self, forKey: .value))
        case .stringList:
            self = .stringList(try container.decode([String].self, forKey: .value))
        case .keyValueList:
            self = .keyValueList(try container.decode([Core.Container.KeyValue].self, forKey: .value))
        case .portList:
            self = .portList(try container.decode([Core.Container.Port].self, forKey: .value))
        case .volumeList:
            self = .volumeList(try container.decode([Core.Container.VolumeMount].self, forKey: .value))
        case .socketList:
            self = .socketList(try container.decode([Core.Container.Socket].self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(valueKind, forKey: .kind)
        switch self {
        case .string(let value):
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode(value, forKey: .value)
        case .enumeration(let value):
            try container.encode(value, forKey: .value)
        case .commandLine(let value):
            try container.encode(value, forKey: .value)
        case .stringList(let value):
            try container.encode(value, forKey: .value)
        case .keyValueList(let value):
            try container.encode(value, forKey: .value)
        case .portList(let value):
            try container.encode(value, forKey: .value)
        case .volumeList(let value):
            try container.encode(value, forKey: .value)
        case .socketList(let value):
            try container.encode(value, forKey: .value)
        }
    }
}

enum SourceKind: String, Codable, Equatable, Hashable, Sendable {
    case appleCLI
    case dockerCLI
    case compose
}

struct SourceAlias: Codable, Equatable, Hashable, Sendable {
    public var source: Core.Schema.SourceKind
    public var name: String
    public var example: String

    public init(source: Core.Schema.SourceKind, name: String, example: String) {
        self.source = source
        self.name = name
        self.example = example
    }
}

struct FieldTipRef: Codable, Equatable, Hashable, Sendable {
    public var key: String
    public var defaultText: String

    public init(key: String, defaultText: String) {
        self.key = key
        self.defaultText = defaultText
    }
}

enum SupportState: String, Codable, Equatable, Hashable, Sendable {
    case supported
    case disabled
}

struct FieldSupport: Codable, Equatable, Hashable, Sendable {
    public var state: Core.Schema.SupportState
    public var disabledReasonKey: String?
    public var defaultDisabledReason: String?

    public init(state: Core.Schema.SupportState,
                disabledReasonKey: String? = nil,
                defaultDisabledReason: String? = nil) {
        self.state = state
        self.disabledReasonKey = disabledReasonKey
        self.defaultDisabledReason = defaultDisabledReason
    }

    public static let supported = Core.Schema.FieldSupport(state: .supported)
}

struct ValueOption: Codable, Equatable, Hashable, Sendable {
    public var value: String
    public var labelKey: String
    public var defaultLabel: String

    public init(value: String, labelKey: String, defaultLabel: String) {
        self.value = value
        self.labelKey = labelKey
        self.defaultLabel = defaultLabel
    }
}

struct FieldDescriptor: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var path: Core.Field.Path
    public var id: String { path.rawValue }
    public var valueKind: Core.Schema.ValueKind
    public var section: Core.Schema.FieldSection
    public var labelKey: String
    public var defaultLabel: String
    public var defaultValue: Core.Schema.Value
    public var isRequired: Bool
    public var options: [Core.Schema.ValueOption]
    public var support: [Core.Runtime.Kind: Core.Schema.FieldSupport]
    public var tipRefs: [Core.Runtime.Kind: Core.Schema.FieldTipRef]
    public var sourceAliases: [Core.Schema.SourceAlias]
    public var legacyPaths: [Core.Field.Path]

    public init(path: Core.Field.Path,
                valueKind: Core.Schema.ValueKind,
                section: Core.Schema.FieldSection,
                labelKey: String,
                defaultLabel: String,
                defaultValue: Core.Schema.Value,
                isRequired: Bool = false,
                options: [Core.Schema.ValueOption] = [],
                support: [Core.Runtime.Kind: Core.Schema.FieldSupport] = [:],
                tipRefs: [Core.Runtime.Kind: Core.Schema.FieldTipRef] = [:],
                sourceAliases: [Core.Schema.SourceAlias] = [],
                legacyPaths: [Core.Field.Path] = []) {
        self.path = path
        self.valueKind = valueKind
        self.section = section
        self.labelKey = labelKey
        self.defaultLabel = defaultLabel
        self.defaultValue = defaultValue
        self.isRequired = isRequired
        self.options = options
        self.support = support
        self.tipRefs = tipRefs
        self.sourceAliases = sourceAliases
        self.legacyPaths = legacyPaths
    }

    public func support(for runtimeKind: Core.Runtime.Kind) -> Core.Schema.FieldSupport {
        support[runtimeKind] ?? Core.Schema.FieldSupport(
            state: .disabled,
            disabledReasonKey: "schema.disabled.unsupported",
            defaultDisabledReason: "This field is known to Core but is not available for the selected runtime."
        )
    }

    public func tip(for runtimeKind: Core.Runtime.Kind) -> Core.Schema.FieldTipRef? {
        tipRefs[runtimeKind]
    }
}

struct RuntimeProfile: Equatable, Sendable {
    public var kind: Core.Runtime.Kind
    public var supportedPaths: Set<Core.Field.Path>
    public var disabledSupport: [Core.Field.Path: Core.Schema.FieldSupport]
    public var tips: [Core.Field.Path: Core.Schema.FieldTipRef]
    public var defaultDisabledSupport: Core.Schema.FieldSupport

    public init(kind: Core.Runtime.Kind,
                supportedPaths: Set<Core.Field.Path>,
                disabledSupport: [Core.Field.Path: Core.Schema.FieldSupport] = [:],
                tips: [Core.Field.Path: Core.Schema.FieldTipRef] = [:],
                defaultDisabledSupport: Core.Schema.FieldSupport = Core.Schema.FieldSupport(
                    state: .disabled,
                    disabledReasonKey: "schema.disabled.unsupported",
                    defaultDisabledReason: "This field is known to Core but is not available for the selected runtime."
                )) {
        self.kind = kind
        self.supportedPaths = supportedPaths
        self.disabledSupport = disabledSupport
        self.tips = tips
        self.defaultDisabledSupport = defaultDisabledSupport
    }

    public func apply(to descriptors: [Core.Schema.FieldDescriptor]) -> [Core.Schema.FieldDescriptor] {
        descriptors.map { descriptor in
            var field = descriptor
            field.support[kind] = support(for: descriptor)
            if let tip = tips[descriptor.path] {
                field.tipRefs[kind] = tip
            }
            return field
        }
    }

    public func support(for descriptor: Core.Schema.FieldDescriptor) -> Core.Schema.FieldSupport {
        if supportedPaths.contains(descriptor.path) { return .supported }
        return disabledSupport[descriptor.path] ?? defaultDisabledSupport
    }
}

struct Definition: Codable, Equatable, Sendable {
    public var operation: Core.Schema.Operation
    public var version: Core.Schema.Version
    public var runtimeKind: Core.Runtime.Kind
    public var fields: [Core.Schema.FieldDescriptor]

    public init(operation: Core.Schema.Operation,
                version: Core.Schema.Version = .current,
                runtimeKind: Core.Runtime.Kind,
                fields: [Core.Schema.FieldDescriptor]) {
        self.operation = operation
        self.version = version
        self.runtimeKind = runtimeKind
        self.fields = fields
    }

    public func descriptor(for path: Core.Field.Path) -> Core.Schema.FieldDescriptor? {
        fields.first { $0.path == path }
    }
}

enum ValidationSeverity: String, Codable, Equatable, Sendable {
    case error
    case warning
}

struct ValidationIssue: Codable, Equatable, Sendable {
    public var field: Core.Field.Path
    public var severity: Core.Schema.ValidationSeverity
    public var messageKey: String
    public var defaultMessage: String

    public init(field: Core.Field.Path,
                severity: Core.Schema.ValidationSeverity,
                messageKey: String,
                defaultMessage: String) {
        self.field = field
        self.severity = severity
        self.messageKey = messageKey
        self.defaultMessage = defaultMessage
    }
}

struct Document: Codable, Equatable, Sendable {
    public var operation: Core.Schema.Operation
    public var schemaVersion: Core.Schema.Version
    public var runtimeKind: Core.Runtime.Kind
    public var values: [Core.Field.Path: Core.Schema.Value]
    public var provenance: Core.Field.ProvenanceMap

    public init(operation: Core.Schema.Operation = .containerCreate,
                schemaVersion: Core.Schema.Version = .current,
                runtimeKind: Core.Runtime.Kind,
                values: [Core.Field.Path: Core.Schema.Value] = [:],
                provenance: Core.Field.ProvenanceMap = Core.Field.ProvenanceMap()) {
        self.operation = operation
        self.schemaVersion = schemaVersion
        self.runtimeKind = runtimeKind
        self.values = values
        self.provenance = provenance
    }

    public func value(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> Core.Schema.Value? {
        values[path] ?? definition?.descriptor(for: path)?.defaultValue
    }

    public mutating func set(_ path: Core.Field.Path, _ value: Core.Schema.Value?) {
        values[path] = value
    }

    public func string(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> String {
        switch value(path, in: definition) {
        case .string(let value), .enumeration(let value): return value
        default: return ""
        }
    }

    public func bool(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> Bool {
        if case .bool(let value) = value(path, in: definition) { return value }
        return false
    }

    public func strings(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> [String] {
        switch value(path, in: definition) {
        case .stringList(let value), .commandLine(let value): return value
        default: return []
        }
    }

    public func keyValues(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> [Core.Container.KeyValue] {
        if case .keyValueList(let value) = value(path, in: definition) { return value }
        return []
    }

    public func ports(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> [Core.Container.Port] {
        if case .portList(let value) = value(path, in: definition) { return value }
        return []
    }

    public func volumes(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> [Core.Container.VolumeMount] {
        if case .volumeList(let value) = value(path, in: definition) { return value }
        return []
    }

    public func sockets(_ path: Core.Field.Path, in definition: Core.Schema.Definition? = nil) -> [Core.Container.Socket] {
        if case .socketList(let value) = value(path, in: definition) { return value }
        return []
    }
}

enum ValidationError: Error, Equatable, Sendable {
    case invalid([Core.Schema.ValidationIssue])
}
}

extension Core.Schema.ValidationError: Core.Error.PackageError {
    public var packageName: String { "ContainedCore" }
    public var packageErrorCode: String {
        switch self {
        case .invalid: return "schemaInvalid"
        }
    }

    public var packageErrorContext: [String: String] {
        switch self {
        case .invalid(let issues):
            return ["issues": issues.map(\.field.rawValue).joined(separator: ",")]
        }
    }
}
