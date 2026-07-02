import Foundation
import ContainedCore
import ContainedRuntime

public struct PreviewMetricHistorySample: Equatable, Sendable, MetricHistorySample {
    public var timestamp: Date
    public var cpuFraction: Double
    public var memoryBytes: Double
    public var netRxBytesPerSec: Double
    public var netTxBytesPerSec: Double
    public var diskReadBytesPerSec: Double
    public var diskWriteBytesPerSec: Double

    public init(timestamp: Date,
                cpuFraction: Double,
                memoryBytes: Double,
                netRxBytesPerSec: Double,
                netTxBytesPerSec: Double,
                diskReadBytesPerSec: Double,
                diskWriteBytesPerSec: Double) {
        self.timestamp = timestamp
        self.cpuFraction = cpuFraction
        self.memoryBytes = memoryBytes
        self.netRxBytesPerSec = netRxBytesPerSec
        self.netTxBytesPerSec = netTxBytesPerSec
        self.diskReadBytesPerSec = diskReadBytesPerSec
        self.diskWriteBytesPerSec = diskWriteBytesPerSec
    }
}

public struct PreviewCardStyleDescriptor: Equatable, Sendable {
    public var symbol: String
    public var tintName: String
    public var fillsBackground: Bool
    public var backgroundOpacity: Double
    public var usesGradient: Bool

    public init(symbol: String,
                tintName: String,
                fillsBackground: Bool,
                backgroundOpacity: Double,
                usesGradient: Bool) {
        self.symbol = symbol
        self.tintName = tintName
        self.fillsBackground = fillsBackground
        self.backgroundOpacity = backgroundOpacity
        self.usesGradient = usesGradient
    }
}

public struct PreviewWidgetDescriptor: Equatable, Sendable {
    public var metric: GraphMetric
    public var secondaryMetric: GraphMetric?
    public var style: String
    public var icon: String
    public var tintName: String?
    public var showsText: Bool

    public init(metric: GraphMetric,
                secondaryMetric: GraphMetric? = nil,
                style: String,
                icon: String,
                tintName: String? = nil,
                showsText: Bool = true) {
        self.metric = metric
        self.secondaryMetric = secondaryMetric
        self.style = style
        self.icon = icon
        self.tintName = tintName
        self.showsText = showsText
    }
}

public enum PreviewActivityKind: String, CaseIterable, Sendable {
    case lifecycle
    case image
    case compose
    case system
    case alert
}

public struct PreviewActivityEvent: Equatable, Sendable {
    public var timestamp: Date
    public var containerID: String?
    public var kind: PreviewActivityKind
    public var subjectID: String?
    public var isRead: Bool

    public init(timestamp: Date,
                containerID: String?,
                kind: PreviewActivityKind,
                subjectID: String?,
                isRead: Bool = false) {
        self.timestamp = timestamp
        self.containerID = containerID
        self.kind = kind
        self.subjectID = subjectID
        self.isRead = isRead
    }
}

public struct PreviewActivityProgress: Equatable, Sendable {
    public var kind: PreviewActivityKind
    public var subjectID: String
    public var detailID: String?
    public var fraction: Double

    public init(kind: PreviewActivityKind,
                subjectID: String,
                detailID: String? = nil,
                fraction: Double) {
        self.kind = kind
        self.subjectID = subjectID
        self.detailID = detailID
        self.fraction = fraction
    }
}

public enum PreviewSamples {
    public static let now = Date(timeIntervalSinceReferenceDate: 790_000_000)

    public static let appleRuntime = RuntimeDescriptor.appleContainer
    public static let dockerRuntime = RuntimeDescriptor(
        kind: .dockerCompatible,
        displayName: "Docker-compatible",
        executableName: "docker",
        capabilities: []
    )
    public static let runtimes = [appleRuntime, dockerRuntime]

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

    public static let metricHistory: [PreviewMetricHistorySample] = sparklineValues.enumerated().map { offset, value in
        PreviewMetricHistorySample(
            timestamp: now.addingTimeInterval(Double(offset) * 30),
            cpuFraction: value,
            memoryBytes: 260_000_000 + Double(offset) * 6_000_000,
            netRxBytesPerSec: networkSamples[offset % networkSamples.count],
            netTxBytesPerSec: networkSamples[(offset + 3) % networkSamples.count] * 0.45,
            diskReadBytesPerSec: 4_000 + Double(offset * 320),
            diskWriteBytesPerSec: 8_000 + Double(offset * 420)
        )
    }

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

    public static let volume = decode(VolumeResource.self, from: """
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

    public static let network = decode(NetworkResource.self, from: """
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

    public static let cardStyle = PreviewCardStyleDescriptor(
        symbol: "shippingbox.fill",
        tintName: "azure",
        fillsBackground: true,
        backgroundOpacity: 0.16,
        usesGradient: true
    )

    public static let widgetConfigs: [PreviewWidgetDescriptor] = [
        PreviewWidgetDescriptor(metric: .cpu, style: "area", icon: "cpu", tintName: "azure"),
        PreviewWidgetDescriptor(metric: .memory, style: "area", icon: "memorychip", tintName: "teal"),
        PreviewWidgetDescriptor(metric: .netRx, secondaryMetric: .netTx, style: "multiLine", icon: "arrow.down.circle")
    ]

    public static let activityEvents: [PreviewActivityEvent] = [
        PreviewActivityEvent(timestamp: now, containerID: webContainer.id, kind: .lifecycle, subjectID: webContainer.id),
        PreviewActivityEvent(timestamp: now.addingTimeInterval(45), containerID: webContainer.id, kind: .image, subjectID: image.reference, isRead: true),
        PreviewActivityEvent(timestamp: now.addingTimeInterval(90), containerID: nil, kind: .alert, subjectID: "runtime-warning")
    ]

    public static let activityStatus = PreviewActivityProgress(kind: .image,
                                                               subjectID: image.reference,
                                                               detailID: "sha256:preview",
                                                               fraction: 0.62)

    public static let unsupportedCapabilityError = UnsupportedRuntimeCapability(kind: .dockerCompatible,
                                                                               capability: .coreMigration)
    public static let commandError = CommandError.nonZeroExit(code: 42,
                                                              stderr: "preview failure",
                                                              command: "container preview")

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
