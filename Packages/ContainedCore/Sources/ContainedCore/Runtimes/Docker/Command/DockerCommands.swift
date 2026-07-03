import Foundation

/// Pure builders for Docker `docker` argument vectors.
enum DockerCommands {
    static let jsonTemplate = "{{json .}}"

    // MARK: Containers

    static func containerIDs(all: Bool) -> [String] {
        var args = ["container", "ls", "--no-trunc", "--quiet"]
        if all { args.insert("--all", at: 2) }
        return args
    }

    static func inspectContainers(_ ids: [String]) -> [String] {
        ["container", "inspect"] + ids
    }

    static func stats(ids: [String] = [], noStream: Bool = true) -> [String] {
        var args = ["stats"]
        if noStream { args.append("--no-stream") }
        args += ["--format", jsonTemplate]
        args += ids
        return args
    }

    static func start(_ ids: [String]) -> [String] { ["container", "start"] + ids }
    static func stop(_ ids: [String]) -> [String] { ["container", "stop"] + ids }
    static func deleteContainers(_ ids: [String], force: Bool) -> [String] {
        var args = ["container", "rm"]
        if force { args.append("--force") }
        return args + ids
    }
    static func containerPrune() -> [String] { ["container", "prune", "--force"] }
    static func exec(_ id: String, _ command: [String]) -> [String] {
        ["container", "exec", id] + command
    }
    static func execInteractive(_ id: String, shell: String) -> [String] {
        ["container", "exec", "--interactive", "--tty", id, shell]
    }
    static func containerExport(_ id: String, output: String) -> [String] {
        ["container", "export", "--output", output, id]
    }
    static func copy(source: String, destination: String) -> [String] {
        ["container", "cp", source, destination]
    }
    static func logs(_ id: String, follow: Bool = false, tail: Int? = nil) -> [String] {
        var args = ["container", "logs"]
        if follow { args.append("--follow") }
        if let tail { args += ["--tail", String(tail)] }
        args.append(id)
        return args
    }

