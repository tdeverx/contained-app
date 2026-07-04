import Foundation
import ContainedCore

struct VolumeLinkedPath: Codable, Identifiable, Hashable {
    var id = UUID()
    var volumeID: UUID
    var volumeSource: String
    var volumeTarget: String
    var hostPath: String
    var linkPath: String
    var readOnly: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case volumeID
        case volumeSource
        case volumeTarget
        case hostPath
        case linkPath
        case readOnly
    }

    init(id: UUID = UUID(),
         volumeID: UUID,
         volumeSource: String = "",
         volumeTarget: String = "",
         hostPath: String = "",
         linkPath: String = "",
         readOnly: Bool = true) {
        self.id = id
        self.volumeID = volumeID
        self.volumeSource = volumeSource
        self.volumeTarget = volumeTarget
        self.hostPath = hostPath
        self.linkPath = linkPath
        self.readOnly = readOnly
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        volumeID = try c.decode(UUID.self, forKey: .volumeID)
        volumeSource = try c.decodeIfPresent(String.self, forKey: .volumeSource) ?? ""
        volumeTarget = try c.decodeIfPresent(String.self, forKey: .volumeTarget) ?? ""
        hostPath = try c.decodeIfPresent(String.self, forKey: .hostPath) ?? ""
        linkPath = try c.decodeIfPresent(String.self, forKey: .linkPath) ?? ""
        readOnly = try c.decodeIfPresent(Bool.self, forKey: .readOnly) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(volumeID, forKey: .volumeID)
        try c.encode(volumeSource, forKey: .volumeSource)
        try c.encode(volumeTarget, forKey: .volumeTarget)
        try c.encode(hostPath, forKey: .hostPath)
        try c.encode(linkPath, forKey: .linkPath)
        try c.encode(readOnly, forKey: .readOnly)
    }

    init(id: UUID = UUID(),
         volume: Core.Container.VolumeMount,
         hostPath: String = "",
         linkPath: String = "",
         readOnly: Bool = true) {
        self.init(id: id,
                  volumeID: volume.id,
                  volumeSource: volume.source,
                  volumeTarget: volume.target,
                  hostPath: hostPath,
                  linkPath: linkPath,
                  readOnly: readOnly)
    }

    var isValid: Bool {
        !hostPath.trimmedForVolumeLink.isEmpty && !linkPath.trimmedForVolumeLink.isEmpty
    }

    var mountTarget: String {
        "/run/contained-links/\(id.uuidString.lowercased())"
    }

    func resolvedLinkPath(in volume: Core.Container.VolumeMount) -> String {
        let trimmed = linkPath.trimmedForVolumeLink
        guard !trimmed.isEmpty else { return "" }
        let volumeTarget = volume.target.trimmedForVolumeLink
        if trimmed.hasPrefix("/") {
            return trimmed.isInsideVolumeTarget(volumeTarget) ? trimmed : ""
        }
        return volumeTarget.appendingPathComponent(trimmed)
    }

    func isAttached(to volume: Core.Container.VolumeMount) -> Bool {
        if volume.id == volumeID { return true }
        return !volumeSource.trimmedForVolumeLink.isEmpty &&
            volume.source.trimmedForVolumeLink == volumeSource.trimmedForVolumeLink &&
            volume.target.trimmedForVolumeLink == volumeTarget.trimmedForVolumeLink
    }

    mutating func attach(to volume: Core.Container.VolumeMount) {
        volumeID = volume.id
        volumeSource = volume.source
        volumeTarget = volume.target
    }

    func attached(to volume: Core.Container.VolumeMount) -> VolumeLinkedPath {
        var copy = self
        copy.attach(to: volume)
        return copy
    }

    func hostMount() -> Core.Container.VolumeMount {
        Core.Container.VolumeMount(source: hostPath.trimmedForVolumeLink,
                                   target: mountTarget,
                                   readOnly: readOnly)
    }
}

struct VolumeLinkPlan {
    var runtimeKind: Core.Runtime.Kind
    var image: String
    var platform: String
    var os: String
    var architecture: String
    var volumeMounts: [Core.Container.VolumeMount]
    var links: [(linkPath: String, targetPath: String)]
}

struct StorageGroup: Codable, Identifiable, Hashable {
    var id = UUID()
    var volumeID = UUID()
    var usesRuntimeVolume: Bool
    var volumeName: String
    var volumeTarget: String
    var paths: [StoragePath]

    init(id: UUID = UUID(),
         volumeID: UUID = UUID(),
         usesRuntimeVolume: Bool = false,
         volumeName: String = "",
         volumeTarget: String = "",
         paths: [StoragePath] = [StoragePath()]) {
        self.id = id
        self.volumeID = volumeID
        self.usesRuntimeVolume = usesRuntimeVolume
        self.volumeName = volumeName
        self.volumeTarget = volumeTarget
        self.paths = paths
    }

