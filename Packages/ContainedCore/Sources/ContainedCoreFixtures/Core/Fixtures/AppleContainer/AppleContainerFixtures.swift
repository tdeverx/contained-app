import Foundation
import ContainedCore

public extension Core.Fixtures.AppleContainer {
    static let runtimeDescriptor = Core.Runtime.Descriptor.appleContainer
    static let runtimes = [runtimeDescriptor]

    static let webContainer = Core.Container.Snapshot.placeholder(
        id: "preview-web",
        image: "docker.io/library/nginx:latest",
        state: .running
    )

    static let workerContainer = Core.Container.Snapshot.placeholder(
        id: "preview-worker",
        image: "ghcr.io/example/worker:nightly",
        state: .stopped
    )

    static let stats = Core.Metrics.StatsDelta(
        id: "preview-web",
        cpuCoreFraction: 0.62,
        memoryUsageBytes: 420_000_000,
        memoryLimitBytes: 1_073_741_824,
        netRxBytesPerSec: 186_000,
        netTxBytesPerSec: 72_000,
        blockReadBytesPerSec: 8_400,
        blockWriteBytesPerSec: 16_800,
        numProcesses: 9
    )

    static let image = decode(Core.Image.Resource.self, from: """
    {
      "configuration": {
        "name": "docker.io/library/nginx:latest",
        "descriptor": {
          "digest": "sha256:previewnginx",
          "mediaType": "application/vnd.oci.image.index.v1+json",
          "size": 146120
        },
        "creationDate": "2026-07-01T12:00:00Z"
      },
      "id": "sha256:previewnginx",
      "variants": [
        {
          "digest": "sha256:previewnginx-arm64",
          "size": 48120000,
          "platform": { "architecture": "arm64", "os": "linux" },
          "config": {
            "architecture": "arm64",
            "os": "linux",
            "created": "2026-07-01T12:00:00Z",
            "config": {
              "Cmd": ["nginx", "-g", "daemon off;"],
              "Entrypoint": ["/docker-entrypoint.sh"],
              "Env": ["NGINX_VERSION=preview"],
              "WorkingDir": "/",
              "User": "101"
            }
          }
        }
      ]
    }
    """)

    static let imageGroup = Core.Image.LocalTagGroup.group(containing: image, in: [image])

    static let volume = decode(Core.Volume.Resource.self, from: """
    {
      "configuration": {
        "name": "preview-data",
        "source": "/Users/preview/.contained/volumes/preview-data",
        "format": "apfs",
        "sizeInBytes": 10737418240,
        "creationDate": "2026-07-01T12:10:00Z",
        "labels": { "contained.stack": "preview" }
      }
    }
    """)

    static let network = decode(Core.Network.Resource.self, from: """
    {
      "id": "preview-network",
      "configuration": {
        "name": "preview-network",
        "mode": "nat",
        "plugin": "builtin",
        "creationDate": "2026-07-01T12:12:00Z",
        "labels": { "contained.stack": "preview" },
        "options": { "variant": "preview" }
      },
      "status": {
        "ipv4Gateway": "10.42.0.1",
        "ipv4Subnet": "10.42.0.0/24",
        "ipv6Subnet": null
      }
    }
    """)

    static let unsupportedCapabilityError = Core.Runtime.UnsupportedCapability(
        kind: .appleContainer,
        capability: .coreMigration
    )

    static let commandError = Core.Command.Error.nonZeroExit(
        code: 42,
        stderr: "preview failure",
        command: "container preview"
    )

    static let createRequest: Core.Container.CreateRequest = {
        var request = Core.Container.CreateRequest()
        request.runtimeKind = .appleContainer
        request.image = image.reference
        request.platform = "linux/arm64"
        request.name = "preview-web"
        request.command = ["nginx", "-g", "daemon off;"]
        request.env = [Core.Container.KeyValue(key: "ENV", value: "preview")]
        request.labels = [Core.Container.KeyValue(key: "contained.stack", value: "preview")]
        request.ports = [Core.Container.Port(hostPort: "8080", containerPort: "80")]
        request.cpus = "2"
        request.memory = "1g"
        request.workingDir = "/"
        request.useInit = true
        return request
    }()
}

private func decode<T: Decodable>(_ type: T.Type, from json: String) -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
        return try decoder.decode(T.self, from: Data(json.utf8))
    } catch {
        preconditionFailure("Invalid core fixture for \(T.self): \(error)")
    }
}
