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
        spec.workingDir = "/app"
        spec.user = "1000:1000"
        spec.uid = "1000"
        spec.gid = "1000"
        spec.shmSize = "64M"
        spec.capAdd = ["CAP_NET_RAW", ""]      // empty entries skipped
        spec.capDrop = ["ALL"]
        spec.dns = ["1.1.1.1"]
        spec.dnsDomain = "example.com"
        spec.dnsSearch = ["svc.local"]
        spec.dnsOption = ["ndots:2"]
        spec.tmpfs = ["/tmp"]
        spec.ulimits = ["nofile=1024:2048"]
        let args = spec.arguments()
        #expect(subsequence(["--workdir", "/app"], in: args))
        #expect(subsequence(["--user", "1000:1000"], in: args))
        #expect(subsequence(["--uid", "1000"], in: args))
        #expect(subsequence(["--gid", "1000"], in: args))
        #expect(subsequence(["--shm-size", "64M"], in: args))
        #expect(subsequence(["--cap-add", "CAP_NET_RAW"], in: args))
        #expect(subsequence(["--cap-drop", "ALL"], in: args))
        #expect(subsequence(["--dns", "1.1.1.1"], in: args))
        #expect(subsequence(["--dns-domain", "example.com"], in: args))
        #expect(subsequence(["--dns-search", "svc.local"], in: args))
        #expect(subsequence(["--dns-option", "ndots:2"], in: args))
        #expect(subsequence(["--tmpfs", "/tmp"], in: args))
        #expect(subsequence(["--ulimit", "nofile=1024:2048"], in: args))
        #expect(args.filter { $0 == "--cap-add" }.count == 1)   // the empty cap was skipped
    }

    @Test func portsVolumesEnvAndLabelsArgv() {
        var spec = RunSpec()
        spec.image = "nginx"
        spec.ports = [PortMap(hostPort: "8080", containerPort: "80", proto: "tcp"),
                      PortMap(hostPort: "53", containerPort: "53", proto: "udp")]
        spec.volumes = [VolumeMap(source: "/data", target: "/var/lib", readOnly: true)]
        spec.env = [KeyValue(key: "KEY", value: "val")]
        spec.labels = [KeyValue(key: "team", value: "infra")]
        spec.restart = .onFailure
        let args = spec.arguments()
        #expect(subsequence(["--publish", "8080:80"], in: args))
        #expect(subsequence(["--publish", "53:53/udp"], in: args))
        #expect(subsequence(["--volume", "/data:/var/lib:ro"], in: args))
        #expect(subsequence(["--env", "KEY=val"], in: args))
        #expect(subsequence(["--label", "team=infra"], in: args))
        // restart policy round-trips through the contained.restart label, but personalization never does
        #expect(args.contains { $0.hasPrefix("contained.restart=") })
        #expect(!args.contains { $0.hasPrefix("contained.tint") || $0.hasPrefix("contained.icon") })
    }

    @Test func composeServiceMapping() {
        let service = ComposeService(
            key: "db", name: "db", image: "postgres:16", command: nil,
            ports: ["5432:5432"], volumes: ["pgdata:/var/lib/postgresql/data"],
            environment: ["POSTGRES_PASSWORD=secret"], restart: "always",
            dependsOn: [], healthcheck: ComposeHealthcheck(test: ["sh", "-c", "pg_isready"],
                                                           intervalSeconds: 10, retries: 5))
        let spec = RunSpec(service: service, projectName: "demo")
        #expect(spec.image == "postgres:16")
        #expect(spec.name == "db")
        #expect(spec.ports.first?.spec == "5432:5432")
        #expect(spec.restart == .always)
        #expect(spec.labels.contains { $0.key == "contained.stack" && $0.value == "demo" })
        #expect(spec.healthCheck.enabled)
        #expect(spec.healthCheck.command == ["sh", "-c", "pg_isready"])
        #expect(spec.healthCheck.retries == 5)
    }

    @Test func memoryParsingRoundTrips() {
        #expect(RunSpecForm.parseMemoryGB("1G") == 1)
        #expect(RunSpecForm.parseMemoryGB("512M") == 0.5)
        #expect(RunSpecForm.parseMemoryGB("2g") == 2)
        #expect(RunSpecForm.parseMemoryGB("") == nil)
        #expect(RunSpecForm.memorySpec(gb: 2) == "2G")
        #expect(RunSpecForm.memorySpec(gb: 1.5) == "1536M")
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

    /// True if `needle` appears as a contiguous run inside `haystack`.
    private func subsequence(_ needle: [String], in haystack: [String]) -> Bool {
        guard needle.count <= haystack.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<start + needle.count]) == needle { return true }
        }
        return false
    }
}