    init(volume: Core.Container.VolumeMount, links: [VolumeLinkedPath]) {
        self.init(id: UUID(),
                  volumeID: volume.id,
                  usesRuntimeVolume: true,
                  volumeName: volume.source,
                  volumeTarget: volume.target,
                  paths: links.map(StoragePath.init(link:)))
    }
}

struct StoragePath: Codable, Identifiable, Hashable {
    var id = UUID()
    var hostPath: String
    var internalPath: String
    var readOnly: Bool

    init(id: UUID = UUID(),
         hostPath: String = "",
         internalPath: String = "",
         readOnly: Bool = true) {
        self.id = id
        self.hostPath = hostPath
        self.internalPath = internalPath
        self.readOnly = readOnly
    }

    init(volume: Core.Container.VolumeMount) {
        self.init(id: volume.id,
                  hostPath: volume.source,
                  internalPath: volume.target,
                  readOnly: volume.readOnly)
    }

    init(link: VolumeLinkedPath) {
        self.init(id: link.id,
                  hostPath: link.hostPath,
                  internalPath: link.linkPath,
                  readOnly: link.readOnly)
    }
}

extension StorageGroup {
    static func groups(from volumes: [Core.Container.VolumeMount],
                       linkedVolumePaths: [VolumeLinkedPath]) -> [StorageGroup] {
        var groups: [StorageGroup] = []
        var plainPaths: [StoragePath] = []

        for volume in volumes {
            if volume.source.trimmedForVolumeLink.isEmpty || volume.source.isHostPathStorageSource {
                plainPaths.append(StoragePath(volume: volume))
            } else {
                let links = linkedVolumePaths.filter { $0.isAttached(to: volume) }
                groups.append(StorageGroup(volume: volume, links: links))
            }
        }

        if !plainPaths.isEmpty {
            groups.insert(StorageGroup(usesRuntimeVolume: false, paths: plainPaths), at: 0)
        }
        return groups
    }

    static func volumeMounts(from groups: [StorageGroup]) -> [Core.Container.VolumeMount] {
        var result: [Core.Container.VolumeMount] = []
        for group in groups {
            if group.usesRuntimeVolume {
                var volume = Core.Container.VolumeMount(source: group.volumeName.trimmedForVolumeLink,
                                                        target: group.volumeTarget.trimmedForVolumeLink,
                                                        readOnly: false)
                volume.id = group.volumeID
                appendUnique(volume, to: &result)
            } else {
                for path in group.paths {
                    var volume = Core.Container.VolumeMount(source: path.hostPath.trimmedForVolumeLink,
                                                            target: path.internalPath.trimmedForVolumeLink,
                                                            readOnly: path.readOnly)
                    volume.id = path.id
                    appendUnique(volume, to: &result)
                }
            }
        }
        return result
    }

    static func linkedPaths(from groups: [StorageGroup]) -> [VolumeLinkedPath] {
        groups.flatMap { group -> [VolumeLinkedPath] in
            guard group.usesRuntimeVolume else { return [] }
            let volume = Core.Container.VolumeMount(source: group.volumeName.trimmedForVolumeLink,
                                                    target: group.volumeTarget.trimmedForVolumeLink,
                                                    readOnly: false)
            return group.paths.map { path in
                VolumeLinkedPath(id: path.id,
                                 volumeID: group.volumeID,
                                 volumeSource: volume.source,
                                 volumeTarget: volume.target,
                                 hostPath: path.hostPath,
                                 linkPath: path.internalPath,
                                 readOnly: path.readOnly)
            }
        }
    }

    private static func appendUnique(_ volume: Core.Container.VolumeMount,
                                     to volumes: inout [Core.Container.VolumeMount]) {
        guard volume.isValid else { return }
        guard !volumes.contains(where: { existing in
            existing.source == volume.source &&
            existing.target == volume.target &&
            existing.readOnly == volume.readOnly
        }) else { return }
        volumes.append(volume)
    }
}

private extension String {
    var trimmedForVolumeLink: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isHostPathStorageSource: Bool {
        let trimmed = trimmedForVolumeLink
        return trimmed.hasPrefix("/") || trimmed.hasPrefix("~")
    }

    func appendingPathComponent(_ component: String) -> String {
        let trimmedBase = trimmedForVolumeLink
        let trimmedComponent = component.trimmedForVolumeLink
        guard !trimmedBase.isEmpty else { return trimmedComponent }
        guard !trimmedComponent.isEmpty else { return trimmedBase }
        if trimmedBase.hasSuffix("/") { return trimmedBase + trimmedComponent }
        return trimmedBase + "/" + trimmedComponent
    }

    func isInsideVolumeTarget(_ target: String) -> Bool {
        let trimmedTarget = target.trimmedForVolumeLink
        guard !trimmedTarget.isEmpty else { return false }
        if trimmedTarget == "/" { return hasPrefix("/") }
        let prefix = trimmedTarget.hasSuffix("/") ? trimmedTarget : trimmedTarget + "/"
        return self == trimmedTarget || hasPrefix(prefix)
    }
}
