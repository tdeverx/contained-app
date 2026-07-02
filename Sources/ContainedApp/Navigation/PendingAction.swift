/// One-shot commands that may come from menus, the command palette, or toolbar panels.
enum PendingAction: Equatable {
    case runContainer
    case pullImage, loadImage, pruneImages
    case createVolume
    case createNetwork
    case registryLogin
    case build
    case activityHistory, systemLogs
}