    static func run(_ request: Core.Container.CreateRequest) -> [String] {
        var args = ["container", "run"]
        if request.detach { args.append("--detach") }
        if request.removeOnExit { args.append("--rm") }
        if request.interactive { args.append("--interactive") }
        if request.tty { args.append("--tty") }
        if !request.name.isEmpty { args += ["--name", request.name] }
        if !request.entrypoint.isEmpty { args += ["--entrypoint", request.entrypoint] }
        if !request.platform.isEmpty { args += ["--platform", request.platform] }
        if !request.cpus.isEmpty { args += ["--cpus", request.cpus] }
        if !request.memory.isEmpty { args += ["--memory", request.memory] }
        if !request.memoryReservation.isEmpty { args += ["--memory-reservation", request.memoryReservation] }
        if !request.memorySwapLimit.isEmpty { args += ["--memory-swap", request.memorySwapLimit] }
        if !request.memorySwappiness.isEmpty { args += ["--memory-swappiness", request.memorySwappiness] }
        if request.oomKillDisable { args.append("--oom-kill-disable") }
        if !request.oomScoreAdjust.isEmpty { args += ["--oom-score-adj", request.oomScoreAdjust] }
        if !request.cpuShares.isEmpty { args += ["--cpu-shares", request.cpuShares] }
        if !request.cpuQuota.isEmpty { args += ["--cpu-quota", request.cpuQuota] }
        if !request.cpuPeriod.isEmpty { args += ["--cpu-period", request.cpuPeriod] }
        if !request.cpuSet.isEmpty { args += ["--cpuset-cpus", request.cpuSet] }
        if !request.cpuRealtimeRuntime.isEmpty { args += ["--cpu-rt-runtime", request.cpuRealtimeRuntime] }
        if !request.cpuRealtimePeriod.isEmpty { args += ["--cpu-rt-period", request.cpuRealtimePeriod] }
        if !request.workingDir.isEmpty { args += ["--workdir", request.workingDir] }
        if !request.user.isEmpty { args += ["--user", request.user] }
        if !request.shmSize.isEmpty { args += ["--shm-size", request.shmSize] }
        if request.readOnly { args.append("--read-only") }
        if request.useInit { args.append("--init") }
        if request.privileged { args.append("--privileged") }
        if request.publishAll { args.append("--publish-all") }
        if !request.cidFile.isEmpty { args += ["--cidfile", request.cidFile] }
        if !request.pullPolicy.isEmpty { args += ["--pull", request.pullPolicy] }
        if !request.hostname.isEmpty { args += ["--hostname", request.hostname] }
        if !request.domainName.isEmpty { args += ["--domainname", request.domainName] }
        if !request.macAddress.isEmpty { args += ["--mac-address", request.macAddress] }
        if !request.network.isEmpty { args += ["--network", request.network] }
        if !request.runtime.isEmpty { args += ["--runtime", request.runtime] }
        if !request.stopSignal.isEmpty { args += ["--stop-signal", request.stopSignal] }
        if !request.stopGracePeriod.isEmpty { args += ["--stop-timeout", request.stopGracePeriod] }
        if !request.gpus.isEmpty { args += ["--gpus", request.gpus] }
        if !request.cgroupNamespace.isEmpty { args += ["--cgroupns", request.cgroupNamespace] }
        if !request.userNamespace.isEmpty { args += ["--userns", request.userNamespace] }
        if !request.pidNamespace.isEmpty { args += ["--pid", request.pidNamespace] }
        if !request.ipcNamespace.isEmpty { args += ["--ipc", request.ipcNamespace] }
        if !request.utsNamespace.isEmpty { args += ["--uts", request.utsNamespace] }
        if !request.blockIOWeight.isEmpty { args += ["--blkio-weight", request.blockIOWeight] }

        for stream in request.attachStreams where !stream.isEmpty { args += ["--attach", stream] }
        for host in request.extraHosts where !host.isEmpty { args += ["--add-host", host] }
        for port in request.expose where !port.isEmpty { args += ["--expose", port] }
        for port in request.ports where port.isValid { args += ["--publish", port.spec] }
        for volume in request.volumes where volume.isValid { args += ["--volume", volume.spec] }
        for mount in request.mounts where !mount.isEmpty { args += ["--mount", mount] }
        for volume in request.volumesFrom where !volume.isEmpty { args += ["--volumes-from", volume] }
        for mount in request.tmpfs where !mount.isEmpty { args += ["--tmpfs", mount] }
        for file in request.envFiles where !file.isEmpty { args += ["--env-file", file] }
        for variable in request.env where variable.isValid { args += ["--env", "\(variable.key)=\(variable.value)"] }
        for label in request.allLabelArguments() { args += ["--label", label] }
        for file in request.labelFiles where !file.isEmpty { args += ["--label-file", file] }
        for cap in request.capAdd where !cap.isEmpty { args += ["--cap-add", cap] }
        for cap in request.capDrop where !cap.isEmpty { args += ["--cap-drop", cap] }
        for group in request.supplementalGroups where !group.isEmpty { args += ["--group-add", group] }
        for option in request.securityOptions where !option.isEmpty { args += ["--security-opt", option] }
        for limit in request.ulimits where !limit.isEmpty { args += ["--ulimit", limit] }
        for server in request.dns where !server.isEmpty { args += ["--dns", server] }
        for domain in request.dnsSearch where !domain.isEmpty { args += ["--dns-search", domain] }
        for option in request.dnsOption where !option.isEmpty { args += ["--dns-option", option] }
        for entry in request.sysctls where entry.isValid { args += ["--sysctl", "\(entry.key)=\(entry.value)"] }
        for entry in request.storageOptions where entry.isValid { args += ["--storage-opt", "\(entry.key)=\(entry.value)"] }
        if !request.loggingDriver.isEmpty { args += ["--log-driver", request.loggingDriver] }
        for entry in request.loggingOptions where entry.isValid { args += ["--log-opt", "\(entry.key)=\(entry.value)"] }
        for device in request.devices where !device.isEmpty { args += ["--device", device] }

        args.append(request.image)
        args += request.command
        return args
    }

