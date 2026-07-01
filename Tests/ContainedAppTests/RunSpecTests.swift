import Foundation
import Testing
import ContainedCore
@testable import Contained

@Suite("RunSpec argv + compose mapping")
@MainActor
struct RunSpecTests {

    @Test func basicArgv() {
        var spec = RunSpec()
        spec.image = "nginx:latest"
        #expect(spec.arguments() == ["run", "--detach", "nginx:latest"])
    }

    @Test func coreFlagsArgv() {
        var spec = RunSpec()
        spec.image = "alpine"
        spec.name = "web"
        spec.detach = false
        spec.removeOnExit = true
        spec.cpus = "2"
        spec.memory = "1G"
        spec.entrypoint = "/bin/sh"
        spec.readOnly = true
        spec.useInit = true
        spec.command = "echo hi"
        let args = spec.arguments()
        #expect(args.prefix(2) == ["run", "--rm"])
        #expect(args.contains(["--name", "web"].joined()) == false)   // sanity: not joined
        #expect(subsequence(["--name", "web"], in: args))
        #expect(subsequence(["--cpus", "2"], in: args))
        #expect(subsequence(["--memory", "1G"], in: args))
        #expect(subsequence(["--entrypoint", "/bin/sh"], in: args))
        #expect(args.contains("--read-only"))
        #expect(args.contains("--init"))
        #expect(!args.contains("--detach"))
        #expect(args.suffix(3) == ["alpine", "echo", "hi"])
    }

    @Test func advancedFlagsArgv() {
        var spec = RunSpec()
        spec.image = "alpine"
        spec.interactive = true
        spec.tty = true
        spec.workingDir = "/app"
        spec.user = "1000:1000"
        spec.uid = "1000"
        spec.gid = "1000"
        spec.shmSize = "64M"
        spec.capAdd = ["CAP_NET_RAW", ""]      // empty entries skipped
        spec.capDrop = ["ALL"]
        spec.cidFile = "/tmp/container.cid"
        spec.initImage = "init:latest"
        spec.kernel = "/kernels/vmlinux"
        spec.network = "media,mtu=1280"
        spec.noDNS = true
        spec.dns = ["1.1.1.1"]
        spec.dnsDomain = "example.com"
        spec.dnsSearch = ["svc.local"]
        spec.dnsOption = ["ndots:2"]
        spec.mounts = ["type=bind,source=/host,target=/guest,readonly"]
        spec.tmpfs = ["/tmp"]
        spec.ulimits = ["nofile=1024:2048"]
        spec.envFiles = ["/tmp/app.env"]
        spec.runtime = "container-runtime-linux"
        spec.scheme = "https"
        spec.progress = "plain"
        spec.maxConcurrentDownloads = "2"
        let args = spec.arguments()
        #expect(args.contains("--interactive"))
        #expect(args.contains("--tty"))
        #expect(subsequence(["--workdir", "/app"], in: args))
        #expect(subsequence(["--user", "1000:1000"], in: args))
        #expect(subsequence(["--uid", "1000"], in: args))
        #expect(subsequence(["--gid", "1000"], in: args))
        #expect(subsequence(["--shm-size", "64M"], in: args))
        #expect(subsequence(["--cap-add", "CAP_NET_RAW"], in: args))
        #expect(subsequence(["--cap-drop", "ALL"], in: args))
        #expect(subsequence(["--cidfile", "/tmp/container.cid"], in: args))
        #expect(subsequence(["--init-image", "init:latest"], in: args))
        #expect(subsequence(["--kernel", "/kernels/vmlinux"], in: args))
        #expect(subsequence(["--network", "media,mtu=1280"], in: args))
        #expect(args.contains("--no-dns"))
        #expect(!args.contains("--dns"))
        #expect(!args.contains("--dns-domain"))
        #expect(!args.contains("--dns-search"))
        #expect(!args.contains("--dns-option"))
        #expect(subsequence(["--mount", "type=bind,source=/host,target=/guest,readonly"], in: args))
        #expect(subsequence(["--tmpfs", "/tmp"], in: args))
        #expect(subsequence(["--ulimit", "nofile=1024:2048"], in: args))
        #expect(subsequence(["--env-file", "/tmp/app.env"], in: args))
        #expect(subsequence(["--runtime", "container-runtime-linux"], in: args))
        #expect(subsequence(["--scheme", "https"], in: args))
        #expect(subsequence(["--progress", "plain"], in: args))
        #expect(subsequence(["--max-concurrent-downloads", "2"], in: args))
        #expect(args.filter { $0 == "--cap-add" }.count == 1)   // the empty cap was skipped
    }

