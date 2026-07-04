import Foundation

public extension Core.Field.Path {
    static let runtimeKind = Core.Field.Path("runtime.kind")
    static let imageReference = Core.Field.Path("image.reference")
    static let imagePlatform = Core.Field.Path("image.platform")
    static let imageOS = Core.Field.Path("image.os")
    static let imageArchitecture = Core.Field.Path("image.architecture")
    static let containerName = Core.Field.Path("container.name")
    static let processCommand = Core.Field.Path("process.command")
    static let processEntrypoint = Core.Field.Path("process.entrypoint")
    static let processDetach = Core.Field.Path("process.detach")
    static let processRemoveOnExit = Core.Field.Path("process.removeOnExit")
    static let processInteractive = Core.Field.Path("process.interactive")
    static let processTTY = Core.Field.Path("process.tty")
    static let processWorkingDirectory = Core.Field.Path("process.workingDirectory")
    static let processUser = Core.Field.Path("process.user")
    static let processUserID = Core.Field.Path("process.userID")
    static let processGroupID = Core.Field.Path("process.groupID")
    static let processUlimits = Core.Field.Path("process.ulimits")
    static let resourcesCPULimit = Core.Field.Path("resources.cpu.limit")
    static let resourcesMemoryLimit = Core.Field.Path("resources.memory.limit")
    static let resourcesSharedMemorySize = Core.Field.Path("resources.sharedMemory.size")
    static let environmentVariables = Core.Field.Path("environment.variables")
    static let environmentFiles = Core.Field.Path("environment.files")
    static let networkName = Core.Field.Path("network.name")
    static let networkPorts = Core.Field.Path("network.ports")
    static let networkSockets = Core.Field.Path("network.sockets")
    static let networkDNSDisabled = Core.Field.Path("network.dns.disabled")
    static let networkDNSServers = Core.Field.Path("network.dns.servers")
    static let networkDNSDomain = Core.Field.Path("network.dns.domain")
    static let networkDNSSearchDomains = Core.Field.Path("network.dns.searchDomains")
    static let networkDNSOptions = Core.Field.Path("network.dns.options")
    static let storageVolumes = Core.Field.Path("storage.volumes")
    static let storageMounts = Core.Field.Path("storage.mounts")
    static let storageTmpfs = Core.Field.Path("storage.tmpfs")
    static let metadataLabels = Core.Field.Path("metadata.labels")
    static let lifecycleRestartPolicy = Core.Field.Path("lifecycle.restartPolicy")
    static let securityReadOnlyRootFS = Core.Field.Path("security.rootFilesystem.readOnly")
    static let securityUseInit = Core.Field.Path("security.init.enabled")
    static let securityRosetta = Core.Field.Path("security.rosetta.enabled")
    static let securitySSHAgent = Core.Field.Path("security.sshAgent.forwarded")
    static let securityVirtualization = Core.Field.Path("security.virtualization.exposed")
    static let securityCapabilitiesAdd = Core.Field.Path("security.capabilities.add")
    static let securityCapabilitiesDrop = Core.Field.Path("security.capabilities.drop")
    static let outputContainerIDFile = Core.Field.Path("output.containerIDFile")
    static let imageInitReference = Core.Field.Path("image.init.reference")
    static let kernelPath = Core.Field.Path("kernel.path")
    static let runtimeHandler = Core.Field.Path("runtime.handler")
    static let registryScheme = Core.Field.Path("registry.scheme")
    static let progressMode = Core.Field.Path("progress.mode")
    static let imageMaxConcurrentDownloads = Core.Field.Path("image.fetch.maxConcurrentDownloads")

