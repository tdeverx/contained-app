import Foundation

public extension Core.Image {
struct LocalTagGroup: Identifiable, Sendable, Hashable {
    public let id: String
    public let digest: String?
    public let references: [String]
    public let tags: [Core.Image.LocalTag]
    public let images: [Core.Image.Resource]

    public var primaryReference: String { references.first ?? id }

    public static func groups(for images: [Core.Image.Resource]) -> [Core.Image.LocalTagGroup] {
        var parent = Array(images.indices)

        func find(_ index: Int) -> Int {
            var index = index
            while parent[index] != index { index = parent[index] }
            return index
        }

        func union(_ lhs: Int, _ rhs: Int) {
            let left = find(lhs)
            let right = find(rhs)
            if left != right { parent[right] = left }
        }

        var indexByKey: [String: Int] = [:]
        for (index, image) in images.enumerated() {
            let keys = groupKeys(for: image)
            for key in keys {
                if let existing = indexByKey[key] {
                    union(existing, index)
                } else {
                    indexByKey[key] = index
                }
            }
        }

        let buckets = Dictionary(grouping: images.indices, by: find)
        return buckets.values.map { indices in
            let images = indices.map { images[$0] }
            let references = Array(Set(images.map(\.reference)))
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            let sortedImages = images.sorted { lhs, rhs in
                if lhs.reference == rhs.reference {
                    return lhs.runtimeKind.rawValue < rhs.runtimeKind.rawValue
                }
                return lhs.reference.localizedCaseInsensitiveCompare(rhs.reference) == .orderedAscending
            }
            let tags = Dictionary(grouping: sortedImages) { image in
                "\(image.runtimeKind.rawValue)|\(Core.Registry.ImageReference.normalizedKey(image.reference))"
            }
            .compactMap { _, images -> Core.Image.LocalTag? in
                guard let first = images.first else { return nil }
                return Core.Image.LocalTag(reference: first.reference,
                                           runtimeKind: first.runtimeKind,
                                           images: images)
            }
            .sorted { lhs, rhs in
                if lhs.reference == rhs.reference {
                    return lhs.runtimeKind.rawValue < rhs.runtimeKind.rawValue
                }
                return lhs.reference.localizedCaseInsensitiveCompare(rhs.reference) == .orderedAscending
            }
            let repositoryKeys = Set(sortedImages.map {
                Core.Registry.ImageReference.normalizedRepositoryKey($0.reference)
            })
            let digests = Set(sortedImages.compactMap(\.digest).filter { !$0.isEmpty })
            let digest = digests.count == 1 ? digests.first : nil
            let id = repositoryKeys.count == 1
                ? repositoryKeys.first!
                : digest ?? repositoryKeys.sorted().first!
            return Core.Image.LocalTagGroup(
                id: id,
                digest: digest,
                references: references,
                tags: tags,
                images: sortedImages
            )
        }
        .sorted { $0.primaryReference.localizedCaseInsensitiveCompare($1.primaryReference) == .orderedAscending }
    }

    public static func group(containing image: Core.Image.Resource, in images: [Core.Image.Resource]) -> Core.Image.LocalTagGroup {
        groups(for: images).first { $0.images.contains(image) }
            ?? Core.Image.LocalTagGroup(id: Core.Registry.ImageReference.normalizedRepositoryKey(image.reference),
                                        digest: image.digest,
                                        references: [image.reference],
                                        tags: [Core.Image.LocalTag(reference: image.reference,
                                                                   runtimeKind: image.runtimeKind,
                                                                   images: [image])],
                                        images: [image])
    }

    private static func groupKeys(for image: Core.Image.Resource) -> [String] {
        var keys = ["repository:\(Core.Registry.ImageReference.normalizedRepositoryKey(image.reference))"]
        if let digest = image.digest, !digest.isEmpty { keys.append("digest:\(digest)") }
        return keys
    }
}

struct LocalTag: Identifiable, Sendable, Hashable {
    public let reference: String
    public let runtimeKind: Core.Runtime.Kind
    public let images: [Core.Image.Resource]

    public var id: String {
        runtimeKind.scopedID(for: Core.Registry.ImageReference.normalizedKey(reference))
    }

    public var digest: String? {
        images.compactMap(\.digest).first
    }
}

}
