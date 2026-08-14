import Foundation

public extension Core.Schema.Document {
    static func containerCreate(runtimeKind: Core.Runtime.Kind) -> Core.Schema.Document {
        var document = Core.Schema.Document(operation: .containerCreate, runtimeKind: runtimeKind)
        let definition = Core.Schema.Definition.containerRunEdit(runtimeKind: runtimeKind)
        for field in definition.fields {
            if !field.defaultValue.isEmpty || field.isRequired || field.path == .processDetach || field.path == .lifecycleRestartPolicy {
                document.values[field.path] = field.defaultValue
            }
        }
        document.set(.runtimeKind, .string(runtimeKind.rawValue))
        return document
    }

    static func containerCreate(from request: Core.Container.CreateRequest) -> Core.Schema.Document {
        var document = Core.Schema.Document.containerCreate(runtimeKind: request.runtimeKind)
        document.set(.imageReference, .string(request.image))
        document.set(.imagePlatform, .string(request.platform))
        document.set(.imageOS, .string(request.os))
        document.set(.imageArchitecture, .string(request.architecture))
        document.set(.containerName, .string(request.name))
        document.set(.processCommand, .commandLine(request.command))
        document.set(.processEntrypoint, .string(request.entrypoint))
        document.set(.processDetach, .bool(request.detach))
        document.set(.processRemoveOnExit, .bool(request.removeOnExit))
        document.set(.processInteractive, .bool(request.interactive))
        document.set(.processTTY, .bool(request.tty))
        document.set(.resourcesCPULimit, .string(request.cpus))
        document.set(.resourcesMemoryLimit, .string(request.memory))
        document.set(.environmentVariables, .keyValueList(request.env))
        document.set(.environmentFiles, .stringList(request.envFiles))
        document.set(.networkPorts, .portList(request.ports))
        document.set(.storageVolumes, .volumeList(request.volumes))
        document.set(.storageMounts, .stringList(request.mounts))
        document.set(.networkSockets, .socketList(request.sockets))
        document.set(.metadataLabels, .keyValueList(request.labels))
        document.set(.lifecycleRestartPolicy, .enumeration(request.restart.rawValue))
        document.set(.securityReadOnlyRootFS, .bool(request.readOnly))
        document.set(.securityUseInit, .bool(request.useInit))
        document.set(.securityRosetta, .bool(request.rosetta))
        document.set(.securitySSHAgent, .bool(request.ssh))
        document.set(.securityVirtualization, .bool(request.virtualization))
        document.set(.processWorkingDirectory, .string(request.workingDir))
        document.set(.processUser, .string(request.user))
        document.set(.processUserID, .string(request.uid))
        document.set(.processGroupID, .string(request.gid))
        document.set(.resourcesSharedMemorySize, .string(request.shmSize))
        document.set(.securityCapabilitiesAdd, .stringList(request.capAdd))
        document.set(.securityCapabilitiesDrop, .stringList(request.capDrop))
        document.set(.outputContainerIDFile, .string(request.cidFile))
        document.set(.imageInitReference, .string(request.initImage))
        document.set(.kernelPath, .string(request.kernel))
        document.set(.networkName, .string(request.network))
        document.set(.networkDNSDisabled, .bool(request.noDNS))
        document.set(.networkDNSServers, .stringList(request.dns))
        document.set(.networkDNSDomain, .string(request.dnsDomain))
        document.set(.networkDNSSearchDomains, .stringList(request.dnsSearch))
        document.set(.networkDNSOptions, .stringList(request.dnsOption))
        document.set(.storageTmpfs, .stringList(request.tmpfs))
        document.set(.processUlimits, .stringList(request.ulimits))
        document.set(.runtimeHandler, .string(request.runtime))
        document.set(.registryScheme, .enumeration(request.scheme))
        document.set(.progressMode, .enumeration(request.progress))
        document.set(.imageMaxConcurrentDownloads, .string(request.maxConcurrentDownloads))
        document.set(.networkExtraHosts, .stringList(request.extraHosts))
        document.set(.networkHostname, .string(request.hostname))
        document.set(.networkDomainName, .string(request.domainName))
        document.set(.networkMacAddress, .string(request.macAddress))
        document.set(.networkExpose, .stringList(request.expose))
        document.set(.networkPublishAll, .bool(request.publishAll))
        document.set(.imagePullPolicy, .string(request.pullPolicy))
        document.set(.processAttachStreams, .stringList(request.attachStreams))
        document.set(.loggingDriver, .string(request.loggingDriver))
        document.set(.loggingOptions, .keyValueList(request.loggingOptions))
        document.set(.metadataLabelFiles, .stringList(request.labelFiles))
        document.set(.lifecycleStopSignal, .string(request.stopSignal))
        document.set(.lifecycleStopGracePeriod, .string(request.stopGracePeriod))
        document.set(.devices, .stringList(request.devices))
        document.set(.gpus, .string(request.gpus))
        document.set(.processSupplementalGroups, .stringList(request.supplementalGroups))
        document.set(.securityPrivileged, .bool(request.privileged))
        document.set(.securityOptions, .stringList(request.securityOptions))
        document.set(.kernelSysctls, .keyValueList(request.sysctls))
        document.set(.namespaceCgroup, .string(request.cgroupNamespace))
        document.set(.namespaceUser, .string(request.userNamespace))
        document.set(.namespacePID, .string(request.pidNamespace))
        document.set(.namespaceIPC, .string(request.ipcNamespace))
        document.set(.namespaceUTS, .string(request.utsNamespace))
        document.set(.resourcesCPUShares, .string(request.cpuShares))
        document.set(.resourcesCPUQuota, .string(request.cpuQuota))
        document.set(.resourcesCPUPeriod, .string(request.cpuPeriod))
        document.set(.resourcesCPUSet, .string(request.cpuSet))
        document.set(.resourcesCPURealtimeRuntime, .string(request.cpuRealtimeRuntime))
        document.set(.resourcesCPURealtimePeriod, .string(request.cpuRealtimePeriod))
        document.set(.resourcesMemoryReservation, .string(request.memoryReservation))
        document.set(.resourcesMemorySwapLimit, .string(request.memorySwapLimit))
        document.set(.resourcesMemorySwappiness, .string(request.memorySwappiness))
        document.set(.resourcesOOMKillDisable, .bool(request.oomKillDisable))
        document.set(.resourcesOOMScoreAdjust, .string(request.oomScoreAdjust))
        document.set(.resourcesBlockIO, .string(request.blockIOWeight))
        document.set(.storageOptions, .keyValueList(request.storageOptions))
        document.set(.storageVolumesFrom, .stringList(request.volumesFrom))
        return document
    }

