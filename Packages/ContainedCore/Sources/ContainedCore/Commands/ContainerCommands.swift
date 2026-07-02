import Foundation

/// Pure builders for `container` argument vectors. Kept side-effect-free so golden tests can assert
/// the exact argv each UI action produces ("Reveal CLI" reads from the same source of truth).
public enum ContainerCommands {
    static let jsonFormat = ["--format", "json"]

    public enum StatsFormat: String, Sendable {
        case json
        case table
        case toml
        case yaml
    }

    // MARK: Containers

    public static func list(all: Bool) -> [String] {
        var args = ["list"]
        if all { args.append("--all") }
        return args + jsonFormat
    }

    public static func stats(ids: [String] = [], noStream: Bool = true, format: StatsFormat = .json) -> [String] {
        var args = ["stats"]
        if noStream { args.append("--no-stream") }
        return args + ["--format", format.rawValue] + ids
    }

    public static func statsTableStream(ids: [String] = []) -> [String] {
        stats(ids: ids, noStream: false, format: .table)
    }

    public static func start(_ ids: [String]) -> [String] { ["start"] + ids }
    public static func stop(_ ids: [String], signal: String? = nil, time: Int? = nil) -> [String] {
        var args = ["stop"]
        if let signal { args += ["--signal", signal] }
        if let time { args += ["--time", String(time)] }
        return args + ids
    }
    public static func deleteContainers(_ ids: [String], force: Bool) -> [String] {
        var args = ["delete"]
        if force { args.append("--force") }
        return args + ids
    }
    /// `container prune` — remove all stopped containers.
    public static func containerPrune() -> [String] { ["prune"] }
    /// `container exec <id> <command...>` (no TTY) — for one-shot captures like `ps`, `ls`.
    public static func exec(_ id: String, _ command: [String]) -> [String] { ["exec", id] + command }
    /// `container export <id> --output <tar>` — export a container's filesystem as a tar archive.
    /// Note: this is a filesystem tarball, **not** an OCI image (the runtime has no `commit`).
    public static func containerExport(_ id: String, output: String) -> [String] {
        ["export", "--output", output, id]
    }
    /// `container copy <source> <destination>` — paths are `container-id:path` or local.
    public static func copy(source: String, destination: String) -> [String] { ["copy", source, destination] }
    public static func logs(_ id: String, follow: Bool = false, tail: Int? = nil, boot: Bool = false) -> [String] {
        var args = ["logs"]
        if follow { args.append("--follow") }
        if boot { args.append("--boot") }
        if let tail { args += ["-n", String(tail)] }
        args.append(id)
        return args
    }

