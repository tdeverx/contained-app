import Foundation
import Testing
@testable import ContainedCore

@Suite("Decoding real CLI fixtures")
struct DecodingTests {

    @Test func placeholderSnapshotDecodes() {
        let s = Core.Container.Snapshot.placeholder(id: "nginx", image: "nginx:latest", runtimeKind: .appleContainer)
        #expect(s.id == "nginx")
        #expect(s.image == "nginx:latest")
        #expect(s.state == .running)
        let stopped = Core.Container.Snapshot.placeholder(id: "x", image: "redis:7", state: .stopped, runtimeKind: .appleContainer)
        #expect(stopped.state == .stopped)
        let quoted = Core.Container.Snapshot.placeholder(id: #"weird "id""#, image: #"repo/"quoted":tag"#, runtimeKind: .appleContainer)
        #expect(quoted.id == #"weird "id""#)
        #expect(quoted.image == #"repo/"quoted":tag"#)
    }

    @Test func decodesContainerList() throws {
        let snapshots = try Core.Container.JSON.decode([Core.Container.Snapshot].self,
                                                       from: try Fixture.data("list"),
                                                       runtimeKind: .appleContainer)
        try #require(snapshots.count == 1)
        let c = snapshots[0]
        #expect(c.id == "fixture-web")
        #expect(c.state == .running)
        #expect(c.image == "docker.io/library/alpine:latest")
        #expect(c.configuration.resources.cpus == 4)
        #expect(c.configuration.resources.memoryInBytes == 1_073_741_824)
        #expect(c.configuration.initProcess.environment.contains("FOO=bar"))
        #expect(c.configuration.publishedPorts.first?.hostPort == 18080)
        #expect(c.configuration.publishedPorts.first?.containerPort == 80)
        #expect(c.configuration.labels.isEmpty)
        #expect(c.startedDate != nil)
        #expect(c.status.networks.first?.ipv4Address == "192.168.64.3/24")
    }

    @Test func resourceDecodingRequiresRuntimeIdentityOrContext() throws {
        #expect(throws: DecodingError.self) {
            _ = try Core.Container.JSON.decode([Core.Container.Snapshot].self,
                                               from: try Fixture.data("list"))
        }
    }

    @Test func decodesMultiContainerListWithVirtiofsMounts() throws {
        // Live output can represent mount `type` as an enum-like object such as {"virtiofs":{}}.
        let snapshots = try Core.Container.JSON.decode([Core.Container.Snapshot].self,
                                                       from: try Fixture.data("list-current"),
                                                       runtimeKind: .appleContainer)
        #expect(snapshots.count == 4)
        let npm = try #require(snapshots.first { $0.id == "nginx-proxy-manager-latest" })
        #expect(npm.configuration.mounts.count == 2)
        #expect(npm.configuration.mounts.first?.type == "virtiofs")
        #expect(npm.configuration.mounts.first?.effectiveDestination == "/data")
    }

    @Test func decodesInspectMatchesList() throws {
        let inspected = try Core.Container.JSON.decode([Core.Container.Snapshot].self,
                                                       from: try Fixture.data("inspect"),
                                                       runtimeKind: .appleContainer)
        #expect(inspected.first?.id == "fixture-web")
        #expect(inspected.first?.configuration.platform.architecture == "arm64")
    }

    @Test func decodesStats() throws {
        let stats = try Core.Container.JSON.decode([Core.Metrics.ContainerStats].self, from: try Fixture.data("stats"))
        let s = try #require(stats.first)
        #expect(s.id == "fixture-web")
        #expect(s.memoryLimitBytes == 1_073_741_824)
        #expect(s.numProcesses == 1)
        #expect(s.cpuUsageUsec == 1827)
    }

    @Test func decodesDiskUsage() throws {
        let df = try Core.Container.JSON.decode(Core.System.DiskUsage.self, from: try Fixture.data("df"))
        #expect(df.images.total == 11)
        #expect(df.containers.total == 3)
        #expect(df.volumes.sizeInBytes == 0)
        #expect(df.totalSizeInBytes > 0)
    }

    @Test func decodesSystemStatus() throws {
        let status = try Core.Container.JSON.decode(Core.System.Status.self, from: try Fixture.data("status"))
        #expect(status.isRunning)
        #expect(status.apiServerVersion?.contains("1.0.0") == true)
    }

    @Test func decodesSystemPropertiesMachineResources() throws {
        let data = Data("""
        {
          "container": { "cpus": 4, "memory": "1gb" },
          "machine": { "cpus": 5, "memory": "8gb" },
          "build": { "cpus": 2, "memory": "2048mb" }
        }
        """.utf8)
        let properties = try Core.Container.JSON.decode(Core.System.Properties.self, from: data)

        #expect(properties.container?.cpus == 4)
        #expect(properties.container?.memory == "1gb")
        #expect(properties.machine?.cpus == 5)
        #expect(properties.machine?.memory == "8gb")
    }

    @Test func decodesNetworks() throws {
        let nets = try Core.Container.JSON.decode([Core.Network.Resource].self,
                                                  from: try Fixture.data("networks"),
                                                  runtimeKind: .appleContainer)
        let def = try #require(nets.first)
        #expect(def.name == "default")
        #expect(def.isBuiltin)
        #expect(def.status?.ipv4Subnet == "192.168.64.0/24")
    }

