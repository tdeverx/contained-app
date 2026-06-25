import Foundation
import Testing
@testable import ContainedCore

@Suite("Decoding real CLI fixtures")
struct DecodingTests {

    @Test func decodesContainerList() throws {
        let snapshots = try ContainerJSON.decode([ContainerSnapshot].self, from: try Fixture.data("list"))
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
        // Personalization labels round-trip through the CLI.
        #expect(c.tintLabel == "teal")
        #expect(c.iconLabel == "globe")
        #expect(c.startedDate != nil)
        #expect(c.status.networks.first?.ipv4Address == "192.168.64.3/24")
    }

    @Test func decodesMultiContainerListWithVirtiofsMounts() throws {
        // Live output with pre-existing containers exposed an enum-as-object mount `type`
        // ({"virtiofs":{}}) that the initial String model couldn't decode.
        let snapshots = try ContainerJSON.decode([ContainerSnapshot].self, from: try Fixture.data("list-current"))
        #expect(snapshots.count == 4)
        let npm = try #require(snapshots.first { $0.id == "nginx-proxy-manager-latest" })
        #expect(npm.configuration.mounts.count == 2)
        #expect(npm.configuration.mounts.first?.type == "virtiofs")
        #expect(npm.configuration.mounts.first?.effectiveDestination == "/data")
    }

    @Test func decodesInspectMatchesList() throws {
        let inspected = try ContainerJSON.decode([ContainerSnapshot].self, from: try Fixture.data("inspect"))
        #expect(inspected.first?.id == "fixture-web")
        #expect(inspected.first?.configuration.platform.architecture == "arm64")
    }

    @Test func decodesStats() throws {
        let stats = try ContainerJSON.decode([ContainerStats].self, from: try Fixture.data("stats"))
        let s = try #require(stats.first)
        #expect(s.id == "fixture-web")
        #expect(s.memoryLimitBytes == 1_073_741_824)
        #expect(s.numProcesses == 1)
        #expect(s.cpuUsageUsec == 1827)
    }

    @Test func decodesDiskUsage() throws {
        let df = try ContainerJSON.decode(DiskUsage.self, from: try Fixture.data("df"))
        #expect(df.images.total == 11)
        #expect(df.containers.total == 3)
        #expect(df.volumes.sizeInBytes == 0)
        #expect(df.totalSizeInBytes > 0)
    }

    @Test func decodesSystemStatus() throws {
        let status = try ContainerJSON.decode(SystemStatus.self, from: try Fixture.data("status"))
        #expect(status.isRunning)
        #expect(status.apiServerVersion?.contains("1.0.0") == true)
    }

    @Test func decodesNetworks() throws {
        let nets = try ContainerJSON.decode([NetworkResource].self, from: try Fixture.data("networks"))
        let def = try #require(nets.first)
        #expect(def.name == "default")
        #expect(def.isBuiltin)
        #expect(def.status?.ipv4Subnet == "192.168.64.0/24")
    }

    @Test func decodesEmptyVolumes() throws {
        let vols = try ContainerJSON.decode([VolumeResource].self, from: try Fixture.data("volumes"))
        #expect(vols.isEmpty)
    }

    @Test func decodesMultiArchImage() throws {
        let images = try ContainerJSON.decode([ImageResource].self, from: try Fixture.data("image-inspect"))
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

    @Test func handlesDatesWithAndWithoutFractionalSeconds() throws {
        #expect(ContainerJSON.parseDate("2026-06-24T10:16:58Z") != nil)
        #expect(ContainerJSON.parseDate("2026-06-16T00:01:29.967161902Z") != nil)
        #expect(ContainerJSON.parseDate("not-a-date") == nil)
    }

    @Test func unknownRuntimeStatusFallsBack() throws {
        let data = Data(#"{"state":"frobnicating","networks":[]}"#.utf8)
        let s = try ContainerJSON.decode(ContainerRuntimeState.self, from: data)
        #expect(s.state == .unknown)
    }
}