    static func containerEdit(from configuration: Core.Container.Configuration) -> Core.Schema.Document {
        var request = Core.Container.CreateRequest(runtimeKind: configuration.runtimeKind)
        request.image = configuration.image.reference
        request.platform = configuration.platform.display
        request.name = configuration.id
        request.command = configuration.initProcess.arguments
        request.tty = configuration.initProcess.terminal
        request.cpus = String(configuration.resources.cpus)
        request.memory = Self.memorySpec(configuration.resources.memoryInBytes)
        request.readOnly = configuration.readOnly
        request.useInit = configuration.useInit
        request.rosetta = configuration.rosetta
        request.ssh = configuration.ssh
        request.virtualization = configuration.virtualization
        request.workingDir = configuration.initProcess.workingDirectory ?? ""
        request.shmSize = configuration.shmSize.map(Self.memorySpec) ?? ""
        request.capAdd = configuration.capAdd
        request.capDrop = configuration.capDrop
        request.runtime = configuration.runtimeHandler ?? ""
        request.network = configuration.networks.first?.network ?? ""
        request.dns = configuration.dns?.nameservers ?? []
        request.dnsDomain = configuration.dns?.domain ?? ""
        request.dnsSearch = configuration.dns?.searchDomains ?? []
        request.dnsOption = configuration.dns?.options ?? []
        request.ports = configuration.publishedPorts.map {
            let hostPrefix = ($0.hostAddress ?? "").isEmpty || $0.hostAddress == "0.0.0.0" ? "" : "\($0.hostAddress!):"
            return Core.Container.Port(hostPort: "\(hostPrefix)\($0.hostPort)",
                                       containerPort: String($0.containerPort),
                                       proto: $0.proto ?? "tcp")
        }
        request.sockets = configuration.publishedSockets.compactMap { socket in
            guard let hostPath = socket.hostPath, let containerPath = socket.containerPath else { return nil }
            return Core.Container.Socket(hostPath: hostPath, containerPath: containerPath)
        }
        request.volumes = configuration.mounts.compactMap { mount in
            guard let source = mount.source, let target = mount.effectiveDestination else { return nil }
            return Core.Container.VolumeMount(source: source, target: target, readOnly: mount.readonly ?? false)
        }
        request.env = configuration.initProcess.environment.compactMap { entry in
            guard let eq = entry.firstIndex(of: "=") else { return nil }
            return Core.Container.KeyValue(key: String(entry[..<eq]),
                                           value: String(entry[entry.index(after: eq)...]))
        }
        request.labels = configuration.labels
            .filter { !$0.key.hasPrefix("contained.") || $0.key == "contained.stack" }
            .sorted { $0.key < $1.key }
            .map { Core.Container.KeyValue(key: $0.key, value: $0.value) }
        request.restart = Core.Container.RestartPolicy(label: configuration.labels["contained.restart"])
        var document = Core.Schema.Document.containerCreate(from: request)
        document.operation = .containerEdit
        return document
    }