    static let networkExtraHosts = Core.Field.Path("network.extraHosts")
    static let networkHostname = Core.Field.Path("network.hostname")
    static let networkDomainName = Core.Field.Path("network.domainName")
    static let networkMacAddress = Core.Field.Path("network.macAddress")
    static let networkExpose = Core.Field.Path("network.expose")
    static let networkPublishAll = Core.Field.Path("network.publishAll")
    static let imagePullPolicy = Core.Field.Path("image.pullPolicy")
    static let processAttachStreams = Core.Field.Path("process.attachStreams")
    static let loggingDriver = Core.Field.Path("logging.driver")
    static let loggingOptions = Core.Field.Path("logging.options")
    static let metadataLabelFiles = Core.Field.Path("metadata.labelFiles")
    static let lifecycleStopSignal = Core.Field.Path("lifecycle.stopSignal")
    static let lifecycleStopGracePeriod = Core.Field.Path("lifecycle.stopGracePeriod")
    static let devices = Core.Field.Path("hardware.devices")
    static let gpus = Core.Field.Path("hardware.gpus")
    static let processSupplementalGroups = Core.Field.Path("process.supplementalGroups")
    static let securityPrivileged = Core.Field.Path("security.privileged")
    static let securityOptions = Core.Field.Path("security.options")
    static let kernelSysctls = Core.Field.Path("kernel.sysctls")
    static let namespaceCgroup = Core.Field.Path("namespaces.cgroup")
    static let namespaceUser = Core.Field.Path("namespaces.user")
    static let namespacePID = Core.Field.Path("namespaces.pid")
    static let namespaceIPC = Core.Field.Path("namespaces.ipc")
    static let namespaceUTS = Core.Field.Path("namespaces.uts")
    static let resourcesCPUShares = Core.Field.Path("resources.cpu.shares")
    static let resourcesCPUQuota = Core.Field.Path("resources.cpu.quota")
    static let resourcesCPUPeriod = Core.Field.Path("resources.cpu.period")
    static let resourcesCPUSet = Core.Field.Path("resources.cpu.set")
    static let resourcesCPURealtimeRuntime = Core.Field.Path("resources.cpu.realtimeRuntime")
    static let resourcesCPURealtimePeriod = Core.Field.Path("resources.cpu.realtimePeriod")
    static let resourcesMemoryReservation = Core.Field.Path("resources.memory.reservation")
    static let resourcesMemorySwapLimit = Core.Field.Path("resources.memory.swapLimit")
    static let resourcesMemorySwappiness = Core.Field.Path("resources.memory.swappiness")
    static let resourcesOOMKillDisable = Core.Field.Path("resources.oom.killDisabled")
    static let resourcesOOMScoreAdjust = Core.Field.Path("resources.oom.scoreAdjust")
    static let resourcesBlockIO = Core.Field.Path("resources.blockIO")
    static let storageOptions = Core.Field.Path("storage.options")
    static let storageVolumesFrom = Core.Field.Path("storage.volumesFrom")
    static let composeSecrets = Core.Field.Path("compose.secrets")
    static let composeConfigs = Core.Field.Path("compose.configs")
    static let composeProfiles = Core.Field.Path("compose.profiles")
    static let composeDeploy = Core.Field.Path("compose.deploy")
    static let composeScale = Core.Field.Path("compose.scale")
    static let composeLinks = Core.Field.Path("compose.links")
    static let composeDependsOn = Core.Field.Path("compose.dependsOn")
    static let composeProvider = Core.Field.Path("compose.provider")
    static let composeModels = Core.Field.Path("compose.models")
    static let composeUseAPISocket = Core.Field.Path("compose.useAPISocket")
}

public extension Core.Schema.Definition {
    static func containerRunEdit(runtimeKind: Core.Runtime.Kind,
                                 operation: Core.Schema.Operation = .containerCreate) -> Core.Schema.Definition {
        let profile = Core.Runtime.module(for: runtimeKind)?.schemaProfile()
            ?? Core.Schema.RuntimeProfile(kind: runtimeKind, supportedPaths: [])
        return containerRunEdit(runtimeProfile: profile, operation: operation)
    }

    internal static func containerRunEdit(runtimeProfile profile: Core.Schema.RuntimeProfile,
                                          operation: Core.Schema.Operation = .containerCreate) -> Core.Schema.Definition {
        return Core.Schema.Definition(operation: operation,
                                      runtimeKind: profile.kind,
                                      fields: Self.runtimeAwareRunFields(initialRuntime: profile.kind,
                                                                         profile: profile))
    }

    static var canonicalRunFields: [Core.Schema.FieldDescriptor] {
        canonicalRunFieldDescriptors
    }

    private static func runtimeAwareRunFields(initialRuntime: Core.Runtime.Kind,
                                              profile: Core.Schema.RuntimeProfile) -> [Core.Schema.FieldDescriptor] {
        let fields = canonicalRunFieldDescriptors.map { descriptor in
            var field = descriptor
            if field.path == .runtimeKind {
                field.defaultValue = .string(initialRuntime.rawValue)
            }
            return field
        }
        return profile.apply(to: fields)
    }

