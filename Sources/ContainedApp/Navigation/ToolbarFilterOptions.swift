enum ImageGrouping: String, CaseIterable, Identifiable {
    case none, registry, status
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return AppText.string("filter.none", defaultValue: "None")
        case .registry: return AppText.string("filter.registry", defaultValue: "Registry")
        case .status: return AppText.string("filter.status", defaultValue: "Status")
        }
    }
    var symbol: String {
        switch self {
        case .none: return "square.stack.3d.up"
        case .registry: return "globe"
        case .status: return "arrow.triangle.2.circlepath"
        }
    }
}

enum ImageSort: String, CaseIterable, Identifiable {
    case status, name, tags
    var id: String { rawValue }
    var title: String {
        switch self {
        case .status: return AppText.string("filter.status", defaultValue: "Status")
        case .name: return AppText.string("filter.name", defaultValue: "Name")
        case .tags: return AppText.string("image.tags", defaultValue: "Tags")
        }
    }
    var symbol: String {
        switch self {
        case .status: return "bolt"
        case .name: return "textformat"
        case .tags: return "tag"
        }
    }
}

enum ImageFilter: String, CaseIterable, Identifiable {
    case all, updates, errors
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return AppText.string("filter.allImages", defaultValue: "All images")
        case .updates: return AppText.string("filter.updatesOnly", defaultValue: "Updates only")
        case .errors: return AppText.string("filter.errorsOnly", defaultValue: "Errors only")
        }
    }
    var symbol: String {
        switch self {
        case .all: return "tray.full"
        case .updates: return "arrow.down.circle"
        case .errors: return "exclamationmark.triangle"
        }
    }
}

enum TemplateGrouping: String, CaseIterable, Identifiable {
    case none, image
    var id: String { rawValue }
    var title: String { self == .none ? AppText.string("filter.none", defaultValue: "None") : AppText.string("filter.image", defaultValue: "Image") }
    var symbol: String { self == .none ? "bookmark" : "shippingbox" }
}

enum TemplateSort: String, CaseIterable, Identifiable {
    case newest, name, image
    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: return AppText.string("filter.newest", defaultValue: "Newest")
        case .name: return AppText.string("filter.name", defaultValue: "Name")
        case .image: return AppText.string("filter.image", defaultValue: "Image")
        }
    }
    var symbol: String {
        switch self {
        case .newest: return "clock"
        case .name: return "textformat"
        case .image: return "shippingbox"
        }
    }
}

enum NetworkGrouping: String, CaseIterable, Identifiable {
    case none, kind, mode
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return AppText.string("filter.none", defaultValue: "None")
        case .kind: return AppText.string("filter.kind", defaultValue: "Kind")
        case .mode: return AppText.string("filter.mode", defaultValue: "Mode")
        }
    }
    var symbol: String {
        switch self {
        case .none: return "network"
        case .kind: return "square.stack"
        case .mode: return "switch.2"
        }
    }
}

enum NetworkSort: String, CaseIterable, Identifiable {
    case name, mode, plugin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: return AppText.string("filter.name", defaultValue: "Name")
        case .mode: return AppText.string("filter.mode", defaultValue: "Mode")
        case .plugin: return AppText.string("filter.plugin", defaultValue: "Plugin")
        }
    }
    var symbol: String {
        switch self {
        case .name: return "textformat"
        case .mode: return "switch.2"
        case .plugin: return "puzzlepiece"
        }
    }
}

enum NetworkFilter: String, CaseIterable, Identifiable {
    case all, custom, builtin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return AppText.string("filter.allNetworks", defaultValue: "All networks")
        case .custom: return AppText.string("filter.customOnly", defaultValue: "Custom only")
        case .builtin: return AppText.string("filter.builtInOnly", defaultValue: "Built-in only")
        }
    }
    var symbol: String {
        switch self {
        case .all: return "tray.full"
        case .custom: return "network"
        case .builtin: return "network.badge.shield.half.filled"
        }
    }
}
