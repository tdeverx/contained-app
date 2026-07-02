import Foundation

public extension Core.Command {
    static func runPreview(for request: ContainerCreateRequest) -> [String] {
        ContainerCommands.run(request)
    }

    static func buildPreview(context: String,
                             tag: String? = nil,
                             dockerfile: String? = nil,
                             buildArgs: [String: String] = [:],
                             noCache: Bool = false,
                             platform: String? = nil) -> [String] {
        ContainerCommands.build(context: context,
                                tag: tag,
                                dockerfile: dockerfile,
                                buildArgs: buildArgs,
                                noCache: noCache,
                                platform: platform)
    }

    static func networkCreatePreview(name: String,
                                     subnet: String? = nil,
                                     internalOnly: Bool = false) -> [String] {
        ContainerCommands.networkCreate(name: name,
                                        subnet: subnet,
                                        internalOnly: internalOnly)
    }

    static func volumeCreatePreview(name: String,
                                    size: String? = nil) -> [String] {
        ContainerCommands.volumeCreate(name: name, size: size)
    }
}
