import ContainedCore

enum ContainerCardAttention: Equatable {
    case update, recovery

    static func resolve(update: Core.Image.ContainerUpdateState, requiresRecovery: Bool, isBusy: Bool) -> Self? {
        // An in-flight recreation also has a saved recovery recipe; it is not a failure yet.
        guard !isBusy else { return nil }
        if requiresRecovery { return .recovery }
        return update.requiresUpdate ? .update : nil
    }

    var systemImage: String {
        self == .recovery ? "exclamationmark.triangle.fill" : "arrow.down.circle"
    }

    var help: String {
        self == .recovery
            ? AppText.string("recreate.reviewRecovery.help", defaultValue: "Review the saved image and command, then restore the missing container")
            : AppText.updateContainer
    }
}
