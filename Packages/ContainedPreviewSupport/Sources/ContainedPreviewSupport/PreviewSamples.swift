import Foundation
import ContainedCore
import ContainedRuntime

public enum PreviewSamples {
    public static let now = Date(timeIntervalSinceReferenceDate: 790_000_000)

    public static let appleRuntime = RuntimeDescriptor.appleContainer

    public static let webContainer = ContainerSnapshot.placeholder(
        id: "preview-web",
        image: "docker.io/library/nginx:latest",
        state: .running
    )

    public static let workerContainer = ContainerSnapshot.placeholder(
        id: "preview-worker",
        image: "ghcr.io/example/worker:nightly",
        state: .stopped
    )

    public static let stats = StatsDelta(
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

    public static let sparklineValues: [Double] = [
        0.12, 0.16, 0.18, 0.25, 0.22, 0.31, 0.38, 0.35,
        0.44, 0.48, 0.43, 0.52, 0.57, 0.54, 0.61, 0.58,
        0.66, 0.62, 0.70, 0.68, 0.74, 0.71, 0.78, 0.76
    ]

    public static let networkSamples: [Double] = [
        18_000, 24_000, 22_000, 46_000, 42_000, 54_000,
        66_000, 72_000, 68_000, 80_000, 92_000, 88_000
    ]

    public static let image = decode(ImageResource.self, from: """
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

    public static let imageGroup = LocalImageTagGroup.group(containing: image, in: [image])

    public static let createRequest: ContainerCreateRequest = {
        var request = ContainerCreateRequest()
        request.runtimeKind = .appleContainer
        request.image = image.reference
        request.platform = "linux/arm64"
        request.name = "preview-web"
        request.command = ["nginx", "-g", "daemon off;"]
        request.env = [ContainerCreateKeyValue(key: "ENV", value: "preview")]
        request.labels = [ContainerCreateKeyValue(key: "contained.stack", value: "preview")]
        request.ports = [ContainerCreatePort(hostPort: "8080", containerPort: "80")]
        request.cpus = "2"
        request.memory = "1g"
        request.workingDir = "/"
        request.useInit = true
        return request
    }()

    public static let activityTitle = "Preview activity"
    public static let activityDetail = "Deterministic preview data"
}

private func decode<T: Decodable>(_ type: T.Type, from json: String) -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    do {
        return try decoder.decode(T.self, from: Data(json.utf8))
    } catch {
        preconditionFailure("Invalid preview fixture for \(T.self): \(error)")
    }
}
