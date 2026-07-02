import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case containers
    case images
    case build
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
        .build,
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
        case .build, .system, .activity, .settings:
            return false
        default:
            return true
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .containers: return AppText.sectionContainers
        case .images: return AppText.sectionImages
        case .build: return AppText.sectionBuild
        case .volumes: return AppText.sectionVolumes
        case .networks: return AppText.sectionNetworks
        case .system: return AppText.sectionSystem
        case .registries: return AppText.sectionRegistries
        case .templates: return AppText.sectionTemplates
        case .activity: return AppText.sectionActivity
        case .settings: return AppText.sectionSettings
        }
    }

    var symbol: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "square.stack.3d.up"
        case .build: return "hammer"
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
        case .containers, .images, .build, .templates:
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

    var title: String {
        switch self {
        case .workloads: AppText.sectionGroupWorkloads
        case .infra: AppText.sectionGroupInfra
        case .system: AppText.sectionGroupSystem
        }
    }
}
