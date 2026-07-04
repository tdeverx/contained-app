import Foundation
import ContainedCore

enum SystemVolumeInventory {
    enum Kind: String {
        case named = "Named"
        case anonymous = "Temp"
        case localPath = "Local path"

        var symbol: String {
            switch self {
            case .named: return "externaldrive"
            case .anonymous: return "externaldrive.badge.timemachine"
            case .localPath: return "folder"
            }
        }
    }

    struct Entry: Identifiable {
        let id: String
        let kind: Kind
        let runtimeKind: Core.Runtime.Kind
        let title: String
        let subtitle: String?
        let containers: [Core.Container.Snapshot]
        let resource: Core.Volume.Resource?
        let source: String?
        let destination: String?
    }

    static func build(volumes: [Core.Volume.Resource], containers: [Core.Container.Snapshot]) -> [Entry] {
        let sortedVolumes = volumes.sorted {
            if $0.runtimeKind != $1.runtimeKind {
                return $0.runtimeKind.rawValue.localizedCaseInsensitiveCompare($1.runtimeKind.rawValue) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let namedResources = Dictionary(uniqueKeysWithValues: sortedVolumes.map { ($0.scopedID, $0) })
        var byID: [String: Entry] = [:]

        for volume in sortedVolumes {
            byID["named:\(volume.scopedID)"] = Entry(
                id: "named:\(volume.scopedID)",
                kind: .named,
                runtimeKind: volume.runtimeKind,
                title: volume.name,
                subtitle: volumeSubtitle(volume),
                containers: containersMounting(source: volume.name,
                                               runtimeKind: volume.runtimeKind,
                                               in: containers),
                resource: volume,
                source: volume.name,
                destination: nil
            )
        }

        for snapshot in containers {
            for mount in snapshot.configuration.mounts {
                guard let entry = mountInventoryEntry(mount,
                                                      snapshot: snapshot,
                                                      namedResources: namedResources) else { continue }
                if let existing = byID[entry.id] {
                    byID[entry.id] = merging(existing, with: entry)
                } else {
                    byID[entry.id] = entry
                }
            }
        }

        return byID.values.sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    static func rowSubtitle(_ entry: Entry) -> String? {
        var parts: [String] = []
        if let subtitle = entry.subtitle { parts.append(subtitle) }
        if let destination = entry.destination { parts.append("→ \(destination)") }
        if !entry.containers.isEmpty {
            parts.append(entry.containers.map(\.displayName).joined(separator: ", "))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func merging(_ existing: Entry, with incoming: Entry) -> Entry {
        var containers = existing.containers
        for snapshot in incoming.containers where !containers.contains(where: { $0.scopedID == snapshot.scopedID }) {
            containers.append(snapshot)
        }
        return Entry(id: existing.id,
                     kind: existing.kind,
                     runtimeKind: existing.runtimeKind,
                     title: existing.title,
                     subtitle: existing.subtitle,
                     containers: sortedContainers(containers),
                     resource: existing.resource,
                     source: existing.source ?? incoming.source,
                     destination: existing.destination ?? incoming.destination)
    }

    private static func volumeSubtitle(_ volume: Core.Volume.Resource) -> String? {
        let config = volume.configuration
        let parts = [config.sizeInBytes.map { Format.bytes($0) }, config.format].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func mountInventoryEntry(_ mount: Core.Container.Mount,
                                            snapshot: Core.Container.Snapshot,
                                            namedResources: [String: Core.Volume.Resource]) -> Entry? {
        let source = mount.source?.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = mount.effectiveDestination
        let type = mount.type?.lowercased()

        if let source, !source.isEmpty, isLocalPath(source, type: type) {
            return Entry(id: "path:\(snapshot.runtimeKind.rawValue):\(source):\(destination ?? "")",
                         kind: .localPath,
                         runtimeKind: snapshot.runtimeKind,
                         title: source,
                         subtitle: typeLabel(type),
                         containers: [snapshot],
                         resource: nil,
                         source: source,
                         destination: destination)
        }

        if let source, !source.isEmpty {
            let scopedSource = snapshot.runtimeKind.scopedID(for: source)
            let resource = namedResources[scopedSource]
            return Entry(id: "named:\(scopedSource)",
                         kind: .named,
                         runtimeKind: snapshot.runtimeKind,
                         title: source,
                         subtitle: resource.map(volumeSubtitle(_:)) ?? typeLabel(type),
                         containers: [snapshot],
                         resource: resource,
                         source: source,
                         destination: destination)
        }

        guard destination != nil || type == "tmpfs" else { return nil }
        let title = destination ?? "anonymous mount"
        return Entry(id: "anon:\(snapshot.scopedID):\(title)",
                     kind: .anonymous,
                     runtimeKind: snapshot.runtimeKind,
                     title: title,
                     subtitle: typeLabel(type),
                     containers: [snapshot],
                     resource: nil,
                     source: nil,
                     destination: destination)
    }

    private static func isLocalPath(_ source: String, type: String?) -> Bool {
        type == "bind"
            || type == "virtiofs"
            || source.hasPrefix("/")
            || source.hasPrefix("~/")
            || source.hasPrefix("./")
            || source.hasPrefix("../")
    }

    private static func typeLabel(_ type: String?) -> String? {
        guard let type, !type.isEmpty else { return nil }
        return type.uppercased()
    }

    private static func containersMounting(source: String,
                                           runtimeKind: Core.Runtime.Kind,
                                           in containers: [Core.Container.Snapshot]) -> [Core.Container.Snapshot] {
        sortedContainers(containers.filter { snapshot in
            snapshot.runtimeKind == runtimeKind &&
            snapshot.configuration.mounts.contains { $0.source == source }
        })
    }

    private static func sortedContainers(_ containers: [Core.Container.Snapshot]) -> [Core.Container.Snapshot] {
        containers.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
