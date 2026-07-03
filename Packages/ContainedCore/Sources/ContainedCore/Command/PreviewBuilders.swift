import Foundation

public extension Core.Command {
    static func runPreview(for request: Core.Container.CreateRequest) -> [String] {
        ContainerCommands.run(request)
    }

    static func buildPreview(context: String,
                             tag: String? = nil,
                             dockerfile: String? = nil,
                             buildArgs: [String: String] = [:],
                             noCache: Bool = false,
                             platform: String? = nil,
                             runtimeKind: Core.Runtime.Kind = .appleContainer) -> [String] {
        if runtimeKind == .docker {
            return DockerCommands.build(context: context,
                                        tag: tag,
                                        dockerfile: dockerfile,
                                        buildArgs: buildArgs,
                                        noCache: noCache,
                                        platform: platform)
        }
        return ContainerCommands.build(context: context,
                                       tag: tag,
                                       dockerfile: dockerfile,
                                       buildArgs: buildArgs,
                                       noCache: noCache,
                                       platform: platform)
    }

    static func networkCreatePreview(name: String,
                                     subnet: String? = nil,
                                     internalOnly: Bool = false,
                                     runtimeKind: Core.Runtime.Kind = .appleContainer) -> [String] {
        if runtimeKind == .docker {
            return DockerCommands.networkCreate(name: name,
                                                subnet: subnet,
                                                internalOnly: internalOnly)
        }
        return ContainerCommands.networkCreate(name: name,
                                               subnet: subnet,
                                               internalOnly: internalOnly)
    }

    static func volumeCreatePreview(name: String,
                                    size: String? = nil,
                                    runtimeKind: Core.Runtime.Kind = .appleContainer) -> [String] {
        if runtimeKind == .docker {
            return DockerCommands.volumeCreate(name: name, size: size)
        }
        return ContainerCommands.volumeCreate(name: name, size: size)
    }
}
