import Foundation

enum DockerCreateTranslator {
    static func preview(for request: Core.Container.CreateRequest) -> Core.Command.Preview {
        Core.Command.Preview(command: DockerCommands.run(request))
    }

    static func result(from data: Data, request: Core.Container.CreateRequest) -> Core.Container.CreateResult {
        let output = String(decoding: data, as: UTF8.self)
        let printedID = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last(where: { !$0.isEmpty })
        return Core.Container.CreateResult(id: request.effectiveName ?? printedID, output: output)
    }

    static func composePlan(for project: Core.Compose.Project,
                            baseDirectory: URL?) -> Core.Compose.ImportPlan {
        let items = project.services.compactMap { service -> Core.Compose.ImportItem? in
            guard service.image != nil else { return nil }
            var document = Core.Schema.Document.containerCreate(from: createRequest(for: service,
                                                                                    projectName: project.name,
                                                                                    baseDirectory: baseDirectory))
            for path in document.values.keys where !(document.values[path] ?? .string("")).isEmpty {
                document.provenance.sources[path] = .compose
            }
            for (path, value) in service.preservedFields {
                document.values[path] = value
                document.provenance.sources[path] = .compose
            }
            return Core.Compose.ImportItem(document: document,
                                           healthCheck: healthCheck(for: service))
        }
        return Core.Compose.ImportPlan(items: items, warnings: project.warnings)
    }

    static func imageDefaults(for request: Core.Container.CreateRequest,
                              in images: [Core.Image.Resource]) -> Core.Container.ImageDefaults? {
        AppleContainerCreateTranslator.imageDefaults(for: request, in: images)
    }

    private static func createRequest(for service: Core.Compose.Service,
                                      projectName: String,
                                      baseDirectory: URL?) -> Core.Container.CreateRequest {
        var request = Core.Container.CreateRequest(runtimeKind: .docker)
        request.image = service.image ?? ""
        request.platform = service.platform ?? ""
        request.name = service.name
        request.command = splitCommand(service.command)
        request.entrypoint = service.entrypoint ?? ""
        request.detach = true
        request.interactive = service.interactive
        request.tty = service.tty
        request.restart = Core.Container.RestartPolicy(label: service.restart)
        request.cpus = service.cpus ?? ""
        request.memory = service.memory ?? ""
        request.readOnly = service.readOnly
        request.useInit = service.initProcess
        request.workingDir = service.workingDir ?? ""
        request.user = service.user ?? ""
        request.capAdd = service.capAdd
        request.capDrop = service.capDrop
        request.network = service.networkMode == "host" ? "host" : (service.network ?? "")
        request.dns = service.dns
        request.dnsSearch = service.dnsSearch
        request.dnsOption = service.dnsOptions
        request.tmpfs = service.tmpfs
        request.ulimits = service.ulimits
        request.ports = service.ports.compactMap(portMap)
        request.volumes = service.volumes.compactMap { volumeMap($0, baseDirectory: baseDirectory) }
        request.env = service.environment.compactMap(keyValue)
        request.envFiles = service.envFiles
        request.labels = service.labels.compactMap(keyValue)
        request.labels.append(Core.Container.KeyValue(key: "contained.stack", value: projectName))
        request.extraHosts = strings(from: service.preservedFields[.networkExtraHosts])
        request.hostname = string(from: service.preservedFields[.networkHostname])
        request.domainName = string(from: service.preservedFields[.networkDomainName])
        request.macAddress = string(from: service.preservedFields[.networkMacAddress])
        request.expose = strings(from: service.preservedFields[.networkExpose])
        request.pullPolicy = string(from: service.preservedFields[.imagePullPolicy])
        request.attachStreams = strings(from: service.preservedFields[.processAttachStreams])
        request.loggingDriver = string(from: service.preservedFields[.loggingDriver])
        request.loggingOptions = keyValues(from: service.preservedFields[.loggingOptions])
        request.labelFiles = strings(from: service.preservedFields[.metadataLabelFiles])
        request.stopSignal = string(from: service.preservedFields[.lifecycleStopSignal])
        request.stopGracePeriod = string(from: service.preservedFields[.lifecycleStopGracePeriod])
        request.devices = strings(from: service.preservedFields[.devices])
        request.gpus = string(from: service.preservedFields[.gpus])
        request.supplementalGroups = strings(from: service.preservedFields[.processSupplementalGroups])
        request.privileged = bool(from: service.preservedFields[.securityPrivileged])
        request.securityOptions = strings(from: service.preservedFields[.securityOptions])
        request.sysctls = keyValues(from: service.preservedFields[.kernelSysctls])
        request.cgroupNamespace = string(from: service.preservedFields[.namespaceCgroup])
        request.userNamespace = string(from: service.preservedFields[.namespaceUser])
        request.pidNamespace = string(from: service.preservedFields[.namespacePID])
        request.ipcNamespace = string(from: service.preservedFields[.namespaceIPC])
        request.utsNamespace = string(from: service.preservedFields[.namespaceUTS])
        request.cpuShares = string(from: service.preservedFields[.resourcesCPUShares])
        request.cpuQuota = string(from: service.preservedFields[.resourcesCPUQuota])
        request.cpuPeriod = string(from: service.preservedFields[.resourcesCPUPeriod])
        request.cpuSet = string(from: service.preservedFields[.resourcesCPUSet])
        request.cpuRealtimeRuntime = string(from: service.preservedFields[.resourcesCPURealtimeRuntime])
        request.cpuRealtimePeriod = string(from: service.preservedFields[.resourcesCPURealtimePeriod])
        request.memoryReservation = string(from: service.preservedFields[.resourcesMemoryReservation])
        request.memorySwapLimit = string(from: service.preservedFields[.resourcesMemorySwapLimit])
        request.memorySwappiness = string(from: service.preservedFields[.resourcesMemorySwappiness])
        request.oomKillDisable = bool(from: service.preservedFields[.resourcesOOMKillDisable])
        request.oomScoreAdjust = string(from: service.preservedFields[.resourcesOOMScoreAdjust])
        request.blockIOWeight = string(from: service.preservedFields[.resourcesBlockIO])
        request.storageOptions = keyValues(from: service.preservedFields[.storageOptions])
        request.volumesFrom = strings(from: service.preservedFields[.storageVolumesFrom])
        return request
    }

