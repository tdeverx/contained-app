import Foundation
import CryptoKit

struct AppleStorageInventory: Encodable, Sendable {
    var containers: [Core.Container.Snapshot]
    var builders: [Core.Container.Snapshot]
    var images: [Core.Image.Resource]
    var volumes: [Core.Volume.Resource]
    var networks: [Core.Network.Resource]

    var allContainers: [Core.Container.Snapshot] { containers + builders }
    func identities(for action: Core.System.CleanupAction) -> [String] {
        let candidates: [String]
        switch action {
        case .compactRunningContainers:
            candidates = containers.filter { $0.state == .running }.map(\.id)
        case .compactRunningBuilder:
            candidates = builders.filter { $0.state == .running }.map(\.id)
        case .resetBuilderCache:
            candidates = builders.map(\.id)
        case .stoppedContainers:
            candidates = containers.filter { $0.state == .stopped }.map(\.id)
        case .danglingImages, .unusedImages:
            let references = Set(allContainers.map { Core.Registry.ImageReference.normalizedKey($0.image) })
            let digests = Set(allContainers.compactMap { $0.configuration.image.descriptor?.digest })
            candidates = images.filter { image in
                (action != .danglingImages || image.reference == image.id || image.reference.hasPrefix("sha256:")) &&
                    !references.contains(Core.Registry.ImageReference.normalizedKey(image.reference)) &&
                    !digests.contains(image.id) && !digests.contains(image.digest ?? "") &&
                    !image.variants.contains(where: { digests.contains($0.digest) })
            }.map(\.reference)
        case .unusedVolumes:
            candidates = volumes.filter { volume in
                !allContainers.contains { snapshot in
                    snapshot.configuration.mounts.contains { mount in
                        mount.source == volume.name ||
                            (volume.configuration.source != nil && mount.source == volume.configuration.source)
                    }
                }
            }.map(\.name)
        case .unusedNetworks:
            let referenced = Set(allContainers.flatMap { $0.configuration.networks.map(\.network) })
            candidates = networks.filter {
                !$0.isBuiltin && $0.labels["com.apple.container.resource.role"] != "system" &&
                    $0.name != "default" && !referenced.contains($0.name) && !referenced.contains($0.id)
            }.map(\.name)
        }
        return Array(Set(candidates)).sorted()
    }

    func token() throws -> Data {
        var canonical = self
        canonical.containers.sort { $0.id < $1.id }
        canonical.builders.sort { $0.id < $1.id }
        canonical.images.sort { $0.reference < $1.reference }
        canonical.volumes.sort { $0.id < $1.id }
        canonical.networks.sort { $0.id < $1.id }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return Data(SHA256.hash(data: try encoder.encode(canonical)))
    }
}
