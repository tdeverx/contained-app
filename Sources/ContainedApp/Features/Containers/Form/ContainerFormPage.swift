import Foundation

enum ContainerFormPage: CaseIterable, Identifiable {
    case basics
    case network
    case storage
    case options
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .basics:
            AppText.string("runSpec.page.basics", defaultValue: "Basics")
        case .network:
            AppText.string("runSpec.page.network", defaultValue: "Network")
        case .storage:
            AppText.string("runSpec.page.storage", defaultValue: "Storage")
        case .options:
            AppText.string("runSpec.page.options", defaultValue: "Options")
        case .advanced:
            AppText.string("runSpec.page.advanced", defaultValue: "Advanced")
        }
    }

    var subtitle: String {
        switch self {
        case .basics:
            AppText.string("runSpec.page.basics.subtitle", defaultValue: "Image, resources, and process basics")
        case .network:
            AppText.string("runSpec.page.network.subtitle", defaultValue: "Ports, networks, and sockets")
        case .storage:
            AppText.string("runSpec.page.storage.subtitle", defaultValue: "Host paths and runtime volumes")
        case .options:
            AppText.string("runSpec.page.options.subtitle", defaultValue: "Environment, health, and appearance")
        case .advanced:
            AppText.string("runSpec.page.advanced.subtitle", defaultValue: "Less-common runtime fields")
        }
    }

    var systemImage: String {
        switch self {
        case .basics: return "shippingbox"
        case .network: return "network"
        case .storage: return "externaldrive"
        case .options: return "switch.2"
        case .advanced: return "slider.horizontal.3"
        }
    }
}