    public static func run(_ request: ContainerCreateRequest) -> [String] {
        var args = ["run"]
        if request.detach { args.append("--detach") }
        if request.removeOnExit { args.append("--rm") }
        if request.interactive { args.append("--interactive") }
        if request.tty { args.append("--tty") }
        if !request.name.isEmpty { args += ["--name", request.name] }
        if !request.cpus.isEmpty { args += ["--cpus", request.cpus] }
        if !request.memory.isEmpty { args += ["--memory", request.memory] }
        if !request.entrypoint.isEmpty { args += ["--entrypoint", request.entrypoint] }
        if request.readOnly { args.append("--read-only") }
        if request.useInit { args.append("--init") }
        if request.rosetta { args.append("--rosetta") }
        if request.ssh { args.append("--ssh") }
        if request.virtualization { args.append("--virtualization") }
        if !request.platform.isEmpty { args += ["--platform", request.platform] }
        if !request.workingDir.isEmpty { args += ["--workdir", request.workingDir] }
        if !request.user.isEmpty { args += ["--user", request.user] }
        if !request.uid.isEmpty { args += ["--uid", request.uid] }
        if !request.gid.isEmpty { args += ["--gid", request.gid] }
        if !request.shmSize.isEmpty { args += ["--shm-size", request.shmSize] }
        for cap in request.capAdd where !cap.isEmpty { args += ["--cap-add", cap] }
        for cap in request.capDrop where !cap.isEmpty { args += ["--cap-drop", cap] }
        if !request.cidFile.isEmpty { args += ["--cidfile", request.cidFile] }
        if !request.initImage.isEmpty { args += ["--init-image", request.initImage] }
        if !request.kernel.isEmpty { args += ["--kernel", request.kernel] }
        if !request.network.isEmpty { args += ["--network", request.network] }
        if request.noDNS { args.append("--no-dns") }
        if !request.noDNS {
            for server in request.dns where !server.isEmpty { args += ["--dns", server] }
            if !request.dnsDomain.isEmpty { args += ["--dns-domain", request.dnsDomain] }
            for domain in request.dnsSearch where !domain.isEmpty { args += ["--dns-search", domain] }
            for option in request.dnsOption where !option.isEmpty { args += ["--dns-option", option] }
        }
        for mount in request.tmpfs where !mount.isEmpty { args += ["--tmpfs", mount] }
        for limit in request.ulimits where !limit.isEmpty { args += ["--ulimit", limit] }
        if !request.runtime.isEmpty { args += ["--runtime", request.runtime] }
        if !request.scheme.isEmpty { args += ["--scheme", request.scheme] }
        if !request.progress.isEmpty { args += ["--progress", request.progress] }
        if !request.maxConcurrentDownloads.isEmpty {
            args += ["--max-concurrent-downloads", request.maxConcurrentDownloads]
        }
        for port in request.ports where port.isValid { args += ["--publish", port.spec] }
        for volume in request.volumes where volume.isValid { args += ["--volume", volume.spec] }
        for mount in request.mounts where !mount.isEmpty { args += ["--mount", mount] }
        for socket in request.sockets where socket.isValid { args += ["--publish-socket", socket.spec] }
        for file in request.envFiles where !file.isEmpty { args += ["--env-file", file] }
        for variable in request.env where variable.isValid { args += ["--env", "\(variable.key)=\(variable.value)"] }
        for label in request.allLabelArguments() { args += ["--label", label] }
        args.append(request.image)
        args += request.command
        return args
    }

    // MARK: Images

    public static func imageList() -> [String] { ["image", "list"] + jsonFormat }
    public static func imageInspect(_ refs: [String]) -> [String] { ["image", "inspect"] + refs }
    public static func imageDelete(_ refs: [String]) -> [String] { ["image", "delete"] + refs }
    public static func imageTag(source: String, target: String) -> [String] { ["image", "tag", source, target] }
    public static func imagePrune(all: Bool = false) -> [String] {
        var args = ["image", "prune"]
        if all { args.append("--all") }
        return args
    }
    /// `image save <refs...> -o <tar>` — export image(s) to an OCI archive.
    public static func imageSave(refs: [String], output: String) -> [String] {
        ["image", "save"] + refs + ["--output", output]
    }
    /// `image load -i <tar>` — import images from an archive.
    public static func imageLoad(input: String) -> [String] {
        ["image", "load", "--input", input]
    }

    /// `image pull [--platform os/arch] --progress plain <ref>` — plain progress is line-streamable.
    public static func imagePull(_ ref: String, platform: String? = nil) -> [String] {
        var args = ["image", "pull", "--progress", "plain"]
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(ref)
        return args
    }

    // MARK: Build

    /// `container build [-f Dockerfile] [-t tag] [--build-arg k=v] [--no-cache] [--platform p]
    /// --progress plain <context>` — plain progress streams the BuildKit log line by line.
    public static func build(context: String, tag: String? = nil, dockerfile: String? = nil,
                             buildArgs: [String: String] = [:], noCache: Bool = false,
                             platform: String? = nil) -> [String] {
        var args = ["build", "--progress", "plain"]
        if let tag, !tag.isEmpty { args += ["--tag", tag] }
        if let dockerfile, !dockerfile.isEmpty { args += ["--file", dockerfile] }
        for (k, v) in buildArgs.sorted(by: { $0.key < $1.key }) { args += ["--build-arg", "\(k)=\(v)"] }
        if noCache { args.append("--no-cache") }
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(context)
        return args
    }