    @Test func portsVolumesEnvAndLabelsArgv() {
        var spec = RunSpec()
        spec.image = "nginx"
        spec.ports = [PortMap(hostPort: "8080", containerPort: "80", proto: "tcp"),
                      PortMap(hostPort: "53", containerPort: "53", proto: "udp")]
        spec.volumes = [VolumeMap(source: "/data", target: "/var/lib", readOnly: true)]
        spec.sockets = [SocketMap(hostPath: "/tmp/app.sock", containerPath: "/run/app.sock")]
        spec.env = [KeyValue(key: "KEY", value: "val")]
        spec.labels = [KeyValue(key: "team", value: "infra")]
        spec.restart = .onFailure
        let args = spec.arguments()
        #expect(subsequence(["--publish", "8080:80"], in: args))
        #expect(subsequence(["--publish", "53:53/udp"], in: args))
        #expect(subsequence(["--volume", "/data:/var/lib:ro"], in: args))
        #expect(subsequence(["--publish-socket", "/tmp/app.sock:/run/app.sock"], in: args))
        #expect(subsequence(["--env", "KEY=val"], in: args))
        #expect(subsequence(["--label", "team=infra"], in: args))
        // restart policy round-trips through the contained.restart label, but personalization never does
        #expect(args.contains { $0.hasPrefix("contained.restart=") })
        #expect(!args.contains { $0.hasPrefix("contained.tint") || $0.hasPrefix("contained.icon") })
    }

    @Test func composeServiceMapping() {
        let service = ComposeService(
            key: "db", name: "db", image: "postgres:16", platform: "linux/arm64", command: nil,
            ports: ["5432:5432"], volumes: ["pgdata:/var/lib/postgresql/data"],
            environment: ["POSTGRES_PASSWORD=secret"], restart: "always",
            dependsOn: [], healthcheck: ComposeHealthcheck(test: ["sh", "-c", "pg_isready"],
                                                           intervalSeconds: 10, retries: 5))
        let spec = RunSpec(service: service, projectName: "demo")
        #expect(spec.image == "postgres:16")
        #expect(spec.platform == "linux/arm64")
        #expect(spec.name == "db")
        #expect(spec.ports.first?.spec == "5432:5432")
        #expect(subsequence(["--platform", "linux/arm64"], in: spec.arguments()))
        #expect(spec.restart == .always)
        #expect(spec.labels.contains { $0.key == "contained.stack" && $0.value == "demo" })
        #expect(spec.healthCheck.enabled)
        #expect(spec.healthCheck.command == ["sh", "-c", "pg_isready"])
        #expect(spec.healthCheck.retries == 5)
    }

    @Test func composeImportResolvesRelativeBindMountsFromComposeDirectory() {
        let volume = VolumeMap(source: "../configs/bazarr", target: "/config")
        let base = URL(filePath: "/Volumes/Vault/.Docker/compose", directoryHint: .isDirectory)
        let resolved = ComposeImport.resolveRelativeVolume(volume, baseDirectory: base)

        #expect(resolved.source == "/Volumes/Vault/.Docker/configs/bazarr")
        #expect(resolved.target == "/config")
        #expect(!resolved.readOnly)
    }

