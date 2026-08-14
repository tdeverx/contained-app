import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case containers
    case images
    case volumes
    case networks

    static let allCases: [AppSection] = [
        .containers,
        .images,
        .volumes,
        .networks,
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .containers: return AppText.sectionContainers
        case .images: return AppText.sectionImages
        case .volumes: return AppText.sectionVolumes
        case .networks: return AppText.sectionNetworks
        }
    }

    var symbol: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "square.stack.3d.up"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        }
    }

    var group: AppSectionGroup {
        switch self {
        case .containers, .images:
            return .workloads
        case .volumes, .networks:
            return .infra
        }
    }
}

enum AppSectionGroup: String, CaseIterable, Identifiable {
    case workloads = "Workloads"
    case infra = "Infra"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workloads: AppText.sectionGroupWorkloads
        case .infra: AppText.sectionGroupInfra
        }
    }
}
