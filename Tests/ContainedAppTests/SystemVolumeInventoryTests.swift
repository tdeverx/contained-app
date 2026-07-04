import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("System volume inventory")
struct SystemVolumeInventoryTests {
    @Test func classifiesNamedBindAndAnonymousMounts() throws {
        let volume = try decode(Core.Volume.Resource.self, from: """
        {"configuration":{"name":"data","format":"apfs","sizeInBytes":1024}}
        """)
        let snapshot = try decode(Core.Container.Snapshot.self, from: """
        {
          "id": "web",
          "status": {"state": "running"},
          "configuration": {
            "id": "web",
            "image": {"reference": "nginx:latest"},
            "initProcess": {},
            "mounts": [
              {"type": "volume", "source": "data", "destination": "/data"},
              {"type": "bind", "source": "/tmp/app", "destination": "/app"},
              {"type": "tmpfs", "destination": "/cache"}
            ]
          }
        }
        """)

        let entries = SystemVolumeInventory.build(volumes: [volume], containers: [snapshot])
        #expect(entries.map(\.kind) == [.localPath, .named, .anonymous])

        let named = try #require(entries.first { $0.title == "data" })
        #expect(named.resource?.name == "data")
        #expect(named.containers.map(\.id) == ["web"])
        #expect(SystemVolumeInventory.rowSubtitle(named)?.contains("/data") == true)
    }

    @Test func sameNamedRuntimeVolumesStaySeparate() throws {
        let appleVolume = Core.Volume.Resource(
            configuration: Core.Volume.Configuration(name: "config", format: "ext4"),
            runtimeKind: .appleContainer
        )
        let dockerVolume = Core.Volume.Resource(
            configuration: Core.Volume.Configuration(name: "config", format: "ext4"),
            runtimeKind: .docker
        )
        let appleSnapshot = try decode(Core.Container.Snapshot.self,
                                       runtimeKind: .appleContainer,
                                       from: mountedContainerJSON(id: "apple-web", source: "config"))
        let dockerSnapshot = try decode(Core.Container.Snapshot.self,
                                        runtimeKind: .docker,
                                        from: mountedContainerJSON(id: "docker-web", source: "config"))

        let entries = SystemVolumeInventory.build(volumes: [appleVolume, dockerVolume],
                                                  containers: [appleSnapshot, dockerSnapshot])
            .filter { $0.kind == .named && $0.title == "config" }

        #expect(entries.count == 2)
        #expect(entries.first { $0.runtimeKind == .appleContainer }?.containers.map(\.id) == ["apple-web"])
        #expect(entries.first { $0.runtimeKind == .docker }?.containers.map(\.id) == ["docker-web"])
    }

    private func decode<T: Decodable>(_ type: T.Type,
                                      runtimeKind: Core.Runtime.Kind = .appleContainer,
                                      from json: String) throws -> T {
        try Core.Container.JSON.decode(type, from: Data(json.utf8), runtimeKind: runtimeKind)
    }

    private func mountedContainerJSON(id: String, source: String) -> String {
        """
        {
          "id": "\(id)",
          "status": {"state": "running"},
          "configuration": {
            "id": "\(id)",
            "image": {"reference": "nginx:latest"},
            "initProcess": {},
            "mounts": [
              {"type": "volume", "source": "\(source)", "destination": "/config"}
            ]
          }
        }
        """
    }
}
