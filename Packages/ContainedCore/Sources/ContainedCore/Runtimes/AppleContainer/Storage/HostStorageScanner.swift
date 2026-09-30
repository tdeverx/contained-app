import Foundation
import Darwin

enum HostStorageScanner {
    struct Measurement: Sendable {
        var categories: [Core.System.StorageCategory: UInt64] = [:]
        var resources: [String: UInt64] = [:]
        var unsupported: Set<String> = []
        var complete = true
    }

    static func capacity(at root: URL) -> Core.System.StorageCapacity? {
        guard let values = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
              let available = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else { return nil }
        return .init(availableBytes: available, totalBytes: Int64(total))
    }

    static func scan(root: URL, knownContainers: Set<String>, builderIDs: Set<String>) throws -> Measurement {
        guard root.pathComponents.count > 3,
              try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
              try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw Core.System.StorageError.invalidRoot
        }
        var result = Measurement()
        var enumerationFailed = false
        // Foundation may canonicalize /var and /tmp while enumerating. Use the
        // same canonical root for relative paths, after rejecting a linked root.
        guard let physicalPath = root.path.withCString({ realpath($0, nil) }) else {
            throw Core.System.StorageError.invalidRoot
        }
        defer { free(physicalPath) }
        let scanRoot = URL(fileURLWithPath: String(cString: physicalPath), isDirectory: true)
        guard let walker = FileManager.default.enumerator(at: scanRoot, includingPropertiesForKeys: nil,
                                                          errorHandler: { _, _ in enumerationFailed = true; return true }) else {
            throw Core.System.StorageError.unavailable
        }
        var seen: Set<String> = []
        let deadline = Date().addingTimeInterval(15)
        var count = 0
        for case let url as URL in walker {
            count += 1
            if count > 500_000 || Date() > deadline || Task.isCancelled {
                result.complete = false
                break
            }
            var metadata = stat()
            guard url.path.withCString({ lstat($0, &metadata) }) == 0 else { result.complete = false; continue }
            let isLink = metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFLNK)
            if isLink { walker.skipDescendants() }
            let identity = "\(metadata.st_dev):\(metadata.st_ino)"
            guard seen.insert(identity).inserted else { continue }
            let relative = url.pathComponents.dropFirst(scanRoot.pathComponents.count)
            let parts = Array(relative)
            guard let first = parts.first else { continue }
            let name = parts.count > 1 ? parts[1] : nil
            let category: Core.System.StorageCategory
            switch first {
            case "containers": category = name.map(builderIDs.contains) == true ? .builder : .containers
            case "volumes": category = .volumes
            case "content": category = .imageContent
            case "snapshots": category = name == "ingest" ? .ingest : .imageSnapshots
            default: category = .other
            }
            // lstat counts the link's own allocation, never its target. st_blocks also
            // avoids mistaking a sparse disk's virtual capacity for host allocation.
            let allocated = UInt64(max(0, metadata.st_blocks)) * 512
            result.categories[category, default: 0] += allocated
            if let name, first == "containers" || first == "volumes" {
                result.resources[first + "/" + name, default: 0] += allocated
            }
            if first == "containers", let name, !knownContainers.contains(name), !builderIDs.contains(name) {
                result.unsupported.insert("containers/" + name)
            }
            if first == "snapshots", name == "ingest" { result.unsupported.insert("snapshots/ingest") }
            if isLink { result.unsupported.insert("symlink/" + parts.joined(separator: "/")) }
        }
        result.complete = result.complete && !enumerationFailed
        return result
    }
}
