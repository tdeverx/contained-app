enum ImageGrouping: String, CaseIterable, Identifiable {
    case none, registry, status
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .registry: return "Registry"
        case .status: return "Status"
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
        case .status: return "Status"
        case .name: return "Name"
        case .tags: return "Tags"
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
        case .all: return "All images"
        case .updates: return "Updates only"
        case .errors: return "Errors only"
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
    var title: String { self == .none ? "None" : "Image" }
    var symbol: String { self == .none ? "bookmark" : "shippingbox" }
}

enum TemplateSort: String, CaseIterable, Identifiable {
    case newest, name, image
    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: return "Newest"
        case .name: return "Name"
        case .image: return "Image"
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
        case .none: return "None"
        case .kind: return "Kind"
        case .mode: return "Mode"
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
        case .name: return "Name"
        case .mode: return "Mode"
        case .plugin: return "Plugin"
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
        case .all: return "All networks"
        case .custom: return "Custom only"
        case .builtin: return "Built-in only"
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
