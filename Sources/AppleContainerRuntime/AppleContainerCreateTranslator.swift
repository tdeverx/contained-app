import Foundation
import ContainedCore
import ContainedRuntime

public enum AppleContainerCreateTranslator {
    public static func preview(for request: ContainerCreateRequest) -> RuntimeCommandPreview {
        RuntimeCommandPreview(command: ContainerCommands.run(request))
    }

    public static func result(from data: Data, request: ContainerCreateRequest) -> ContainerCreateResult {
        let output = String(decoding: data, as: UTF8.self)
        let printedID = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last(where: { !$0.isEmpty })
        return ContainerCreateResult(id: request.effectiveName ?? printedID, output: output)
    }

    public static func composePlan(for project: ComposeProject,
                                   baseDirectory: URL?) -> RuntimeComposeImportPlan {
        let items = project.services.compactMap { service -> RuntimeComposeImportItem? in
            guard service.image != nil else { return nil }
            return RuntimeComposeImportItem(
                request: createRequest(for: service, projectName: project.name, baseDirectory: baseDirectory),
                healthCheck: healthCheck(for: service)
            )
        }
        return RuntimeComposeImportPlan(items: items, warnings: project.warnings)
    }

    public static func imageDefaults(for request: ContainerCreateRequest,
                                     in images: [ImageResource]) -> ContainerImageDefaults? {
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
        return ContainerImageDefaults(
            command: config.cmd ?? [],
            entrypoint: config.entrypoint ?? [],
            workingDirectory: config.workingDir,
            user: config.user,
            environment: (config.env ?? []).compactMap(keyValue)
        )
    }

    private static func createRequest(for service: ComposeService,
                                      projectName: String,
                                      baseDirectory: URL?) -> ContainerCreateRequest {
        var request = ContainerCreateRequest()
        request.runtimeKind = .appleContainer
        request.image = service.image ?? ""
        request.platform = service.platform ?? ""
        request.name = service.name
        request.command = splitCommand(service.command)
        request.entrypoint = service.entrypoint ?? ""
        request.detach = true
        request.interactive = service.interactive
        request.tty = service.tty
        request.restart = RestartPolicy(label: service.restart)
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
        request.labels.append(ContainerCreateKeyValue(key: "contained.stack", value: projectName))
        return request
    }

    private static func healthCheck(for service: ComposeService) -> HealthCheck? {
        guard let healthcheck = service.healthcheck else { return nil }
        return HealthCheck(command: healthcheck.test,
                           intervalSeconds: healthcheck.intervalSeconds,
                           retries: healthcheck.retries,
                           enabled: true)
    }

    private static func splitCommand(_ command: String?) -> [String] {
        guard let command else { return [] }
        return command.split(separator: " ").map(String.init)
    }

    private static func portMap(_ spec: String) -> ContainerCreatePort? {
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
        return ContainerCreatePort(hostPort: host, containerPort: container, proto: proto)
    }

    private static func volumeMap(_ spec: String, baseDirectory: URL?) -> ContainerCreateVolume? {
        let parts = spec.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count > 1 else { return nil }
        var source = parts.first ?? ""
        if let baseDirectory, source.hasPrefix("./") || source.hasPrefix("../") {
            source = baseDirectory.appending(path: source).standardizedFileURL.path
        }
        return ContainerCreateVolume(source: source,
                                     target: parts.count > 1 ? parts[1] : "",
                                     readOnly: parts.count > 2 && parts[2] == "ro")
    }

    private static func keyValue(_ entry: String) -> ContainerCreateKeyValue? {
        guard let eq = entry.firstIndex(of: "=") else { return nil }
        return ContainerCreateKeyValue(key: String(entry[..<eq]),
                                       value: String(entry[entry.index(after: eq)...]))
    }

    private static func matchingImage(for reference: String, in images: [ImageResource]) -> ImageResource? {
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