    // MARK: Infra

    public static func networkList() -> [String] { ["network", "list"] + jsonFormat }
    public static func volumeList() -> [String] { ["volume", "list"] + jsonFormat }

    /// `volume create [--label k=v ...] [-s size] <name>`
    public static func volumeCreate(name: String, size: String? = nil, labels: [String: String] = [:]) -> [String] {
        var args = ["volume", "create"]
        for (k, v) in labels.sorted(by: { $0.key < $1.key }) { args += ["--label", "\(k)=\(v)"] }
        if let size, !size.isEmpty { args += ["-s", size] }
        args.append(name)
        return args
    }
    /// `volume delete <names...>`
    public static func volumeDelete(_ names: [String]) -> [String] { ["volume", "delete"] + names }
    public static func volumePrune() -> [String] { ["volume", "prune"] }

    /// `network create [--internal] [--label k=v ...] [--subnet <cidr>] <name>`
    public static func networkCreate(name: String, subnet: String? = nil, internalOnly: Bool = false,
                                     labels: [String: String] = [:]) -> [String] {
        var args = ["network", "create"]
        if internalOnly { args.append("--internal") }
        for (k, v) in labels.sorted(by: { $0.key < $1.key }) { args += ["--label", "\(k)=\(v)"] }
        if let subnet, !subnet.isEmpty { args += ["--subnet", subnet] }
        args.append(name)
        return args
    }
    /// `network delete <names...>`
    public static func networkDelete(_ names: [String]) -> [String] { ["network", "delete"] + names }
    public static func networkPrune() -> [String] { ["network", "prune"] }

    /// `image push [--platform p] --progress plain <ref>` — streamable push to a logged-in registry.
    public static func imagePush(_ ref: String, platform: String? = nil) -> [String] {
        var args = ["image", "push", "--progress", "plain"]
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(ref)
        return args
    }

    // MARK: Registries

    public static func registryList() -> [String] { ["registry", "list"] + jsonFormat }
    /// `registry login --username <user> --password-stdin <server>` — password is piped via stdin.
    public static func registryLogin(server: String, username: String) -> [String] {
        ["registry", "login", "--username", username, "--password-stdin", server]
    }
    public static func registryLogout(server: String) -> [String] { ["registry", "logout", server] }

    // MARK: System

    public static let systemStatus = ["system", "status"] + jsonFormat
    public static let systemDF = ["system", "df"] + jsonFormat
    public static let systemPropertyList = ["system", "property", "list"] + jsonFormat
    public static let version = ["--version"]
    /// `system logs [--follow] [--last N]` — service logs (plain text, not JSON).
    public static func systemLogs(follow: Bool = false, last: Int? = nil) -> [String] {
        var args = ["system", "logs"]
        if follow { args.append("--follow") }
        if let last { args += ["--last", String(last)] }
        return args
    }

    // MARK: System — kernel & DNS (privileged; may trigger a system sudo prompt handled by the CLI)

    public static let systemDNSList = ["system", "dns", "list"] + jsonFormat
    /// `system dns create <domain>` — must run as administrator (the CLI prompts).
    public static func systemDNSCreate(_ domain: String) -> [String] { ["system", "dns", "create", domain] }
    /// `system dns delete <domain>` — must run as administrator (the CLI prompts).
    public static func systemDNSDelete(_ domain: String) -> [String] { ["system", "dns", "delete", domain] }
    /// `system kernel set --recommended` — download + install the recommended kernel.
    public static let systemKernelSetRecommended = ["system", "kernel", "set", "--recommended"]
}