    private static var canonicalRunFieldDescriptors: [Core.Schema.FieldDescriptor] {
        func field(_ path: Core.Field.Path,
                   _ kind: Core.Schema.ValueKind,
                   _ section: Core.Schema.FieldSection,
                   _ label: String,
                   defaultValue: Core.Schema.Value,
                   required: Bool = false,
                   options: [Core.Schema.ValueOption] = [],
                   flag: String? = nil,
                   example: String? = nil,
                   docker: (String, String)? = nil,
                   compose: (String, String)? = nil,
                   tip: String) -> Core.Schema.FieldDescriptor {
            var aliases: [Core.Schema.SourceAlias] = []
            if let flag {
                aliases.append(.init(source: .appleCLI, name: flag, example: example ?? flag))
            }
            if let docker {
                aliases.append(.init(source: .dockerCLI, name: docker.0, example: docker.1))
            }
            if let compose {
                aliases.append(.init(source: .compose, name: compose.0, example: compose.1))
            }
            return Core.Schema.FieldDescriptor(
                path: path,
                valueKind: kind,
                section: section,
                labelKey: "schema.field.\(path.rawValue)",
                defaultLabel: label,
                defaultValue: defaultValue,
                isRequired: required,
                options: options,
                defaultTip: tip,
                sourceAliases: aliases
            )
        }

        func preserved(_ path: Core.Field.Path,
                       _ kind: Core.Schema.ValueKind,
                       _ label: String,
                       defaultValue: Core.Schema.Value,
                       docker: (String, String)? = nil,
                       compose: (String, String)? = nil,
                       tip: String) -> Core.Schema.FieldDescriptor {
            var aliases: [Core.Schema.SourceAlias] = []
            if let docker { aliases.append(.init(source: .dockerCLI, name: docker.0, example: docker.1)) }
            if let compose { aliases.append(.init(source: .compose, name: compose.0, example: compose.1)) }
            return Core.Schema.FieldDescriptor(
                path: path,
                valueKind: kind,
                section: .dockerCompose,
                labelKey: "schema.field.\(path.rawValue)",
                defaultLabel: label,
                defaultValue: defaultValue,
                defaultTip: tip,
                sourceAliases: aliases
            )
        }

        let restartOptions = [
            Core.Schema.ValueOption(value: "no", labelKey: "schema.option.restart.no", defaultLabel: "No"),
            Core.Schema.ValueOption(value: "always", labelKey: "schema.option.restart.always", defaultLabel: "Always"),
            Core.Schema.ValueOption(value: "on-failure", labelKey: "schema.option.restart.onFailure", defaultLabel: "On failure"),
        ]
        let schemeOptions = [
            Core.Schema.ValueOption(value: "", labelKey: "schema.option.default", defaultLabel: "Default"),
            Core.Schema.ValueOption(value: "auto", labelKey: "schema.option.scheme.auto", defaultLabel: "Auto"),
            Core.Schema.ValueOption(value: "https", labelKey: "schema.option.scheme.https", defaultLabel: "HTTPS"),
            Core.Schema.ValueOption(value: "http", labelKey: "schema.option.scheme.http", defaultLabel: "HTTP"),
        ]
        let progressOptions = [
            Core.Schema.ValueOption(value: "", labelKey: "schema.option.default", defaultLabel: "Default"),
            Core.Schema.ValueOption(value: "auto", labelKey: "schema.option.progress.auto", defaultLabel: "Auto"),
            Core.Schema.ValueOption(value: "none", labelKey: "schema.option.progress.none", defaultLabel: "None"),
            Core.Schema.ValueOption(value: "ansi", labelKey: "schema.option.progress.ansi", defaultLabel: "ANSI"),
            Core.Schema.ValueOption(value: "plain", labelKey: "schema.option.progress.plain", defaultLabel: "Plain"),
            Core.Schema.ValueOption(value: "color", labelKey: "schema.option.progress.color", defaultLabel: "Color"),
        ]

        return [
            field(.runtimeKind, .string, .runtime, "Runtime", defaultValue: .string(""),
                  tip: "Selects the container runtime used for previewing and running this container."),
            field(.imageReference, .string, .essentials, "Image", defaultValue: .string(""), required: true,
                  flag: "<image>", example: "nginx:latest", docker: ("IMAGE", "docker run nginx:latest"), compose: ("image", "image: nginx:latest"),
                  tip: "The container image to run. If it is not local, Contained pulls it before running."),
            field(.imagePlatform, .string, .essentials, "Platform", defaultValue: .string(""),
                  flag: "--platform", example: "--platform linux/arm64", docker: ("--platform", "--platform linux/arm64"), compose: ("platform", "platform: linux/arm64"),
                  tip: "Pins a multi-platform image to an OS and architecture when the selected runtime supports it."),
            field(.imageOS, .string, .essentials, "Image OS", defaultValue: .string(""),
                  flag: "--os", example: "--os linux", docker: ("--platform", "--platform linux/arm64"), compose: ("platform", "platform: linux/arm64"),
                  tip: "Sets only the image operating system when no full platform is set."),
            field(.imageArchitecture, .string, .essentials, "Image architecture", defaultValue: .string(""),
                  flag: "--arch", example: "--arch arm64", docker: ("--platform", "--platform linux/arm64"), compose: ("platform", "platform: linux/arm64"),
                  tip: "Sets only the image architecture when no full platform is set."),
            field(.containerName, .string, .essentials, "Name", defaultValue: .string(""),
                  flag: "--name", example: "--name web", docker: ("--name", "--name web"), compose: ("container_name", "container_name: web"),
                  tip: "Optional container ID. Leave blank and the runtime will generate one."),
            field(.processCommand, .commandLine, .essentials, "Command", defaultValue: .commandLine([]),
                  flag: "<arguments>", example: "sleep infinity", docker: ("COMMAND", "docker run alpine sleep infinity"), compose: ("command", "command: sleep infinity"),
                  tip: "Optional arguments to run instead of the image's default command."),
            field(.processEntrypoint, .string, .process, "Entrypoint", defaultValue: .string(""),
                  flag: "--entrypoint", example: "--entrypoint /bin/sh", docker: ("--entrypoint", "--entrypoint /bin/sh"), compose: ("entrypoint", "entrypoint: /bin/sh"),
                  tip: "Overrides the image entrypoint program."),
            field(.processDetach, .bool, .essentials, "Run in the background", defaultValue: .bool(true),
                  flag: "--detach", example: "--detach", docker: ("--detach", "--detach"), compose: ("detach-like", "Compose services run detached from the form"),
                  tip: "Runs without attaching to the process output."),
            field(.processRemoveOnExit, .bool, .essentials, "Remove when stopped", defaultValue: .bool(false),
                  flag: "--rm, --remove", example: "--rm", docker: ("--rm", "--rm"), compose: ("", ""),
                  tip: "Deletes the container record after it stops. Use volumes for data you need to keep."),
            field(.resourcesCPULimit, .string, .resources, "CPUs", defaultValue: .string(""),
                  flag: "--cpus", example: "--cpus 2", docker: ("--cpus", "--cpus 2"), compose: ("cpus", "cpus: 2"),
                  tip: "Limits how many CPUs the container can use. Leave blank to let the runtime decide."),
            field(.resourcesMemoryLimit, .string, .resources, "Memory", defaultValue: .string(""),
                  flag: "--memory", example: "--memory 1G", docker: ("--memory", "--memory 1G"), compose: ("mem_limit", "mem_limit: 512M"),
                  tip: "Sets a memory ceiling for the container."),
            field(.networkPorts, .portList, .networking, "Ports", defaultValue: .portList([]),
                  flag: "--publish", example: "--publish 127.0.0.1:8080:80/tcp", docker: ("--publish", "--publish 8080:80"), compose: ("ports", "ports: [\"8080:80\"]"),
                  tip: "Publishes container ports to the host."),
            field(.networkName, .string, .networking, "Network", defaultValue: .string(""),
                  flag: "--network", example: "--network media,mtu=1280", docker: ("--network", "--network media"), compose: ("network_mode/networks", "networks: [media]"),
                  tip: "Attaches the container to a runtime network."),
            field(.networkSockets, .socketList, .networking, "Sockets", defaultValue: .socketList([]),
                  flag: "--publish-socket", example: "--publish-socket /tmp/app.sock:/run/app.sock",
                  tip: "Publishes a host socket path into the container."),
            field(.storageVolumes, .volumeList, .storage, "Volumes", defaultValue: .volumeList([]),
                  flag: "--volume", example: "--volume data:/var/lib/app:ro", docker: ("--volume", "--volume data:/var/lib/app"), compose: ("volumes", "volumes: [\"data:/var/lib/app\"]"),
                  tip: "Bind mounts a host path or named volume into the container."),
            field(.storageMounts, .stringList, .storage, "Mounts", defaultValue: .stringList([]),
                  flag: "--mount", example: "--mount type=bind,source=/host,target=/container,readonly", docker: ("--mount", "--mount type=bind,src=/host,dst=/container"), compose: ("volumes long syntax", "volumes: [{type: bind, source: ./data, target: /data}]"),
                  tip: "Advanced mount syntax for bind, volume, or tmpfs style mounts."),
            field(.storageTmpfs, .stringList, .storage, "Tmpfs mounts", defaultValue: .stringList([]),
                  flag: "--tmpfs", example: "--tmpfs /tmp", docker: ("--tmpfs", "--tmpfs /tmp"), compose: ("tmpfs", "tmpfs: [/tmp]"),
                  tip: "Mounts an in-memory filesystem at the given container path."),
            field(.environmentVariables, .keyValueList, .environment, "Environment variables", defaultValue: .keyValueList([]),
                  flag: "--env", example: "--env KEY=value", docker: ("--env", "--env KEY=value"), compose: ("environment", "environment: { KEY: value }"),
                  tip: "Sets environment variables inside the container."),
            field(.environmentFiles, .stringList, .environment, "Environment files", defaultValue: .stringList([]),
                  flag: "--env-file", example: "--env-file ./app.env", docker: ("--env-file", "--env-file ./app.env"), compose: ("env_file", "env_file: ./app.env"),
                  tip: "Loads environment variables from a file."),
            field(.lifecycleRestartPolicy, .enumeration, .metadata, "Restart policy", defaultValue: .enumeration("no"), options: restartOptions,
                  docker: ("--restart", "--restart=always"), compose: ("restart", "restart: always"),
                  tip: "Contained stores this as local/runtime metadata and uses it for restart behavior."),
            field(.metadataLabels, .keyValueList, .metadata, "Labels", defaultValue: .keyValueList([]),
                  flag: "--label", example: "--label team=infra", docker: ("--label", "--label team=infra"), compose: ("labels", "labels: { team: infra }"),
                  tip: "Adds runtime metadata labels. Contained app personalization is stored separately."),
            field(.processInteractive, .bool, .process, "Keep stdin open", defaultValue: .bool(false),
                  flag: "--interactive", example: "--interactive", docker: ("--interactive", "--interactive"), compose: ("stdin_open", "stdin_open: true"),
                  tip: "Keeps standard input open for interactive processes."),
            field(.processTTY, .bool, .process, "Allocate TTY", defaultValue: .bool(false),
                  flag: "--tty", example: "--tty", docker: ("--tty", "--tty"), compose: ("tty", "tty: true"),
                  tip: "Allocates a terminal for the process."),
            field(.processWorkingDirectory, .string, .process, "Working directory", defaultValue: .string(""),
                  flag: "--workdir, --cwd", example: "--workdir /app", docker: ("--workdir", "--workdir /app"), compose: ("working_dir", "working_dir: /app"),
                  tip: "Sets the initial working directory inside the container."),
            field(.processUser, .string, .process, "User", defaultValue: .string(""),
                  flag: "--user", example: "--user 1000:1000", docker: ("--user", "--user 1000:1000"), compose: ("user", "user: \"1000:1000\""),
                  tip: "Runs the process as a user name or uid[:gid]."),
            field(.processUserID, .string, .process, "User ID", defaultValue: .string(""),
                  flag: "--uid", example: "--uid 1000", tip: "Sets the numeric user ID for the process."),
            field(.processGroupID, .string, .process, "Group ID", defaultValue: .string(""),
                  flag: "--gid", example: "--gid 1000", tip: "Sets the numeric group ID for the process."),
            field(.resourcesSharedMemorySize, .string, .process, "Shared memory", defaultValue: .string(""),
                  flag: "--shm-size", example: "--shm-size 64M", docker: ("--shm-size", "--shm-size 64M"), compose: ("shm_size", "shm_size: 64M"),
                  tip: "Sets the size of /dev/shm."),
            field(.processUlimits, .stringList, .process, "Resource limits", defaultValue: .stringList([]),
                  flag: "--ulimit", example: "--ulimit nofile=1024:2048", docker: ("--ulimit", "--ulimit nofile=1024:2048"), compose: ("ulimits", "ulimits: { nofile: { soft: 1024, hard: 2048 } }"),
                  tip: "Sets process resource limits."),
            field(.securityCapabilitiesAdd, .stringList, .security, "Add capabilities", defaultValue: .stringList([]),
                  flag: "--cap-add", example: "--cap-add CAP_NET_RAW", docker: ("--cap-add", "--cap-add CAP_NET_RAW"), compose: ("cap_add", "cap_add: [CAP_NET_RAW]"),
                  tip: "Adds Linux capabilities to the container."),
            field(.securityCapabilitiesDrop, .stringList, .security, "Drop capabilities", defaultValue: .stringList([]),
                  flag: "--cap-drop", example: "--cap-drop ALL", docker: ("--cap-drop", "--cap-drop ALL"), compose: ("cap_drop", "cap_drop: [ALL]"),
                  tip: "Drops Linux capabilities from the container."),
            field(.outputContainerIDFile, .string, .process, "Container ID file", defaultValue: .string(""),
                  flag: "--cidfile", example: "--cidfile /tmp/container.cid", docker: ("--cidfile", "--cidfile /tmp/container.cid"),
                  tip: "Writes the new container ID to a file."),
            field(.securityReadOnlyRootFS, .bool, .security, "Read-only filesystem", defaultValue: .bool(false),
                  flag: "--read-only", example: "--read-only", docker: ("--read-only", "--read-only"), compose: ("read_only", "read_only: true"),
                  tip: "Mounts the container root filesystem as read-only."),
            field(.securityUseInit, .bool, .security, "Use an init process", defaultValue: .bool(false),
                  flag: "--init", example: "--init", docker: ("--init", "--init"), compose: ("init", "init: true"),
                  tip: "Runs a small init process that forwards signals and reaps processes."),
            field(.securityRosetta, .bool, .security, "Rosetta", defaultValue: .bool(false),
                  flag: "--rosetta", example: "--rosetta", tip: "Allows x86-64 Linux binaries to run through Rosetta when supported."),
            field(.securitySSHAgent, .bool, .security, "Forward SSH agent", defaultValue: .bool(false),
                  flag: "--ssh", example: "--ssh", tip: "Forwards your host SSH agent socket into the container."),
            field(.securityVirtualization, .bool, .security, "Expose virtualization", defaultValue: .bool(false),
                  flag: "--virtualization", example: "--virtualization", tip: "Exposes virtualization capabilities to the container when host and guest support it."),
            field(.networkDNSDisabled, .bool, .networking, "Disable DNS", defaultValue: .bool(false),
                  flag: "--no-dns", example: "--no-dns", tip: "Prevents DNS from being configured in the container."),
            field(.networkDNSServers, .stringList, .networking, "DNS servers", defaultValue: .stringList([]),
                  flag: "--dns", example: "--dns 1.1.1.1", docker: ("--dns", "--dns 1.1.1.1"), compose: ("dns", "dns: [1.1.1.1]"),
                  tip: "Sets DNS nameserver IP addresses."),
            field(.networkDNSDomain, .string, .networking, "DNS domain", defaultValue: .string(""),
                  flag: "--dns-domain", example: "--dns-domain example.test", tip: "Sets the default DNS domain."),
            field(.networkDNSSearchDomains, .stringList, .networking, "DNS search domains", defaultValue: .stringList([]),
                  flag: "--dns-search", example: "--dns-search home.arpa", docker: ("--dns-search", "--dns-search home.arpa"), compose: ("dns_search", "dns_search: [home.arpa]"),
                  tip: "Adds DNS search domains."),
            field(.networkDNSOptions, .stringList, .networking, "DNS options", defaultValue: .stringList([]),
                  flag: "--dns-option", example: "--dns-option ndots:2", docker: ("--dns-option", "--dns-option ndots:2"), compose: ("dns_opt", "dns_opt: [ndots:2]"),
                  tip: "Adds resolver options."),
            field(.imageInitReference, .string, .imageFetch, "Init image", defaultValue: .string(""),
                  flag: "--init-image", example: "--init-image init:latest", tip: "Uses a custom init image instead of the runtime default."),
            field(.kernelPath, .string, .imageFetch, "Kernel", defaultValue: .string(""),
                  flag: "--kernel", example: "--kernel /path/to/vmlinux", tip: "Uses a custom kernel path."),
            field(.runtimeHandler, .string, .imageFetch, "Runtime handler", defaultValue: .string(""),
                  flag: "--runtime", example: "--runtime container-runtime-linux", compose: ("runtime", "runtime: runc"),
                  tip: "Sets the low-level runtime handler."),
            field(.registryScheme, .enumeration, .imageFetch, "Registry scheme", defaultValue: .enumeration(""), options: schemeOptions,
                  flag: "--scheme", example: "--scheme https", tip: "Controls the registry connection scheme for image fetches."),
            field(.progressMode, .enumeration, .imageFetch, "Progress", defaultValue: .enumeration(""), options: progressOptions,
                  flag: "--progress", example: "--progress plain", tip: "Controls progress output style for image fetches."),
            field(.imageMaxConcurrentDownloads, .string, .imageFetch, "Max parallel downloads", defaultValue: .string(""),
                  flag: "--max-concurrent-downloads", example: "--max-concurrent-downloads 2", tip: "Limits concurrent image downloads."),

            preserved(.networkExtraHosts, .stringList, "Extra hosts", defaultValue: .stringList([]), docker: ("--add-host", "--add-host host.docker.internal=host-gateway"), compose: ("extra_hosts", "extra_hosts: [\"host.docker.internal:host-gateway\"]"), tip: "Adds entries to /etc/hosts when the selected runtime supports it."),
            preserved(.networkHostname, .string, "Hostname", defaultValue: .string(""), docker: ("--hostname", "--hostname app"), compose: ("hostname", "hostname: app"), tip: "Sets the container hostname when the selected runtime supports it."),
            preserved(.networkDomainName, .string, "Domain name", defaultValue: .string(""), docker: ("--domainname", "--domainname example.test"), compose: ("domainname", "domainname: example.test"), tip: "Sets the container NIS/domain name."),
            preserved(.networkMacAddress, .string, "MAC address", defaultValue: .string(""), docker: ("--mac-address", "--mac-address 02:42:ac:11:00:02"), compose: ("mac_address", "mac_address: 02:42:ac:11:00:02"), tip: "Requests a fixed MAC address."),
            preserved(.networkExpose, .stringList, "Expose ports", defaultValue: .stringList([]), docker: ("--expose", "--expose 80"), compose: ("expose", "expose: [80]"), tip: "Exposes container ports without publishing them to the host."),
            preserved(.networkPublishAll, .bool, "Publish all exposed ports", defaultValue: .bool(false), docker: ("--publish-all", "--publish-all"), tip: "Publishes every exposed port to random host ports."),
            preserved(.imagePullPolicy, .string, "Pull policy", defaultValue: .string(""), docker: ("--pull", "--pull=always"), compose: ("pull_policy", "pull_policy: always"), tip: "Controls when the selected runtime pulls the image."),
            preserved(.processAttachStreams, .stringList, "Attach streams", defaultValue: .stringList([]), docker: ("--attach", "--attach stdout"), compose: ("attach", "attach: false"), tip: "Controls attached STDIN/STDOUT/STDERR streams."),
            preserved(.loggingDriver, .string, "Logging driver", defaultValue: .string(""), docker: ("--log-driver", "--log-driver syslog"), compose: ("logging.driver", "logging: { driver: syslog }"), tip: "Selects a Docker logging driver."),
            preserved(.loggingOptions, .keyValueList, "Logging options", defaultValue: .keyValueList([]), docker: ("--log-opt", "--log-opt max-size=10m"), compose: ("logging.options", "logging: { options: { max-size: 10m } }"), tip: "Configures logging driver options."),
            preserved(.metadataLabelFiles, .stringList, "Label files", defaultValue: .stringList([]), docker: ("--label-file", "--label-file ./labels"), tip: "Loads labels from a file."),
            preserved(.lifecycleStopSignal, .string, "Stop signal", defaultValue: .string(""), docker: ("--stop-signal", "--stop-signal SIGTERM"), compose: ("stop_signal", "stop_signal: SIGTERM"), tip: "Signal used to stop the container."),
            preserved(.lifecycleStopGracePeriod, .string, "Stop grace period", defaultValue: .string(""), docker: ("--stop-timeout", "--stop-timeout 30"), compose: ("stop_grace_period", "stop_grace_period: 30s"), tip: "How long Compose waits before force-stopping."),
            preserved(.devices, .stringList, "Devices", defaultValue: .stringList([]), docker: ("--device", "--device /dev/sda:/dev/xvdc"), compose: ("devices", "devices: [/dev/sda:/dev/xvdc]"), tip: "Passes host devices into the container."),
            preserved(.gpus, .string, "GPUs", defaultValue: .string(""), docker: ("--gpus", "--gpus all"), compose: ("gpus", "gpus: all"), tip: "Requests GPU devices."),
            preserved(.processSupplementalGroups, .stringList, "Supplemental groups", defaultValue: .stringList([]), docker: ("--group-add", "--group-add audio"), compose: ("group_add", "group_add: [audio]"), tip: "Adds supplemental groups."),
            preserved(.securityPrivileged, .bool, "Privileged", defaultValue: .bool(false), docker: ("--privileged", "--privileged"), compose: ("privileged", "privileged: true"), tip: "Runs with extended host privileges."),
            preserved(.securityOptions, .stringList, "Security options", defaultValue: .stringList([]), docker: ("--security-opt", "--security-opt no-new-privileges=true"), compose: ("security_opt", "security_opt: [no-new-privileges:true]"), tip: "Applies Docker security profiles or labels."),
            preserved(.kernelSysctls, .keyValueList, "Sysctls", defaultValue: .keyValueList([]), docker: ("--sysctl", "--sysctl net.ipv4.ip_forward=1"), compose: ("sysctls", "sysctls: { net.ipv4.ip_forward: 1 }"), tip: "Sets kernel sysctls for the container."),
            preserved(.namespaceCgroup, .string, "Cgroup namespace", defaultValue: .string(""), docker: ("--cgroupns", "--cgroupns private"), compose: ("cgroup", "cgroup: private"), tip: "Controls the cgroup namespace."),
            preserved(.namespaceUser, .string, "User namespace", defaultValue: .string(""), docker: ("--userns", "--userns host"), compose: ("userns_mode", "userns_mode: host"), tip: "Controls the user namespace."),
            preserved(.namespacePID, .string, "PID namespace", defaultValue: .string(""), docker: ("--pid", "--pid host"), compose: ("pid", "pid: host"), tip: "Controls the process namespace."),
            preserved(.namespaceIPC, .string, "IPC namespace", defaultValue: .string(""), docker: ("--ipc", "--ipc host"), compose: ("ipc", "ipc: host"), tip: "Controls the IPC namespace."),
            preserved(.namespaceUTS, .string, "UTS namespace", defaultValue: .string(""), compose: ("uts", "uts: host"), tip: "Controls the UTS namespace."),
            preserved(.resourcesCPUShares, .string, "CPU shares", defaultValue: .string(""), docker: ("--cpu-shares", "--cpu-shares 512"), compose: ("cpu_shares", "cpu_shares: 512"), tip: "Sets relative CPU weight."),
            preserved(.resourcesCPUQuota, .string, "CPU quota", defaultValue: .string(""), docker: ("--cpu-quota", "--cpu-quota 50000"), compose: ("cpu_quota", "cpu_quota: 50000"), tip: "Sets CPU CFS quota."),
            preserved(.resourcesCPUPeriod, .string, "CPU period", defaultValue: .string(""), docker: ("--cpu-period", "--cpu-period 100000"), compose: ("cpu_period", "cpu_period: 100000"), tip: "Sets CPU CFS period."),
            preserved(.resourcesCPUSet, .string, "CPU set", defaultValue: .string(""), docker: ("--cpuset-cpus", "--cpuset-cpus 0-3"), compose: ("cpuset", "cpuset: 0-3"), tip: "Pins execution to specific CPUs."),
            preserved(.resourcesCPURealtimeRuntime, .string, "CPU realtime runtime", defaultValue: .string(""), docker: ("--cpu-rt-runtime", "--cpu-rt-runtime 95000"), compose: ("cpu_rt_runtime", "cpu_rt_runtime: 95000"), tip: "Sets real-time CPU runtime."),
            preserved(.resourcesCPURealtimePeriod, .string, "CPU realtime period", defaultValue: .string(""), docker: ("--cpu-rt-period", "--cpu-rt-period 100000"), compose: ("cpu_rt_period", "cpu_rt_period: 100000"), tip: "Sets real-time CPU period."),
            preserved(.resourcesMemoryReservation, .string, "Memory reservation", defaultValue: .string(""), compose: ("mem_reservation", "mem_reservation: 256M"), tip: "Sets a soft memory reservation."),
            preserved(.resourcesMemorySwapLimit, .string, "Swap limit", defaultValue: .string(""), docker: ("--memory-swap", "--memory-swap 1G"), compose: ("memswap_limit", "memswap_limit: 1G"), tip: "Sets memory plus swap limit."),
            preserved(.resourcesMemorySwappiness, .string, "Memory swappiness", defaultValue: .string(""), docker: ("--memory-swappiness", "--memory-swappiness 0"), compose: ("mem_swappiness", "mem_swappiness: 0"), tip: "Controls anonymous page swapping."),
            preserved(.resourcesOOMKillDisable, .bool, "Disable OOM killer", defaultValue: .bool(false), docker: ("--oom-kill-disable", "--oom-kill-disable"), compose: ("oom_kill_disable", "oom_kill_disable: true"), tip: "Disables OOM killer behavior."),
            preserved(.resourcesOOMScoreAdjust, .string, "OOM score adjustment", defaultValue: .string(""), docker: ("--oom-score-adj", "--oom-score-adj 500"), compose: ("oom_score_adj", "oom_score_adj: 500"), tip: "Adjusts host OOM scoring."),
            preserved(.resourcesBlockIO, .string, "Block I/O", defaultValue: .string(""), docker: ("--blkio-weight", "--blkio-weight 300"), compose: ("blkio_config", "blkio_config: { weight: 300 }"), tip: "Controls block I/O weighting and throttling."),
            preserved(.storageOptions, .keyValueList, "Storage options", defaultValue: .keyValueList([]), docker: ("--storage-opt", "--storage-opt size=120G"), compose: ("storage_opt", "storage_opt: { size: 120G }"), tip: "Passes storage driver options."),
            preserved(.storageVolumesFrom, .stringList, "Volumes from", defaultValue: .stringList([]), docker: ("--volumes-from", "--volumes-from db"), compose: ("volumes_from", "volumes_from: [db]"), tip: "Mounts volumes from another container."),
            preserved(.composeSecrets, .stringList, "Secrets", defaultValue: .stringList([]), compose: ("secrets", "secrets: [db_password]"), tip: "Compose secrets are preserved for runtimes that can apply them later."),
            preserved(.composeConfigs, .stringList, "Configs", defaultValue: .stringList([]), compose: ("configs", "configs: [app_config]"), tip: "Compose configs are preserved for runtimes that can apply them later."),
            preserved(.composeProfiles, .stringList, "Profiles", defaultValue: .stringList([]), compose: ("profiles", "profiles: [dev]"), tip: "Compose profiles select which services participate in a run."),
            preserved(.composeDeploy, .string, "Deploy metadata", defaultValue: .string(""), compose: ("deploy", "deploy: { replicas: 2 }"), tip: "Compose deploy metadata is preserved when the selected runtime cannot apply it."),
            preserved(.composeScale, .string, "Scale", defaultValue: .string(""), compose: ("scale", "scale: 2"), tip: "Compose service scale is preserved for future stack-oriented runtimes."),
            preserved(.composeLinks, .stringList, "Links", defaultValue: .stringList([]), compose: ("links", "links: [db]"), tip: "Legacy Compose links are preserved for reference."),
            preserved(.composeDependsOn, .stringList, "Dependencies", defaultValue: .stringList([]), compose: ("depends_on", "depends_on: { db: { condition: service_healthy } }"), tip: "Compose startup dependency metadata is preserved for reference."),
            preserved(.composeProvider, .string, "Provider", defaultValue: .string(""), compose: ("provider", "provider: awesomecloud"), tip: "Compose provider metadata is preserved for future runtimes."),
            preserved(.composeModels, .stringList, "Models", defaultValue: .stringList([]), compose: ("models", "models: [ai_model]"), tip: "Compose model metadata is preserved for future runtimes."),
            preserved(.composeUseAPISocket, .bool, "Use API socket", defaultValue: .bool(false), compose: ("use_api_socket", "use_api_socket: true"), tip: "Compose API socket access is preserved for future runtimes."),
        ]
    }
}
