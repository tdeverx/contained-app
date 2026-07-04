import ContainedCore

/// App-level runtime choice policy for actions that are not already owned by a resource.
enum AppRuntimeIntent {
    static let placeholderKind = Core.Runtime.Kind(rawValue: "contained-runtime-unselected")

    enum Resolution: Equatable {
        case resolved(Core.Runtime.Kind)
        case needsSelection([Core.Runtime.Descriptor])
        case unavailable(Core.Runtime.Capability)
    }
}

@MainActor
extension AppModel {
    func runtimeDescriptors(supporting capability: Core.Runtime.Capability) -> [Core.Runtime.Descriptor] {
        availableRuntimeDescriptors.filter { $0.supports(capability) }
    }

    func preselectedRuntimeKind(current: Core.Runtime.Kind,
                                capability: Core.Runtime.Capability) -> Core.Runtime.Kind {
        let candidates = runtimeDescriptors(supporting: capability)
        if candidates.contains(where: { $0.kind == current }) {
            return current
        }
        return candidates.first?.kind ?? AppRuntimeIntent.placeholderKind
    }

    func resolveRuntimeIntent(owner: Core.Runtime.Kind? = nil,
                              selected: Core.Runtime.Kind? = nil,
                              capability: Core.Runtime.Capability) -> AppRuntimeIntent.Resolution {
        let candidates = runtimeDescriptors(supporting: capability)
        if let owner, candidates.contains(where: { $0.kind == owner }) {
            return .resolved(owner)
        }
        if let selected, candidates.contains(where: { $0.kind == selected }) {
            return .resolved(selected)
        }
        if candidates.count == 1, let only = candidates.first {
            return .resolved(only.kind)
        }
        if candidates.isEmpty {
            return .unavailable(capability)
        }
        return .needsSelection(candidates)
    }
}