    func validatedRequest(definition: Core.Schema.Definition? = nil) throws -> Core.Container.CreateRequest {
        let definition = definition ?? Core.Schema.Definition.containerRunEdit(runtimeKind: runtimeKind, operation: operation)
        let document = migrated(to: definition)
        let issues = document.rawValidationIssues(in: definition)
        let errors = issues.filter { $0.severity == .error }
        if !errors.isEmpty { throw Core.Schema.ValidationError.invalid(errors) }

        var request = Core.Container.CreateRequest(runtimeKind: document.runtimeKind)
        request.image = document.string(.imageReference, in: definition)
        request.platform = document.string(.imagePlatform, in: definition)
        request.os = document.string(.imageOS, in: definition)
        request.architecture = document.string(.imageArchitecture, in: definition)
        request.name = document.string(.containerName, in: definition)
        request.command = document.strings(.processCommand, in: definition).filter { !$0.isEmpty }
        request.entrypoint = document.string(.processEntrypoint, in: definition)
        request.detach = document.bool(.processDetach, in: definition)
        request.removeOnExit = document.bool(.processRemoveOnExit, in: definition)
        request.interactive = document.bool(.processInteractive, in: definition)
        request.tty = document.bool(.processTTY, in: definition)
        request.cpus = document.string(.resourcesCPULimit, in: definition)
        request.memory = document.string(.resourcesMemoryLimit, in: definition)
        request.env = document.keyValues(.environmentVariables, in: definition)
        request.envFiles = document.strings(.environmentFiles, in: definition)
        request.ports = document.ports(.networkPorts, in: definition)
        request.volumes = document.volumes(.storageVolumes, in: definition)
        request.mounts = document.strings(.storageMounts, in: definition)
        request.sockets = document.sockets(.networkSockets, in: definition)
        request.labels = document.keyValues(.metadataLabels, in: definition)
        request.restart = Core.Container.RestartPolicy(rawValue: document.string(.lifecycleRestartPolicy, in: definition)) ?? .no
        request.readOnly = document.bool(.securityReadOnlyRootFS, in: definition)
        request.useInit = document.bool(.securityUseInit, in: definition)
        request.rosetta = document.bool(.securityRosetta, in: definition)
        request.ssh = document.bool(.securitySSHAgent, in: definition)
        request.virtualization = document.bool(.securityVirtualization, in: definition)
        request.workingDir = document.string(.processWorkingDirectory, in: definition)
        request.user = document.string(.processUser, in: definition)
        request.uid = document.string(.processUserID, in: definition)
        request.gid = document.string(.processGroupID, in: definition)
        request.shmSize = document.string(.resourcesSharedMemorySize, in: definition)
        request.capAdd = document.strings(.securityCapabilitiesAdd, in: definition)
        request.capDrop = document.strings(.securityCapabilitiesDrop, in: definition)
        request.cidFile = document.string(.outputContainerIDFile, in: definition)
        request.initImage = document.string(.imageInitReference, in: definition)
        request.kernel = document.string(.kernelPath, in: definition)
        request.network = document.string(.networkName, in: definition)
        request.noDNS = document.bool(.networkDNSDisabled, in: definition)
        request.dns = document.strings(.networkDNSServers, in: definition)
        request.dnsDomain = document.string(.networkDNSDomain, in: definition)
        request.dnsSearch = document.strings(.networkDNSSearchDomains, in: definition)
        request.dnsOption = document.strings(.networkDNSOptions, in: definition)
        request.tmpfs = document.strings(.storageTmpfs, in: definition)
        request.ulimits = document.strings(.processUlimits, in: definition)
        request.runtime = document.string(.runtimeHandler, in: definition)
        request.scheme = document.string(.registryScheme, in: definition)
        request.progress = document.string(.progressMode, in: definition)
        request.maxConcurrentDownloads = document.string(.imageMaxConcurrentDownloads, in: definition)
        request.extraHosts = document.strings(.networkExtraHosts, in: definition)
        request.hostname = document.string(.networkHostname, in: definition)
        request.domainName = document.string(.networkDomainName, in: definition)
        request.macAddress = document.string(.networkMacAddress, in: definition)
        request.expose = document.strings(.networkExpose, in: definition)
        request.publishAll = document.bool(.networkPublishAll, in: definition)
        request.pullPolicy = document.string(.imagePullPolicy, in: definition)
        request.attachStreams = document.strings(.processAttachStreams, in: definition)
        request.loggingDriver = document.string(.loggingDriver, in: definition)
        request.loggingOptions = document.keyValues(.loggingOptions, in: definition)
        request.labelFiles = document.strings(.metadataLabelFiles, in: definition)
        request.stopSignal = document.string(.lifecycleStopSignal, in: definition)
        request.stopGracePeriod = document.string(.lifecycleStopGracePeriod, in: definition)
        request.devices = document.strings(.devices, in: definition)
        request.gpus = document.string(.gpus, in: definition)
        request.supplementalGroups = document.strings(.processSupplementalGroups, in: definition)
        request.privileged = document.bool(.securityPrivileged, in: definition)
        request.securityOptions = document.strings(.securityOptions, in: definition)
        request.sysctls = document.keyValues(.kernelSysctls, in: definition)
        request.cgroupNamespace = document.string(.namespaceCgroup, in: definition)
        request.userNamespace = document.string(.namespaceUser, in: definition)
        request.pidNamespace = document.string(.namespacePID, in: definition)
        request.ipcNamespace = document.string(.namespaceIPC, in: definition)
        request.utsNamespace = document.string(.namespaceUTS, in: definition)
        request.cpuShares = document.string(.resourcesCPUShares, in: definition)
        request.cpuQuota = document.string(.resourcesCPUQuota, in: definition)
        request.cpuPeriod = document.string(.resourcesCPUPeriod, in: definition)
        request.cpuSet = document.string(.resourcesCPUSet, in: definition)
        request.cpuRealtimeRuntime = document.string(.resourcesCPURealtimeRuntime, in: definition)
        request.cpuRealtimePeriod = document.string(.resourcesCPURealtimePeriod, in: definition)
        request.memoryReservation = document.string(.resourcesMemoryReservation, in: definition)
        request.memorySwapLimit = document.string(.resourcesMemorySwapLimit, in: definition)
        request.memorySwappiness = document.string(.resourcesMemorySwappiness, in: definition)
        request.oomKillDisable = document.bool(.resourcesOOMKillDisable, in: definition)
        request.oomScoreAdjust = document.string(.resourcesOOMScoreAdjust, in: definition)
        request.blockIOWeight = document.string(.resourcesBlockIO, in: definition)
        request.storageOptions = document.keyValues(.storageOptions, in: definition)
        request.volumesFrom = document.strings(.storageVolumesFrom, in: definition)
        return request
    }

