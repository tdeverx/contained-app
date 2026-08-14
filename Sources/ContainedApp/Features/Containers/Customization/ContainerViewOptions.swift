import Foundation

/// How containers are ordered in the main grid.
enum ContainerSort: String, CaseIterable, Identifiable, Codable, Sendable {
    case name, status, image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:   return AppText.string("filter.name", defaultValue: "Name")
        case .status: return AppText.string("filter.status", defaultValue: "Status")
        case .image:  return AppText.string("filter.image", defaultValue: "Image")
        }
    }

    var symbol: String {
        switch self {
        case .name:   return "textformat"
        case .status: return "bolt"
        case .image:  return "shippingbox"
        }
    }
}
