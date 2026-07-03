import Foundation

enum AppleContainerCreateTranslator {
    static func preview(for request: Core.Container.CreateRequest) -> Core.Command.Preview {
        Core.Command.Preview(command: ContainerCommands.run(request))
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
            var document = Core.Schema.Document.containerCreate(from: createRequest(for: service, projectName: project.name, baseDirectory: baseDirectory))
            for path in document.values.keys
                where !(document.values[path] ?? .string("")).isEmpty {
                document.provenance.sources[path] = .compose
            }
            for (path, value) in service.preservedFields {
                document.values[path] = value
                document.provenance.sources[path] = .compose
            }
            return Core.Compose.ImportItem(
                document: document,
                healthCheck: healthCheck(for: service)
            )
        }
        return Core.Compose.ImportPlan(items: items, warnings: project.warnings)
    }

    static func imageDefaults(for request: Core.Container.CreateRequest,
                                     in images: [Core.Image.Resource]) -> Core.Container.ImageDefaults? {
        guard let image = matchingImage(for: request.image, in: images) else { return nil }
        let runnable = image.variants.filter(\.isRunnable)
        let platformMatch = runnable.first { variant in
            !request.platform.isEmpty && variant.platform.display == request.platform
        }
        #if arch(arm64)
        let hostMatch = runnable.first { $0.platform.os == "linux" && $0.platform.architecture == "arm64" }
        #else
        let hostMatch = runnable.first { $0.platform.os == "linux" && $0.platform.architecture == "amd64" }
        #endif
        guard let config = (platformMatch ?? hostMatch ?? runnable.first)?.config?.config else { return nil }
        return Core.Container.ImageDefaults(
            command: config.cmd ?? [],
            entrypoint: config.entrypoint ?? [],
            workingDirectory: config.workingDir,
            user: config.user,
            environment: (config.env ?? []).compactMap(keyValue)
        )
    }

    private static func createRequest(for service: Core.Compose.Service,
                                      projectName: String,
                                      baseDirectory: URL?) -> Core.Container.CreateRequest {
        var request = Core.Container.CreateRequest()
        request.runtimeKind = .appleContainer
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
        request.network = service.network ?? ""
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

    private static func matchingImage(for reference: String, in images: [Core.Image.Resource]) -> Core.Image.Resource? {
        let target = normalizedImageReference(reference)
        return images.first { normalizedImageReference($0.reference) == target }
    }

    private static func normalizedImageReference(_ reference: String) -> String {
        let short = shortImage(reference.trimmingCharacters(in: .whitespaces))
        let nameStart = short.lastIndex(of: "/").map { short.index(after: $0) } ?? short.startIndex
        let namePart = short[nameStart...]
        if namePart.contains(":") || namePart.contains("@") { return short }
        return short + ":latest"
    }

    private static func shortImage(_ reference: String) -> String {
        let prefixes = ["docker.io/library/", "docker.io/"]
        return prefixes.reduce(reference) { value, prefix in
            value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
        }
    }
}