    @Test func composeImportMapsAvailableRunOptions() throws {
        let yaml = """
        services:
          app:
            container_name: demo-app
            image: example/app:1
            platform: linux/arm64
            command: ["serve", "--port", "8080"]
            entrypoint: ["/bin/app"]
            working_dir: /srv/app
            user: "1000:1000"
            cpus: 2
            mem_limit: 512M
            ports:
              - target: 8080
                published: 18080
                host_ip: 127.0.0.1
                protocol: tcp
              - "15353:53/udp"
              - "8081"
            volumes:
              - type: bind
                source: ./config
                target: /config
                read_only: true
              - "cache:/cache"
            environment:
              TZ: Europe/London
              DEBUG: false
            env_file:
              - ./app.env
            labels:
              com.example.role: media
            restart: unless-stopped
            network_mode: host
            read_only: true
            init: true
            stdin_open: true
            tty: true
            cap_add: [CAP_NET_RAW]
            cap_drop: [ALL]
            dns: 1.1.1.1
            dns_search: [home.arpa]
            dns_opt: [ndots:2]
            tmpfs: [/tmp]
            ulimits:
              nofile:
                soft: 1024
                hard: 2048
            healthcheck:
              test: ["CMD", "curl", "-f", "http://localhost:8080"]
              interval: 30s
              retries: 3
        """

        let project = try ComposeParser.parse(yaml, projectName: "demo")
        let service = try #require(project.services.first)
        var spec = RunSpec(service: service, projectName: project.name)
        spec.volumes = spec.volumes.map {
            ComposeImport.resolveRelativeVolume($0, baseDirectory: URL(filePath: "/opt/stacks/demo", directoryHint: .isDirectory))
        }
        let args = spec.arguments()

        #expect(spec.image == "example/app:1")
        #expect(spec.platform == "linux/arm64")
        #expect(spec.name == "demo-app")
        #expect(spec.command == "serve --port 8080")
        #expect(spec.entrypoint == "/bin/app")
        #expect(spec.workingDir == "/srv/app")
        #expect(spec.user == "1000:1000")
        #expect(spec.cpus == "2")
        #expect(spec.memory == "512M")
        #expect(spec.restart == .always)
        #expect(spec.network.isEmpty)
        #expect(spec.interactive)
        #expect(spec.tty)
        #expect(spec.readOnly)
        #expect(spec.useInit)
        #expect(spec.capAdd == ["CAP_NET_RAW"])
        #expect(spec.capDrop == ["ALL"])
        #expect(spec.dns == ["1.1.1.1"])
        #expect(spec.dnsSearch == ["home.arpa"])
        #expect(spec.dnsOption == ["ndots:2"])
        #expect(spec.tmpfs == ["/tmp"])
        #expect(spec.ulimits == ["nofile=1024:2048"])
        #expect(spec.envFiles == ["./app.env"])
        #expect(spec.env.contains { $0.key == "TZ" && $0.value == "Europe/London" })
        #expect(spec.env.contains { $0.key == "DEBUG" && $0.value == "false" })
        #expect(spec.labels.contains { $0.key == "com.example.role" && $0.value == "media" })
        #expect(spec.labels.contains { $0.key == "contained.stack" && $0.value == "demo" })
        #expect(spec.ports.map(\.spec).sorted() == ["127.0.0.1:18080:8080", "15353:53/udp"])
        #expect(spec.volumes.map(\.spec).sorted() == ["/opt/stacks/demo/config:/config:ro", "cache:/cache"])
        #expect(spec.healthCheck.enabled)
        #expect(spec.healthCheck.command == ["curl", "-f", "http://localhost:8080"])
        #expect(project.warnings.contains { $0.contains("8081") && $0.contains("no host port") })

        #expect(subsequence(["--platform", "linux/arm64"], in: args))
        #expect(subsequence(["--entrypoint", "/bin/app"], in: args))
        #expect(subsequence(["--workdir", "/srv/app"], in: args))
        #expect(subsequence(["--cpus", "2"], in: args))
        #expect(subsequence(["--memory", "512M"], in: args))
        #expect(subsequence(["--cap-add", "CAP_NET_RAW"], in: args))
        #expect(!args.contains("--network"))
        #expect(args.contains("--interactive"))
        #expect(args.contains("--tty"))
        #expect(subsequence(["--dns", "1.1.1.1"], in: args))
        #expect(subsequence(["--env-file", "./app.env"], in: args))
        #expect(subsequence(["--ulimit", "nofile=1024:2048"], in: args))
        #expect(subsequence(["example/app:1", "serve", "--port", "8080"], in: args))
    }

    @Test func memoryParsingRoundTrips() {
        #expect(RunSpecForm.parseMemoryGB("1G") == 1)
        #expect(RunSpecForm.parseMemoryGB("512M") == 0.5)
        #expect(RunSpecForm.parseMemoryGB("2g") == 2)
        #expect(RunSpecForm.parseMemoryGB("") == nil)
        #expect(RunSpecForm.memorySpec(gb: 2) == "2G")
        #expect(RunSpecForm.memorySpec(gb: 1.5) == "1536M")
    }

    @Test func adoptsPulledImageDefaultsIntoEmptyRunFields() throws {
        let data = try Data(contentsOf: fixturesURL.appending(path: "image-inspect.json"))
        let images = try ContainerJSON.decode([ImageResource].self, from: data)
        var spec = RunSpec()
        spec.image = "alpine"

        let defaults = try #require(spec.imageDefaults(in: images))
        let applied = spec.adoptImageDefaults(from: defaults)

        #expect(applied >= 3)
        #expect(spec.command == "/bin/sh")
        #expect(spec.workingDir == "/")
        #expect(spec.env.contains { $0.key == "PATH" && !$0.value.isEmpty })
        #expect(spec.hasGeneralOptions)
        #expect(spec.hasEnvironmentOptions)
        #expect(spec.hasAdvancedOptions)
    }

