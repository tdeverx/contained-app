import Foundation

public extension Core.Runtime {
struct UnsupportedCapability: Error, Equatable, Sendable {
    public var kind: Core.Runtime.Kind
    public var capability: Core.Runtime.Capability

    public init(kind: Core.Runtime.Kind, capability: Core.Runtime.Capability) {
        self.kind = kind
        self.capability = capability
    }
}

struct InventoryFailure: Error, Equatable, Sendable {
    public var resource: String
    public var kind: Core.Runtime.Kind
    public var message: String

    public init(resource: String, kind: Core.Runtime.Kind, message: String) {
        self.resource = resource
        self.kind = kind
        self.message = message
    }
}

struct InventoryResult<Item: Sendable>: Sendable {
    public var items: [Item]
    public var failures: [Core.Runtime.InventoryFailure]

    public init(items: [Item], failures: [Core.Runtime.InventoryFailure] = []) {
        self.items = items
        self.failures = failures
    }
}
}

extension Core.Runtime.UnsupportedCapability: Core.Error.PackageError {
    public var packageName: String { "ContainedCore" }
    public var packageErrorCode: String { "unsupportedRuntimeCapability" }
    public var packageErrorContext: [String: String] {
        [
            "kind": kind.rawValue,
            "capability": String(capability.rawValue),
        ]
    }
}

extension Core.Runtime.InventoryFailure: Core.Error.PackageError {
    public var packageName: String { "ContainedCore" }
    public var packageErrorCode: String { "partialRuntimeInventoryFailure" }
    public var packageErrorContext: [String: String] {
        [
            "resource": resource,
            "kind": kind.rawValue,
            "message": message,
        ]
    }
}
