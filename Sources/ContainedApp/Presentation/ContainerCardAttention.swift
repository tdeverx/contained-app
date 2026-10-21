import ContainedCore

enum ContainerCardAttention: Equatable {
    case update, recovery

    static func resolve(update: Core.Image.ContainerUpdateState, requiresRecovery: Bool) -> Self? {
        if requiresRecovery { return .recovery }
        return update.requiresUpdate ? .update : nil
    }

    var systemImage: String {
        self == .recovery ? "exclamationmark.triangle.fill" : "exclamationmark.triangle"
    }

    var help: String {
        self == .recovery
            ? AppText.string("recreate.reviewRecovery.help", defaultValue: "Review the saved image and command, then restore the missing container")
            : AppText.updateContainer
    }
}
