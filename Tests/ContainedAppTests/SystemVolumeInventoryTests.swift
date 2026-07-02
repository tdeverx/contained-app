import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("System volume inventory")
struct SystemVolumeInventoryTests {
    @Test func classifiesNamedBindAndAnonymousMounts() throws {
        let volume = try decode(VolumeResource.self, from: """
        {"configuration":{"name":"data","format":"apfs","sizeInBytes":1024}}
        """)
        let snapshot = try decode(ContainerSnapshot.self, from: """
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

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
