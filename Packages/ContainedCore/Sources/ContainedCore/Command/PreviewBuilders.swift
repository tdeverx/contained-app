import Foundation

public extension Core.Command {
    static func runPreview(for request: Core.Container.CreateRequest) -> [String] {
        Core.Runtime.module(for: request.runtimeKind)?.runPreview(for: request) ?? []
    }

    static func buildPreview(context: String,
                             tag: String? = nil,
                             dockerfile: String? = nil,
                             buildArgs: [String: String] = [:],
                             noCache: Bool = false,
                             platform: String? = nil,
                             runtimeKind: Core.Runtime.Kind) -> [String] {
        Core.Runtime.module(for: runtimeKind)?.buildPreview(context: context,
                                                            tag: tag,
                                                            dockerfile: dockerfile,
                                                            buildArgs: buildArgs,
                                                            noCache: noCache,
                                                            platform: platform) ?? []
    }

    static func networkCreatePreview(name: String,
                                     subnet: String? = nil,
                                     internalOnly: Bool = false,
                                     runtimeKind: Core.Runtime.Kind) -> [String] {
        Core.Runtime.module(for: runtimeKind)?.networkCreatePreview(name: name,
                                                                    subnet: subnet,
                                                                    internalOnly: internalOnly) ?? []
    }

    static func volumeCreatePreview(name: String,
                                    size: String? = nil,
                                    runtimeKind: Core.Runtime.Kind) -> [String] {
        Core.Runtime.module(for: runtimeKind)?.volumeCreatePreview(name: name, size: size) ?? []
    }
}
