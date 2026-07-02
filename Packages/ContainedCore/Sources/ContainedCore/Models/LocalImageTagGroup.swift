import Foundation

public struct LocalImageTagGroup: Identifiable, Sendable, Hashable {
    public let id: String
    public let digest: String?
    public let references: [String]
    public let images: [ImageResource]

    public var primaryReference: String { references.first ?? id }

    public static func groups(for images: [ImageResource]) -> [LocalImageTagGroup] {
        let buckets = Dictionary(grouping: images) { image in
            image.digest ?? image.id
        }
        return buckets.map { key, images in
            let references = images.map(\.reference)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            return LocalImageTagGroup(
                id: key,
                digest: images.compactMap(\.digest).first,
                references: references,
                images: images.sorted { $0.reference.localizedCaseInsensitiveCompare($1.reference) == .orderedAscending }
            )
        }
        .sorted { $0.primaryReference.localizedCaseInsensitiveCompare($1.primaryReference) == .orderedAscending }
    }

    public static func group(containing image: ImageResource, in images: [ImageResource]) -> LocalImageTagGroup {
        groups(for: images).first { $0.images.contains(image) }
            ?? LocalImageTagGroup(id: image.digest ?? image.id, digest: image.digest,
                                  references: [image.reference], images: [image])
    }
}