    @Test func decodesEmptyVolumes() throws {
        let vols = try Core.Container.JSON.decode([Core.Volume.Resource].self,
                                                  from: try Fixture.data("volumes"),
                                                  runtimeKind: .appleContainer)
        #expect(vols.isEmpty)
    }

    @Test func decodesMultiArchImage() throws {
        let images = try Core.Container.JSON.decode([Core.Image.Resource].self,
                                                    from: try Fixture.data("image-inspect"),
                                                    runtimeKind: .appleContainer)
        let img = try #require(images.first)
        #expect(img.reference == "docker.io/library/alpine:latest")
        #expect(img.variants.count > 1)
        // Real OS/arch variants are runnable; "unknown/unknown" attestation blobs are filtered out.
        let runnable = img.variants.filter(\.isRunnable)
        #expect(runnable.contains { $0.platform.architecture == "arm64" })
        #expect(runnable.allSatisfy { $0.platform.os == "linux" })
        // Snake_case / capitalized OCI keys decode.
        let arm64 = try #require(runnable.first { $0.platform.architecture == "arm64" })
        #expect(arm64.config?.config?.cmd == ["/bin/sh"])
        #expect(arm64.config?.rootfs?.diffIDs?.isEmpty == false)
    }

    @Test func decodesDockerContainerInspectToCoreSnapshot() throws {
        let data = Data("""
        [
          {
            "Id": "0123456789abcdef",
            "Image": "sha256:image-content-id",
            "Name": "/web",
            "Created": "2026-07-03T09:30:00Z",
            "Platform": "linux/arm64/v8",
            "Config": {
              "Image": "nginx:latest",
              "Cmd": ["nginx", "-g", "daemon off;"],
              "Entrypoint": null,
              "Env": ["FOO=bar"],
              "WorkingDir": "/app",
              "User": "1000",
              "Labels": {"contained.restart": "always"},
              "Tty": true
            },
            "State": {
              "Status": "running",
              "Running": true,
              "StartedAt": "2026-07-03T09:31:00Z"
            },
            "HostConfig": {
              "NetworkMode": "host",
              "PortBindings": {"80/tcp": [{"HostIp": "127.0.0.1", "HostPort": "8080"}]},
              "ReadonlyRootfs": true,
              "Init": true,
              "ShmSize": 67108864,
              "CapAdd": ["NET_ADMIN"],
              "CapDrop": ["MKNOD"],
              "Runtime": "runc"
            },
            "NetworkSettings": {
              "Networks": {
                "bridge": {
                  "IPAddress": "172.17.0.2",
                  "Gateway": "172.17.0.1",
                  "GlobalIPv6Address": "",
                  "MacAddress": "02:42:ac:11:00:02"
                }
              }
            },
            "Mounts": [
              {"Type": "bind", "Source": "/tmp/site", "Destination": "/usr/share/nginx/html", "RW": false}
            ]
          }
        ]
        """.utf8)

        let rows = try DockerJSON.decode([DockerContainerInspect].self, from: data)
        let row = try #require(rows.first)
        let snapshot = try row.coreSnapshot()

        #expect(snapshot.runtimeKind == .docker)
        #expect(snapshot.id == "web")
        #expect(snapshot.scopedID == "docker::web")
        #expect(snapshot.state == .running)
        #expect(snapshot.image == "nginx:latest")
        #expect(snapshot.configuration.image.descriptor?.digest == "sha256:image-content-id")
        #expect(snapshot.configuration.runtimeKind == .docker)
        #expect(snapshot.configuration.initProcess.arguments == ["nginx", "-g", "daemon off;"])
        #expect(snapshot.configuration.initProcess.environment == ["FOO=bar"])
        #expect(snapshot.configuration.platform.architecture == "arm64")
        #expect(snapshot.configuration.platform.variant == "v8")
        #expect(snapshot.configuration.publishedPorts.first?.hostPort == 8080)
        #expect(snapshot.configuration.mounts.first?.readonly == true)
        #expect(snapshot.configuration.capAdd == ["NET_ADMIN"])
        #expect(snapshot.configuration.capDrop == ["MKNOD"])
        #expect(snapshot.status.networks.first?.ipv4Address == "172.17.0.2")
    }

    @Test func decodesDockerImageListRows() throws {
        let data = Data("""
        {"Repository":"nginx","Tag":"latest","Digest":"sha256:abc","ID":"sha256:image"}
        {"Repository":"<none>","Tag":"<none>","Digest":"<none>","ID":"sha256:dangling"}
        """.utf8)

        let rows = try DockerJSON.decodeJSONLines(DockerImageListRow.self, from: data)
        let images = rows.compactMap { $0.coreImage() }

        #expect(images.count == 1)
        #expect(images.first?.reference == "nginx:latest")
        #expect(images.first?.digest == "sha256:abc")
        #expect(images.first?.runtimeKind == .docker)
    }

    @Test func handlesDatesWithAndWithoutFractionalSeconds() throws {
        #expect(Core.Container.JSON.parseDate("2026-06-24T10:16:58Z") != nil)
        #expect(Core.Container.JSON.parseDate("2026-06-16T00:01:29.967161902Z") != nil)
        #expect(Core.Container.JSON.parseDate("not-a-date") == nil)
    }

    @Test func unknownRuntimeStatusFallsBack() throws {
        let data = Data(#"{"state":"frobnicating","networks":[]}"#.utf8)
        let s = try Core.Container.JSON.decode(Core.Container.RuntimeState.self, from: data)
        #expect(s.state == .unknown)
        #expect(s.rawState == "frobnicating")
    }
}