    @Test func adoptingImageDefaultsDoesNotOverwriteExistingEdits() throws {
        let data = try Data(contentsOf: fixturesURL.appending(path: "image-inspect.json"))
        let images = try ContainerJSON.decode([ImageResource].self, from: data)
        var spec = RunSpec()
        spec.image = "alpine"
        spec.command = "custom"
        spec.workingDir = "/app"
        spec.env = [KeyValue(key: "PATH", value: "/custom")]

        let defaults = try #require(spec.imageDefaults(in: images))
        _ = spec.adoptImageDefaults(from: defaults)

        #expect(spec.command == "custom")
        #expect(spec.workingDir == "/app")
        #expect(spec.env.filter { $0.key == "PATH" }.map(\.value) == ["/custom"])
    }

    @Test func runSpecIsCodable() throws {
        var spec = RunSpec()
        spec.image = "redis:7"
        spec.ports = [PortMap(hostPort: "6379", containerPort: "6379", proto: "tcp")]
        spec.capAdd = ["CAP_NET_RAW"]
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(RunSpec.self, from: data)
        #expect(decoded.arguments() == spec.arguments())
    }

    @Test func editPrefillRestoresAdvancedContainerConfiguration() throws {
        let json = """
        {
          "id": "edited",
          "status": { "state": "running" },
          "configuration": {
            "id": "edited",
            "image": { "reference": "example/app:1" },
            "platform": { "os": "linux", "architecture": "amd64", "variant": "v2" },
            "initProcess": {
              "executable": "/entrypoint.sh",
              "arguments": ["serve"],
              "environment": ["KEY=value"],
              "workingDirectory": "/srv",
              "terminal": true
            },
            "resources": { "cpus": 2, "memoryInBytes": 536870912 },
            "labels": { "team": "infra", "contained.restart": "always" },
            "publishedPorts": [
              { "hostAddress": "127.0.0.1", "hostPort": 18080, "containerPort": 8080, "proto": "tcp" }
            ],
            "publishedSockets": [
              { "hostPath": "/tmp/app.sock", "containerPath": "/run/app.sock" }
            ],
            "mounts": [
              { "source": "/host/config", "destination": "/config", "readonly": true }
            ],
            "networks": [
              { "network": "media" }
            ],
            "dns": {
              "nameservers": ["1.1.1.1"],
              "searchDomains": ["home.arpa"],
              "options": ["ndots:2"],
              "domain": "example.test"
            },
            "capAdd": ["CAP_NET_RAW"],
            "capDrop": ["ALL"],
            "readOnly": true,
            "useInit": true,
            "rosetta": true,
            "ssh": true,
            "virtualization": true,
            "shmSize": 67108864,
            "runtimeHandler": "custom-runtime"
          }
        }
        """
        let snapshot = try JSONDecoder().decode(ContainerSnapshot.self, from: Data(json.utf8))
        let spec = RunSpec(from: snapshot.configuration)

        #expect(spec.image == "example/app:1")
        #expect(spec.platform == "linux/amd64/v2")
        #expect(spec.entrypoint.isEmpty)
        #expect(spec.command == "serve")
        #expect(spec.tty)
        #expect(spec.memory == "512M")
        #expect(spec.shmSize == "64M")
        #expect(spec.network == "media")
        #expect(spec.dns == ["1.1.1.1"])
        #expect(spec.dnsDomain == "example.test")
        #expect(spec.dnsSearch == ["home.arpa"])
        #expect(spec.dnsOption == ["ndots:2"])
        #expect(spec.capAdd == ["CAP_NET_RAW"])
        #expect(spec.capDrop == ["ALL"])
        #expect(spec.runtime == "custom-runtime")
        #expect(spec.ports.first?.spec == "127.0.0.1:18080:8080")
        #expect(spec.sockets.first?.spec == "/tmp/app.sock:/run/app.sock")
        #expect(spec.labels.contains { $0.key == "team" && $0.value == "infra" })
        #expect(spec.restart == .always)
        #expect(spec.readOnly && spec.useInit && spec.rosetta && spec.ssh && spec.virtualization)
    }

    /// True if `needle` appears as a contiguous run inside `haystack`.
    private func subsequence(_ needle: [String], in haystack: [String]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<start + needle.count]) == needle { return true }
        }
        return false
    }

    private var fixturesURL: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "ContainedCoreTests/Fixtures", directoryHint: .isDirectory)
    }
}