    private static func healthCheck(for service: Core.Compose.Service) -> Core.Container.HealthCheck? {
        guard let healthcheck = service.healthcheck else { return nil }
        return Core.Container.HealthCheck(command: healthcheck.test,
                                          intervalSeconds: healthcheck.intervalSeconds,
                                          retries: healthcheck.retries,
                                          enabled: true)
    }

    private static func splitCommand(_ command: String?) -> [String] {
        guard let command else { return [] }
        return command.split(separator: " ").map(String.init)
    }

    private static func portMap(_ spec: String) -> Core.Container.Port? {
        var raw = spec
        let proto: String
        if let slash = raw.lastIndex(of: "/") {
            proto = String(raw[raw.index(after: slash)...])
            raw = String(raw[..<slash])
        } else {
            proto = "tcp"
        }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return nil }
        let host = parts.dropLast().joined(separator: ":")
        let container = parts[parts.count - 1]
        guard !host.isEmpty, !container.isEmpty else { return nil }
        return Core.Container.Port(hostPort: host, containerPort: container, proto: proto)
    }

    private static func volumeMap(_ spec: String, baseDirectory: URL?) -> Core.Container.VolumeMount? {
        let parts = spec.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count > 1 else { return nil }
        var source = parts.first ?? ""
        if let baseDirectory, source.hasPrefix("./") || source.hasPrefix("../") {
            source = baseDirectory.appending(path: source).standardizedFileURL.path
        }
        return Core.Container.VolumeMount(source: source,
                                          target: parts.count > 1 ? parts[1] : "",
                                          readOnly: parts.count > 2 && parts[2] == "ro")
    }

    private static func keyValue(_ entry: String) -> Core.Container.KeyValue? {
        guard let eq = entry.firstIndex(of: "=") else { return nil }
        return Core.Container.KeyValue(key: String(entry[..<eq]),
                                       value: String(entry[entry.index(after: eq)...]))
    }

    private static func string(from value: Core.Schema.Value?) -> String {
        switch value {
        case .string(let value), .enumeration(let value): return value
        default: return ""
        }
    }

    private static func strings(from value: Core.Schema.Value?) -> [String] {
        switch value {
        case .stringList(let values), .commandLine(let values): return values
        default: return []
        }
    }

    private static func keyValues(from value: Core.Schema.Value?) -> [Core.Container.KeyValue] {
        if case .keyValueList(let values) = value { return values }
        return []
    }

    private static func bool(from value: Core.Schema.Value?) -> Bool {
        if case .bool(let value) = value { return value }
        return false
    }
}