    func validationIssues(in definition: Core.Schema.Definition? = nil) -> [Core.Schema.ValidationIssue] {
        let definition = definition ?? Core.Schema.Definition.containerRunEdit(runtimeKind: runtimeKind, operation: operation)
        return migrated(to: definition).rawValidationIssues(in: definition)
    }

    private func rawValidationIssues(in definition: Core.Schema.Definition) -> [Core.Schema.ValidationIssue] {
        var issues: [Core.Schema.ValidationIssue] = []
        let descriptorsByPath = Dictionary(uniqueKeysWithValues: definition.fields.map { ($0.path, $0) })
        for (path, value) in values {
            guard let descriptor = descriptorsByPath[path] else {
                issues.append(.init(field: path,
                                    severity: .error,
                                    messageKey: "schema.validation.unknownField",
                                    defaultMessage: "Unknown field: \(path.rawValue)."))
                continue
            }
            guard descriptor.valueKind == value.valueKind else {
                issues.append(.init(field: path,
                                    severity: .error,
                                    messageKey: "schema.validation.wrongType",
                                    defaultMessage: "\(descriptor.defaultLabel) has the wrong value type."))
                continue
            }
            let support = descriptor.support(for: runtimeKind)
            if support.state == .disabled, !value.isEmpty {
                issues.append(.init(field: path,
                                    severity: .warning,
                                    messageKey: support.disabledReasonKey ?? "schema.validation.disabledField",
                                    defaultMessage: support.defaultDisabledReason ?? "\(descriptor.defaultLabel) is not executable by this runtime."))
            }
        }
        for descriptor in definition.fields where descriptor.isRequired {
            let value = values[descriptor.path] ?? descriptor.defaultValue
            if value.isEmpty {
                issues.append(.init(field: descriptor.path,
                                    severity: .error,
                                    messageKey: "schema.validation.required",
                                    defaultMessage: "\(descriptor.defaultLabel) is required."))
            }
        }
        if !string(.resourcesMemoryLimit, in: definition).isEmpty,
           Self.parseMemoryBytes(string(.resourcesMemoryLimit, in: definition)) == nil {
            issues.append(.init(field: .resourcesMemoryLimit,
                                severity: .error,
                                messageKey: "schema.validation.memory",
                                defaultMessage: "Memory must be a positive number with optional K, M, G, or T suffix."))
        }
        return issues
    }

    private static func memorySpec(_ bytes: UInt64) -> String {
        let gib = Double(bytes) / 1_073_741_824
        if gib >= 1, gib.rounded() == gib { return "\(Int(gib))G" }
        let mib = Double(bytes) / 1_048_576
        if mib >= 1, mib.rounded() == mib { return "\(Int(mib))M" }
        return String(bytes)
    }

    private static func parseMemoryBytes(_ spec: String) -> UInt64? {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let suffix = trimmed.last?.isLetter == true ? trimmed.last! : nil
        let numberPart = suffix == nil ? trimmed : String(trimmed.dropLast())
        guard let value = Double(numberPart), value > 0 else { return nil }
        let multiplier: Double
        switch suffix?.uppercased() {
        case nil: multiplier = 1
        case "K": multiplier = 1024
        case "M": multiplier = 1024 * 1024
        case "G": multiplier = 1024 * 1024 * 1024
        case "T": multiplier = 1024 * 1024 * 1024 * 1024
        default: return nil
        }
        return UInt64(value * multiplier)
    }
}