    // MARK: Images

    static func imageList() -> [String] {
        ["image", "ls", "--digests", "--no-trunc", "--format", jsonTemplate]
    }
    static func imageInspect(_ refs: [String]) -> [String] { ["image", "inspect"] + refs }
    static func imageDelete(_ refs: [String]) -> [String] { ["image", "rm"] + refs }
    static func imageTag(source: String, target: String) -> [String] { ["image", "tag", source, target] }
    static func imagePrune(all: Bool = false) -> [String] {
        var args = ["image", "prune", "--force"]
        if all { args.append("--all") }
        return args
    }
    static func imageSave(refs: [String], output: String) -> [String] {
        ["image", "save"] + refs + ["--output", output]
    }
    static func imageLoad(input: String) -> [String] { ["image", "load", "--input", input] }
    static func imagePull(_ ref: String, platform: String? = nil) -> [String] {
        var args = ["image", "pull"]
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(ref)
        return args
    }
    static func imagePush(_ ref: String, platform: String? = nil) -> [String] {
        var args = ["image", "push"]
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(ref)
        return args
    }

    // MARK: Build

    static func build(context: String, tag: String? = nil, dockerfile: String? = nil,
                      buildArgs: [String: String] = [:], noCache: Bool = false,
                      platform: String? = nil) -> [String] {
        var args = ["build", "--progress", "plain"]
        if let tag, !tag.isEmpty { args += ["--tag", tag] }
        if let dockerfile, !dockerfile.isEmpty { args += ["--file", dockerfile] }
        for (key, value) in buildArgs.sorted(by: { $0.key < $1.key }) {
            args += ["--build-arg", "\(key)=\(value)"]
        }
        if noCache { args.append("--no-cache") }
        if let platform, !platform.isEmpty { args += ["--platform", platform] }
        args.append(context)
        return args
    }

    // MARK: Infra

    static func networkList() -> [String] {
        ["network", "ls", "--no-trunc", "--format", jsonTemplate]
    }
    static func networkInspect(_ names: [String]) -> [String] { ["network", "inspect"] + names }
    static func networkCreate(name: String, subnet: String? = nil, internalOnly: Bool = false,
                              labels: [String: String] = [:]) -> [String] {
        var args = ["network", "create"]
        if internalOnly { args.append("--internal") }
        for (key, value) in labels.sorted(by: { $0.key < $1.key }) { args += ["--label", "\(key)=\(value)"] }
        if let subnet, !subnet.isEmpty { args += ["--subnet", subnet] }
        args.append(name)
        return args
    }
    static func networkDelete(_ names: [String]) -> [String] { ["network", "rm"] + names }
    static func networkPrune() -> [String] { ["network", "prune", "--force"] }

    static func volumeList() -> [String] {
        ["volume", "ls", "--format", jsonTemplate]
    }
    static func volumeInspect(_ names: [String]) -> [String] { ["volume", "inspect"] + names }
    static func volumeCreate(name: String, size: String? = nil, labels: [String: String] = [:]) -> [String] {
        var args = ["volume", "create"]
        for (key, value) in labels.sorted(by: { $0.key < $1.key }) { args += ["--label", "\(key)=\(value)"] }
        if let size, !size.isEmpty { args += ["--opt", "size=\(size)"] }
        args.append(name)
        return args
    }
    static func volumeDelete(_ names: [String]) -> [String] { ["volume", "rm"] + names }
    static func volumePrune() -> [String] { ["volume", "prune", "--force"] }

    // MARK: Registries / System

    static func registryLogin(server: String, username: String) -> [String] {
        ["login", "--username", username, "--password-stdin", server]
    }
    static func registryLogout(server: String) -> [String] { ["logout", server] }

    static let version = ["--version"]
    static let systemStatus = ["info", "--format", jsonTemplate]
    static let systemDF = ["system", "df", "--format", jsonTemplate]
}
