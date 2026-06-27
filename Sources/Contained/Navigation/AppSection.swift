import SwiftUI

/// Sidebar destinations, grouped Workloads / Infra / System.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case containers, images, build
    case volumes, registries
    case system, templates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .containers: return "Containers"
        case .images: return "Images"
        case .build: return "Build"
        case .volumes: return "Volumes"
        case .registries: return "Registries"
        case .system: return "System"
        case .templates: return "Templates"
        }
    }

    var systemImage: String {
        switch self {
        case .containers: return "shippingbox"
        case .images: return "square.stack.3d.up"
        case .build: return "hammer"
        case .volumes: return "externaldrive"
        case .registries: return "key"
        case .system: return "gearshape.2"
        case .templates: return "square.on.square"
        }
    }

    enum Group: String, CaseIterable, Identifiable {
        case workloads = "Workloads"
        case infra = "Infra"
        case system = "System"
        var id: String { rawValue }
        var sections: [AppSection] {
            switch self {
            case .workloads: return [.containers, .images, .build]
            case .infra: return [.volumes, .registries]
            case .system: return [.system, .templates]
            }
        }
    }
}
