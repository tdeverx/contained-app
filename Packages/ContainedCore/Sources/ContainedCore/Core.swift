import Foundation

/// Root namespace for Contained's backend, runtime, import/export, and metric systems.
public enum Core {}

public extension Core {
    enum Runtime {}
    enum Container {}
    enum Image {}
    enum Compose {}
    enum Export {}
    enum Migration {}
    enum Registry {}
    enum Network {}
    enum Volume {}
    enum System {}
    enum Metrics {}
    enum Command {}
    enum Error {}
    enum Field {}
    enum Schema {}
}

public extension Core.Runtime {
    typealias Kind = RuntimeKind
    typealias Descriptor = RuntimeDescriptor
    typealias Capability = RuntimeCapability
    typealias SystemAction = RuntimeSystemAction
    typealias UnsupportedCapability = UnsupportedRuntimeCapability
}

public extension Core.Container {
    typealias CreateRequest = ContainerCreateRequest
    typealias CreateResult = ContainerCreateResult
    typealias KeyValue = ContainerCreateKeyValue
    typealias Port = ContainerCreatePort
    typealias VolumeMount = ContainerCreateVolume
    typealias Socket = ContainerCreateSocket
    typealias ImageDefaults = ContainerImageDefaults
    typealias Snapshot = ContainerSnapshot
    typealias RuntimeState = ContainerRuntimeState
    typealias Configuration = ContainerConfiguration
    typealias RuntimeStatus = ContainedCore.RuntimeStatus
    typealias Document = ContainerDocument
    typealias Spec = ContainerSpec
}

public extension Core.Command {
    typealias Preview = RuntimeCommandPreview
    typealias Invocation = CommandInvocation
    typealias Runner = CommandRunner
    typealias Running = CommandRunning
    typealias ExecutionPriority = CommandExecutionPriority
}

public extension Core.Compose {
    typealias Project = ComposeProject
    typealias Service = ComposeService
    typealias ImportPlan = RuntimeComposeImportPlan
    typealias ImportItem = RuntimeComposeImportItem
    typealias ExportPlan = ComposeExportPlan
    typealias Dialect = ComposeDialect
}

public extension Core.Image {
    typealias Resource = ImageResource
    typealias Configuration = ImageConfiguration
    typealias Variant = ImageVariant
    typealias UpdateStatus = ImageUpdateStatus
    typealias UpdateState = ImageUpdateState
}

public extension Core.Registry {
    typealias Login = RegistryLogin
    typealias ImageReference = RegistryImageReference
    typealias ManifestClient = RegistryManifestClient
}

public extension Core.Network {
    typealias Resource = NetworkResource
    typealias Configuration = NetworkConfiguration
    typealias Status = NetworkStatus
}

public extension Core.Volume {
    typealias Resource = VolumeResource
    typealias Configuration = VolumeConfiguration
}

public extension Core.System {
    typealias Status = SystemStatus
    typealias Properties = SystemProperties
    typealias DiskUsage = ContainedCore.DiskUsage
}

public extension Core.Metrics {
    typealias GraphMetric = ContainedCore.GraphMetric
    typealias ContainerStats = ContainedCore.ContainerStats
    typealias RuntimeStatsSnapshot = ContainedCore.RuntimeStatsSnapshot
    typealias StatsDelta = ContainedCore.StatsDelta
    typealias NormalizationMode = StatsNormalizationMode
    typealias NormalizationContext = StatsNormalizationContext
    typealias HistorySample = MetricHistorySample
}

public extension Core.Migration {
    typealias Plan = RuntimeCoreSwitchPlan
    typealias UnavailableReason = RuntimeCoreSwitchUnavailableReason
}

public extension Core.Error {
    typealias PackageError = ContainedPackageError
    typealias Command = CommandError
}

public extension Core.Field {
    typealias Path = RuntimeFieldPath
    typealias ProvenanceMap = RuntimeFieldProvenanceMap
}

public extension Core.Schema {
    typealias Version = CoreSchemaVersion
}
