import Foundation

public extension Core.Runtime.Capability {
    static let appleContainer: Core.Runtime.Capability = [
        .containers,
        .images,
        .imageBuild,
        .imagePush,
        .imageArchive,
        .registries,
        .networks,
        .volumes,
        .systemStatus,
        .systemLogs,
        .systemProperties,
        .dnsManagement,
        .kernelManagement,
        .exec,
        .copy,
        .containerExport,
        .composeImport,
        .serviceControl,
    ]
}

public extension Core.Runtime.Descriptor {
    static let appleContainer = Core.Runtime.Descriptor(
        kind: .appleContainer,
        displayName: "Apple container",
        executableName: "container",
        capabilities: .appleContainer
    )
}

struct AppleContainerRuntimeModule: Core.Runtime.Module {
    let descriptor = Core.Runtime.Descriptor.appleContainer

    func locateCLI(override: String?) -> URL? {
        AppleContainerCLILocator.locate(override: override)
    }

    func makeClient(runner: any Core.Command.Running) -> any RuntimeClient {
        AppleContainerClient(runner: runner)
    }

    func readiness(cliURL: URL, runner: any Core.Command.Running) async -> Core.RuntimeReadiness {
        let versionOutput = try? await runner.run(ContainerCommands.version)
        let version = versionOutput.map { String(decoding: $0, as: UTF8.self) }
            .flatMap(AppleContainerCLILocator.parseVersion)

        guard AppleContainerCLILocator.isSupported(version) else {
            return Core.RuntimeReadiness(kind: descriptor.kind,
                                         cliURL: cliURL,
                                         version: version,
                                         state: .unsupported)
        }

        do {
            let data = try await runner.run(ContainerCommands.systemStatus)
            let status = try Core.Container.JSON.decode(Core.System.Status.self, from: data)
            return Core.RuntimeReadiness(kind: descriptor.kind,
                                         cliURL: cliURL,
                                         version: version,
                                         state: status.isRunning ? .ready : .endpointUnavailable,
                                         message: status.isRunning ? nil : "Apple container service is stopped.")
        } catch {
            return Core.RuntimeReadiness(kind: descriptor.kind,
                                         cliURL: cliURL,
                                         version: version,
                                         state: .endpointUnavailable,
                                         message: String(describing: error))
        }
    }

    func terminalInvocation(containerID: String, shell: String, cliURL: URL) -> Core.Command.Invocation {
        Core.Command.Invocation(executableURL: cliURL,
                                arguments: ContainerCommands.execInteractive(containerID, shell: shell))
    }

    func runPreview(for request: Core.Container.CreateRequest) -> [String] {
        ContainerCommands.run(request)
    }

    func buildPreview(context: String,
                      tag: String?,
                      dockerfile: String?,
                      buildArgs: [String: String],
                      noCache: Bool,
                      platform: String?) -> [String] {
        ContainerCommands.build(context: context,
                                tag: tag,
                                dockerfile: dockerfile,
                                buildArgs: buildArgs,
                                noCache: noCache,
                                platform: platform)
    }

    func networkCreatePreview(name: String, subnet: String?, internalOnly: Bool) -> [String] {
        ContainerCommands.networkCreate(name: name,
                                        subnet: subnet,
                                        internalOnly: internalOnly)
    }

    func volumeCreatePreview(name: String, size: String?) -> [String] {
        ContainerCommands.volumeCreate(name: name, size: size)
    }

    func schemaProfile() -> Core.Schema.RuntimeProfile {
        let fields = Core.Schema.Definition.canonicalRunFields
        let supported = Set(fields.compactMap { field -> Core.Field.Path? in
            field.support[descriptor.kind]?.state == .supported ? field.path : nil
        })
        let disabled = Dictionary(uniqueKeysWithValues: fields.compactMap { field -> (Core.Field.Path, Core.Schema.FieldSupport)? in
            guard let support = field.support[descriptor.kind], support.state == .disabled else { return nil }
            return (field.path, support)
        })
        let tips = Dictionary(uniqueKeysWithValues: fields.compactMap { field -> (Core.Field.Path, Core.Schema.FieldTipRef)? in
            guard let tip = field.tipRefs[descriptor.kind] else { return nil }
            return (field.path, tip)
        })
        return Core.Schema.RuntimeProfile(kind: descriptor.kind,
                                          supportedPaths: supported,
                                          disabledSupport: disabled,
                                          tips: tips)
    }
}

extension AppleContainerClient: RuntimeClient,
                                RuntimeContainerClient,
                                RuntimeSystemStatusClient,
                                RuntimeDNSClient,
                                RuntimeKernelClient,
                                RuntimeExecClient,
                                RuntimeSystemLogsClient,
                                RuntimeComposeClient,
                                RuntimeNetworkClient,
                                RuntimeVolumeClient,
                                RuntimeImageClient,
                                RuntimeRegistryClient,
                                RuntimeServiceControlClient {}
