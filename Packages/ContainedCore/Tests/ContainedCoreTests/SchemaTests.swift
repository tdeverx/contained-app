import Foundation
import Testing
@testable import ContainedCore

@Suite("Container run/edit schema")
struct SchemaTests {
    @Test func appleSchemaPublishesCurrentRunFieldAliases() throws {
        let definition = Core.Schema.Definition.appleContainerCreate
        let paths = Set(definition.fields.map(\.path))

        let expectedPaths: [Core.Field.Path] = [
            .runtimeKind,
            .imageReference,
            .imagePlatform,
            .imageOS,
            .imageArchitecture,
            .containerName,
            .processCommand,
            .processEntrypoint,
            .processDetach,
            .processRemoveOnExit,
            .processInteractive,
            .processTTY,
            .processWorkingDirectory,
            .processUser,
            .processUserID,
            .processGroupID,
            .processUlimits,
            .resourcesCPULimit,
            .resourcesMemoryLimit,
            .resourcesSharedMemorySize,
            .environmentVariables,
            .environmentFiles,
            .networkName,
            .networkPorts,
            .networkSockets,
            .networkDNSDisabled,
            .networkDNSServers,
            .networkDNSDomain,
            .networkDNSSearchDomains,
            .networkDNSOptions,
            .storageVolumes,
            .storageMounts,
            .storageTmpfs,
            .metadataLabels,
            .securityReadOnlyRootFS,
            .securityUseInit,
            .securityRosetta,
            .securitySSHAgent,
            .securityVirtualization,
            .securityCapabilitiesAdd,
            .securityCapabilitiesDrop,
            .outputContainerIDFile,
            .imageInitReference,
            .kernelPath,
            .runtimeHandler,
            .registryScheme,
            .progressMode,
            .imageMaxConcurrentDownloads,
        ]

        for path in expectedPaths {
            #expect(paths.contains(path), "Missing schema field \(path.rawValue)")
        }

        let appleAliases = Set(
            definition.fields
                .flatMap(\.sourceAliases)
                .filter { $0.source == .appleCLI }
                .map(\.name)
        )
        let helpAliases = [
            "<image>",
            "<arguments>",
            "--env",
            "--env-file",
            "--user",
            "--uid",
            "--gid",
            "--workdir, --cwd",
            "--interactive",
            "--tty",
            "--ulimit",
            "--cpus",
            "--memory",
            "--cap-add",
            "--cap-drop",
            "--cidfile",
            "--detach",
            "--dns",
            "--dns-domain",
            "--dns-option",
            "--dns-search",
            "--entrypoint",
            "--init",
            "--init-image",
            "--kernel",
            "--label",
            "--mount",
            "--name",
            "--network",
            "--no-dns",
            "--os",
            "--arch",
            "--platform",
            "--publish",
            "--publish-socket",
            "--read-only",
            "--rm, --remove",
            "--rosetta",
            "--runtime",
            "--ssh",
            "--shm-size",
            "--tmpfs",
            "--virtualization",
            "--volume",
            "--scheme",
            "--progress",
            "--max-concurrent-downloads",
        ]

        for alias in helpAliases {
            #expect(appleAliases.contains(alias), "Missing Apple source alias \(alias)")
        }

        let publish = try #require(definition.descriptor(for: .networkPorts))
        #expect(publish.sourceAliases.contains {
            $0.source == .appleCLI &&
            $0.name == "--publish" &&
            $0.example.contains("127.0.0.1:8080:80/tcp")
        })
        #expect(publish.tip(for: .appleContainer)?.key == "schema.tip.network.ports.apple-container")
    }

    @Test func appleOSAndArchitectureGenerateFlagsOnlyWithoutPlatform() throws {
        var document = Core.Schema.Document.containerCreate()
        document.set(.imageReference, .string("alpine"))
        document.set(.imageOS, .string("linux"))
        document.set(.imageArchitecture, .string("amd64"))

        let request = try document.validatedRequest()
        let args = ContainerCommands.run(request)
        #expect(subsequence(["--os", "linux"], in: args))
        #expect(subsequence(["--arch", "amd64"], in: args))

        document.set(.imagePlatform, .string("linux/arm64"))
        let platformRequest = try document.validatedRequest()
        let platformArgs = ContainerCommands.run(platformRequest)
        #expect(subsequence(["--platform", "linux/arm64"], in: platformArgs))
        #expect(!platformArgs.contains("--os"))
        #expect(!platformArgs.contains("--arch"))
    }

    @Test func documentRuntimeFieldTracksRuntimeKind() {
        let document = Core.Schema.Document.containerCreate(runtimeKind: .docker)
        #expect(document.runtimeKind == .docker)
        #expect(document.string(.runtimeKind) == Core.Runtime.Kind.docker.rawValue)
    }

    @Test func schemaConformanceMigratorDoesNotNeedVersionGate() throws {
        var document = Core.Schema.Document.containerCreate()
        document.schemaVersion = Core.Schema.Version(999)
        document.set(.imageReference, .string("alpine"))
        document.set(.processCommand, .string("echo hello"))

        let definition = Core.Schema.Definition.appleContainerCreate
        let migrated = document.migrated(to: definition)
        #expect(migrated.schemaVersion == definition.version)
        #expect(migrated.strings(.processCommand, in: definition) == ["echo", "hello"])

        let request = try document.validatedRequest(definition: definition)
        #expect(request.image == "alpine")
        #expect(request.command == ["echo", "hello"])
    }

    @Test func schemaConformanceMigratorMapsLegacyPathsPublishedByCore() throws {
        let oldImagePath = Core.Field.Path("legacy.image")
        let definition = Core.Schema.Definition(
            operation: .containerCreate,
            runtimeKind: .appleContainer,
            fields: [
                Core.Schema.FieldDescriptor(
                    path: .imageReference,
                    valueKind: .string,
                    section: .essentials,
                    labelKey: "schema.field.image.reference",
                    defaultLabel: "Image",
                    defaultValue: .string(""),
                    isRequired: true,
                    support: [.appleContainer: .supported],
                    legacyPaths: [oldImagePath]
                ),
            ]
        )
        var document = Core.Schema.Document.containerCreate()
        document.values = [oldImagePath: .string("alpine")]

        let migrated = document.migrated(to: definition)
        #expect(migrated.string(.imageReference, in: definition) == "alpine")
        #expect(migrated.value(oldImagePath) == nil)
        #expect(migrated.validationIssues(in: definition).isEmpty)
    }

    @Test func unresolvedSchemaDeviationsReturnFieldKeyedIssues() {
        var document = Core.Schema.Document.containerCreate()
        document.set(.imageReference, .bool(true))
        document.set(Core.Field.Path("unknown.future.field"), .string("value"))

        let issues = document.validationIssues()
        #expect(issues.contains {
            $0.field == .imageReference &&
            $0.severity == .error &&
            $0.messageKey == "schema.validation.wrongType"
        })
        #expect(issues.contains {
            $0.field.rawValue == "unknown.future.field" &&
            $0.severity == .error &&
            $0.messageKey == "schema.validation.unknownField"
        })
    }

    @Test func composeOnlyFieldsImportAsDisabledSchemaValues() throws {
        let yaml = """
        services:
          app:
            image: example/app:1
            pull_policy: always
            extra_hosts:
              - host.docker.internal:host-gateway
            privileged: true
            security_opt:
              - no-new-privileges:true
            volumes_from:
              - db
            secrets:
              - app_secret
            deploy:
              replicas: 2
            use_api_socket: true
        """

        let project = try Core.Compose.Parser.parse(yaml, projectName: "demo")
        let plan = AppleContainerCreateTranslator.composePlan(for: project, baseDirectory: nil)
        let item = try #require(plan.items.first)
        let definition = Core.Schema.Definition.appleContainerCreate

        #expect(item.document.string(.imagePullPolicy, in: definition) == "always")
        #expect(item.document.strings(.networkExtraHosts, in: definition) == ["host.docker.internal:host-gateway"])
        #expect(item.document.bool(.securityPrivileged, in: definition))
        #expect(item.document.strings(.securityOptions, in: definition) == ["no-new-privileges:true"])
        #expect(item.document.strings(.storageVolumesFrom, in: definition) == ["db"])
        #expect(item.document.strings(.composeSecrets, in: definition) == ["app_secret"])
        #expect(item.document.string(.composeDeploy, in: definition).contains("replicas"))
        #expect(item.document.bool(.composeUseAPISocket, in: definition))
        #expect(item.document.provenance.sources[.imagePullPolicy] == .compose)
        #expect(item.document.provenance.sources[.securityPrivileged] == .compose)

        let pullPolicyDescriptor = try #require(definition.descriptor(for: .imagePullPolicy))
        let support = pullPolicyDescriptor.support(for: .appleContainer)
        #expect(support.state == .disabled)
        #expect(support.defaultDisabledReason == "Known from Docker CLI or Compose, not executable by Apple container.")
        #expect(pullPolicyDescriptor.sourceAliases.contains {
            $0.source == .dockerCLI && $0.example == "--pull=always"
        })
        #expect(pullPolicyDescriptor.sourceAliases.contains {
            $0.source == .compose && $0.example == "pull_policy: always"
        })

        let warnings = item.document.validationIssues(in: definition).filter { $0.severity == .warning }
        #expect(warnings.contains { $0.field == .imagePullPolicy })
        #expect(warnings.contains { $0.field == .securityPrivileged })

        let request = try item.document.validatedRequest(definition: definition)
        #expect(request.image == "example/app:1")
        #expect(request.image != item.document.string(.imagePullPolicy, in: definition))
    }

    @Test func dockerDefinitionSupportsDockerCLIFieldsButDisablesComposeStackFields() throws {
        var document = Core.Schema.Document.containerCreate(runtimeKind: .docker)
        document.set(.imageReference, .string("example/app:1"))
        document.set(.imagePullPolicy, .enumeration("always"))
        document.set(.networkExtraHosts, .stringList(["host.docker.internal:host-gateway"]))
        document.set(.securityPrivileged, .bool(true))
        document.set(.securityOptions, .stringList(["no-new-privileges"]))
        document.set(.composeSecrets, .stringList(["app_secret"]))

        let definition = Core.Schema.Definition.containerRunEdit(runtimeKind: .docker,
                                                                 operation: .containerCreate)
        let pullPolicy = try #require(definition.descriptor(for: .imagePullPolicy))
        let secrets = try #require(definition.descriptor(for: .composeSecrets))

        #expect(pullPolicy.support(for: .docker).state == .supported)
        #expect(secrets.support(for: .docker).state == .disabled)

        let warnings = document.validationIssues(in: definition).filter { $0.severity == .warning }
        #expect(!warnings.contains { $0.field == .imagePullPolicy })
        #expect(warnings.contains { $0.field == .composeSecrets })

        let request = try document.validatedRequest(definition: definition)
        #expect(request.runtimeKind == .docker)
        #expect(request.pullPolicy == "always")
        #expect(request.extraHosts == ["host.docker.internal:host-gateway"])
        #expect(request.privileged)
        #expect(request.securityOptions == ["no-new-privileges"])
        #expect(DockerCommands.run(request).contains("--privileged"))
        #expect(subsequence(["--pull", "always"], in: DockerCommands.run(request)))
    }

    private func subsequence(_ needle: [String], in haystack: [String]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<start + needle.count]) == needle { return true }
        }
        return false
    }
}
