import Foundation

public extension Core.Runtime.Capability {
    static let docker: Core.Runtime.Capability = [
        .containers,
        .images,
        .imageBuild,
        .imagePush,
        .imageArchive,
        .registries,
        .networks,
        .volumes,
        .systemStatus,
        .systemProperties,
        .exec,
        .copy,
        .containerExport,
        .composeImport,
    ]
}

public extension Core.Runtime.Descriptor {
    static let docker = Core.Runtime.Descriptor(
        kind: .docker,
        displayName: "Docker",
        executableName: "docker",
        capabilities: .docker
    )
}

struct DockerRuntimeModule: Core.Runtime.Module {
    let descriptor = Core.Runtime.Descriptor.docker

    func locateCLI(override: String?) -> URL? {
        DockerCLILocator.locate(override: override)
    }

    func makeClient(runner: any Core.Command.Running) -> any RuntimeClient {
        DockerClient(runner: runner)
    }

    func readiness(cliURL: URL, runner: any Core.Command.Running) async -> Core.RuntimeReadiness {
        let versionOutput = try? await runner.run(DockerCommands.version)
        let version = versionOutput.map { String(decoding: $0, as: UTF8.self) }
            .flatMap(DockerCLILocator.parseVersion)

        do {
            _ = try await runner.run(DockerCommands.systemStatus)
            return Core.RuntimeReadiness(kind: descriptor.kind,
                                         cliURL: cliURL,
                                         version: version,
                                         state: .ready)
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
                                arguments: DockerCommands.execInteractive(containerID, shell: shell))
    }

    func runPreview(for request: Core.Container.CreateRequest) -> [String] {
        DockerCommands.run(request)
    }

    func buildPreview(context: String,
                      tag: String?,
                      dockerfile: String?,
                      buildArgs: [String: String],
                      noCache: Bool,
                      platform: String?) -> [String] {
        DockerCommands.build(context: context,
                             tag: tag,
                             dockerfile: dockerfile,
                             buildArgs: buildArgs,
                             noCache: noCache,
                             platform: platform)
    }

    func networkCreatePreview(name: String, subnet: String?, internalOnly: Bool) -> [String] {
        DockerCommands.networkCreate(name: name,
                                     subnet: subnet,
                                     internalOnly: internalOnly)
    }

    func volumeCreatePreview(name: String, size: String?) -> [String] {
        DockerCommands.volumeCreate(name: name, size: size)
    }

    func schemaProfile() -> Core.Schema.RuntimeProfile {
        let fields = Core.Schema.Definition.canonicalRunFields
        let supportByPath = Dictionary(uniqueKeysWithValues: fields.map { ($0.path, dockerSupport(for: $0)) })
        let supported = Set(supportByPath.compactMap { path, support in
            support.state == .supported ? path : nil
        })
        let disabled = supportByPath.filter { _, support in support.state == .disabled }
        let tips = Dictionary(uniqueKeysWithValues: fields.compactMap { field -> (Core.Field.Path, Core.Schema.FieldTipRef)? in
            guard supportByPath[field.path]?.state == .supported,
                  let tip = field.tipRefs[.appleContainer] else { return nil }
            return (field.path, Core.Schema.FieldTipRef(
                key: tip.key.replacingOccurrences(of: "apple-container", with: "docker"),
                defaultText: tip.defaultText
            ))
        })
        return Core.Schema.RuntimeProfile(kind: descriptor.kind,
                                          supportedPaths: supported,
                                          disabledSupport: disabled,
                                          tips: tips)
    }

    private func dockerSupport(for descriptor: Core.Schema.FieldDescriptor) -> Core.Schema.FieldSupport {
        let unsupported = Core.Schema.FieldSupport(
            state: .disabled,
            disabledReasonKey: "schema.disabled.docker.unsupportedAppleContainer",
            defaultDisabledReason: "Known from Apple container or Compose, not executable by Docker."
        )
        let composeOnlyUnsupported = Core.Schema.FieldSupport(
            state: .disabled,
            disabledReasonKey: "schema.disabled.docker.composeOnly",
            defaultDisabledReason: "Compose stack metadata is preserved, but V1 Docker support runs single containers only."
        )

        let sharedDockerPaths: Set<Core.Field.Path> = [
            .runtimeKind, .imageReference, .imagePlatform, .containerName, .processCommand,
            .processEntrypoint, .processDetach, .processRemoveOnExit, .processInteractive,
            .processTTY, .processWorkingDirectory, .processUser, .processUlimits,
            .resourcesCPULimit, .resourcesMemoryLimit, .resourcesSharedMemorySize,
            .environmentVariables, .environmentFiles, .networkName, .networkPorts,
            .storageVolumes, .storageMounts, .storageTmpfs, .metadataLabels,
            .lifecycleRestartPolicy, .securityReadOnlyRootFS, .securityUseInit,
            .securityCapabilitiesAdd, .securityCapabilitiesDrop, .outputContainerIDFile,
            .runtimeHandler, .networkDNSServers, .networkDNSSearchDomains,
            .networkDNSOptions,
        ]
        let appleOnlyPaths: Set<Core.Field.Path> = [
            .imageOS, .imageArchitecture, .networkSockets, .networkDNSDisabled,
            .networkDNSDomain, .processUserID, .processGroupID, .securityRosetta,
            .securitySSHAgent, .securityVirtualization, .imageInitReference,
            .kernelPath, .registryScheme, .progressMode, .imageMaxConcurrentDownloads,
        ]
        let composeOnlyPaths: Set<Core.Field.Path> = [
            .composeSecrets, .composeConfigs, .composeProfiles, .composeDeploy,
            .composeScale, .composeLinks, .composeDependsOn, .composeProvider,
            .composeModels, .composeUseAPISocket,
        ]

        if sharedDockerPaths.contains(descriptor.path) { return .supported }
        if appleOnlyPaths.contains(descriptor.path) { return unsupported }
        if composeOnlyPaths.contains(descriptor.path) { return composeOnlyUnsupported }
        if descriptor.sourceAliases.contains(where: { $0.source == .dockerCLI }) { return .supported }
        return unsupported
    }
}

extension DockerClient: RuntimeClient,
                        RuntimeContainerClient,
                        RuntimeSystemStatusClient,
                        RuntimeExecClient,
                        RuntimeComposeClient,
                        RuntimeNetworkClient,
                        RuntimeVolumeClient,
                        RuntimeImageClient,
                        RuntimeRegistryClient {}
