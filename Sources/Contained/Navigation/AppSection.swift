import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case containers
    case images
    case volumes
    case networks
    case system
    case registries
    case templates
    case activity
    case settings

    static let allCases: [AppSection] = [
        .containers,
        .images,
        .volumes,
        .networks,
        .system,
        .templates,
        .activity,
        .settings,
    ]

    static func navigableSections(panelNavigationEnabled: Bool) -> [AppSection] {
        allCases.filter { section in
            section.isNavigable(panelNavigationEnabled: panelNavigationEnabled)
        }
    }

    func isNavigable(panelNavigationEnabled: Bool) -> Bool {
        guard panelNavigationEnabled else { return true }
        switch self {
        case .system, .activity, .settings:
            return false
        default:
            return true
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .containers: return "Containers"
        case .images: return "Images"
        case .volumes: return "Volumes"
        case .networks: return "Networks"
        case .system: return "System"
        case .registries: return "Registries"
        case .templates: return "Templates"
        case .activity: return "Activity"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "square.stack.3d.up"
        case .volumes: return "externaldrive"
        case .networks: return "network"
        case .system: return "gearshape.2"
        case .registries: return "key"
        case .templates: return "bookmark"
        case .activity: return "bell"
        case .settings: return "gearshape"
        }
    }

    var group: AppSectionGroup {
        switch self {
        case .containers, .images, .templates:
            return .workloads
        case .volumes, .networks, .registries:
            return .infra
        case .system, .activity, .settings:
            return .system
        }
    }
}

enum AppSectionGroup: String, CaseIterable, Identifiable {
    case workloads = "Workloads"
    case infra = "Infra"
    case system = "System"

    var id: String { rawValue }
}
