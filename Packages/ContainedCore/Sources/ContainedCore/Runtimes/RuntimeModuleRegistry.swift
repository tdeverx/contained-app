import Foundation

public extension Core.Runtime {
    static var supportedDescriptors: [Core.Runtime.Descriptor] {
        builtInModules.map(\.descriptor).sorted { $0.displayName < $1.displayName }
    }

    static func descriptor(for kind: Core.Runtime.Kind) -> Core.Runtime.Descriptor? {
        module(for: kind)?.descriptor
    }
}

extension Core.Runtime {
    static var builtInModules: [any Core.Runtime.Module] {
        [
            AppleContainerRuntimeModule(),
            DockerRuntimeModule(),
        ]
    }

    static func module(for kind: Core.Runtime.Kind) -> (any Core.Runtime.Module)? {
        builtInModules.first { $0.descriptor.kind == kind }
    }
}
