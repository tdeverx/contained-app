import Foundation

public extension Core.Runtime {
struct Descriptor: Equatable, Sendable {
    public var kind: Core.Runtime.Kind
    public var displayName: String
    public var executableName: String?
    public var capabilities: Core.Runtime.Capability

    public init(kind: Core.Runtime.Kind,
                displayName: String,
                executableName: String? = nil,
                capabilities: Core.Runtime.Capability) {
        self.kind = kind
        self.displayName = displayName
        self.executableName = executableName
        self.capabilities = capabilities
    }

    public func supports(_ capability: Core.Runtime.Capability) -> Bool {
        capabilities.isSuperset(of: capability)
    }

    public func require(_ capability: Core.Runtime.Capability) throws {
        guard supports(capability) else {
            throw Core.Runtime.UnsupportedCapability(kind: kind, capability: capability)
        }
    }
}
}
