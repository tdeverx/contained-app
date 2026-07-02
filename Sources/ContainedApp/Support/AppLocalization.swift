import Foundation
import ContainedCore
import ContainedDesignSystem

/// App-owned user-facing copy. Packages receive resolved strings from here; they do not own
/// localized resources or English defaults.
enum AppText {
    static func string(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: .main)
    }

    static var back: String { string("common.back", defaultValue: "Back") }
    static var cancel: String { string("common.cancel", defaultValue: "Cancel") }
    static var clearSearch: String { string("common.clearSearch", defaultValue: "Clear search") }
    static var choose: String { string("common.choose", defaultValue: "Choose") }
    static var close: String { string("common.close", defaultValue: "Close") }
    static var add: String { string("common.add", defaultValue: "Add") }
    static var copied: String { string("common.copied", defaultValue: "Copied") }
    static var copyCommand: String { string("common.copyCommand", defaultValue: "Copy command") }
    static var copyLog: String { string("common.copyLog", defaultValue: "Copy log") }
    static var copyAll: String { string("common.copyAll", defaultValue: "Copy all") }
    static var copyReference: String { string("common.copyReference", defaultValue: "Copy reference") }
    static var clear: String { string("common.clear", defaultValue: "Clear") }
    static var delete: String { string("common.delete", defaultValue: "Delete") }
    static var edit: String { string("common.edit", defaultValue: "Edit") }
    static var refresh: String { string("common.refresh", defaultValue: "Refresh") }
    static var completed: String { string("common.completed", defaultValue: "Completed") }
    static var direction: String { string("common.direction", defaultValue: "Direction") }
    static var done: String { string("common.done", defaultValue: "Done") }
    static var follow: String { string("common.follow", defaultValue: "Follow") }
    static var logIn: String { string("common.logIn", defaultValue: "Log in") }
    static var parent: String { string("common.parent", defaultValue: "Parent") }
    static var reconnect: String { string("common.reconnect", defaultValue: "Reconnect") }
    static var quit: String { string("common.quit", defaultValue: "Quit") }
    static var run: String { string("common.run", defaultValue: "Run") }
    static var save: String { string("common.save", defaultValue: "Save") }
    static var start: String { string("common.start", defaultValue: "Start") }
    static var stop: String { string("common.stop", defaultValue: "Stop") }
    static var restart: String { string("common.restart", defaultValue: "Restart") }
    static var working: String { string("common.working", defaultValue: "Working...") }

    static var addBuildArgument: String { string("build.addBuildArgument", defaultValue: "Add build argument") }
    static var buildImage: String { string("build.buildImage", defaultValue: "Build image") }
    static var cancelBuild: String { string("build.cancelBuild", defaultValue: "Cancel build") }
    static var chooseContextFolder: String { string("build.chooseContextFolder", defaultValue: "Choose context folder") }
    static var chooseBuildContextFolder: String {
        string("build.chooseContextFolderPanel", defaultValue: "Choose the build context folder")
    }
    static var removeBuildArgument: String { string("build.removeBuildArgument", defaultValue: "Remove build argument") }
    static var cardColor: String { string("customize.cardColor", defaultValue: "Card Color") }
    static var current: String { string("common.current", defaultValue: "Current") }
    static var deleteTag: String { string("image.deleteTag", defaultValue: "Delete tag") }
    static var loadImageTar: String { string("image.loadImageTar", defaultValue: "Load Image Tar") }
    static var prune: String { string("image.prune", defaultValue: "Prune") }
    static var pruneImages: String { string("image.pruneImages", defaultValue: "Prune Images") }
    static var pullUpdate: String { string("image.pullUpdate", defaultValue: "Pull Update") }
    static var chooseImageTarArchive: String {
        string("image.chooseTarArchive", defaultValue: "Choose an image tar archive")
    }
    static var checkForUpdates: String { string("updates.checkForUpdates", defaultValue: "Check for Updates") }
    static var checkForUpdatesNow: String { string("updates.checkForUpdatesNow", defaultValue: "Check for app updates now") }
    static var runImageUpdateCheckNow: String {
        string("updates.runImageUpdateCheckNow", defaultValue: "Run image update check now")
    }
    static var addTag: String { string("image.addTag", defaultValue: "Add Tag") }
    static var push: String { string("image.push", defaultValue: "Push") }
    static var saveAsTemplate: String { string("template.saveAsTemplate", defaultValue: "Save as template") }
    static var newNetwork: String { string("network.newNetwork", defaultValue: "New Network") }
    static var newVolume: String { string("volume.newVolume", defaultValue: "New Volume") }
    static var refreshNetworks: String { string("network.refreshNetworks", defaultValue: "Refresh Networks") }
    static var refreshVolumes: String { string("volume.refreshVolumes", defaultValue: "Refresh Volumes") }
    static var systemLogs: String { string("system.systemLogs", defaultValue: "System Logs") }
    static var storageCleanup: String { string("system.storageCleanup", defaultValue: "Storage cleanup") }
    static var markAllRead: String { string("activity.markAllRead", defaultValue: "Mark all read") }
    static var clearActivity: String { string("activity.clearActivity", defaultValue: "Clear activity") }
    static var sectionContainers: String { string("section.containers", defaultValue: "Containers") }
    static var sectionImages: String { string("section.images", defaultValue: "Images") }
    static var sectionBuild: String { string("section.build", defaultValue: "Build") }
    static var sectionVolumes: String { string("section.volumes", defaultValue: "Volumes") }
    static var sectionNetworks: String { string("section.networks", defaultValue: "Networks") }
    static var sectionSystem: String { string("section.system", defaultValue: "System") }
    static var sectionRegistries: String { string("section.registries", defaultValue: "Registries") }
    static var sectionTemplates: String { string("section.templates", defaultValue: "Templates") }
    static var sectionActivity: String { string("section.activity", defaultValue: "Activity") }
    static var sectionSettings: String { string("section.settings", defaultValue: "Settings") }
    static var sectionGroupWorkloads: String { string("sectionGroup.workloads", defaultValue: "Workloads") }
    static var sectionGroupInfra: String { string("sectionGroup.infra", defaultValue: "Infra") }
    static var sectionGroupSystem: String { string("sectionGroup.system", defaultValue: "System") }
    static var tint: String { string("common.tint", defaultValue: "Tint") }
    static var unread: String { string("common.unread", defaultValue: "Unread") }
    static var runtimeCore: String { string("runtime.core", defaultValue: "Core") }
    static var runtimeCoreSubtitle: String {
        string(
            "runtime.core.subtitle",
            defaultValue: "Runtime adapter used for create, recreate, imports, images, logs, stats, and system actions."
        )
    }
    static var containerRuntimeNotReady: String {
        string("runtime.notReady", defaultValue: "Container runtime is not ready.")
    }
    static var selectContainerBinary: String {
        string("cli.selectContainerBinary", defaultValue: "Select the `container` binary")
    }
    static var composeNoServicesWithImages: String {
        string("compose.noServicesWithImages", defaultValue: "No services with an image to import.")
    }
    static var composeWarnings: String {
        string(
            "compose.warnings",
            defaultValue: "Some compose keys were not translated; review each container before creating."
        )
    }
    static var chooseComposeFile: String {
        string("compose.chooseFile", defaultValue: "Choose a compose.yaml")
    }
    static var composeInvalid: String {
        string("error.compose.invalid", defaultValue: "Invalid compose file.")
    }
    static func composeInvalid(reason: String) -> String {
        string("error.compose.invalidWithReason", defaultValue: "Invalid compose file: \(reason)")
    }

    static var reconnectTerminal: String {
        string("terminal.reconnectTerminal", defaultValue: "Reconnect terminal")
    }

    static var appUpdateChecksUnavailable: String {
        string("updates.unavailable", defaultValue: "App update checks are unavailable in this build")
    }

    static var startService: String { string("service.start", defaultValue: "Start service") }
    static var stopService: String { string("service.stop", defaultValue: "Stop service") }
    static var restartService: String { string("service.restart", defaultValue: "Restart service") }

    static func lineCount(_ count: Int) -> String {
        string("streamConsole.lineCount", defaultValue: "\(count) lines")
    }

    static var paletteDockerHub: String { string("palette.dockerHub", defaultValue: "Docker Hub") }
    static var paletteLocalImages: String { string("palette.localImages", defaultValue: "Local images") }
    static var paletteSearchDockerHubPlaceholder: String {
        string("palette.searchDockerHubPlaceholder", defaultValue: "Search Docker Hub...")
    }
    static var paletteFilterLocalImagesPlaceholder: String {
        string("palette.filterLocalImagesPlaceholder", defaultValue: "Filter local images...")
    }
    static var paletteSearchOrRunPlaceholder: String {
        string("palette.searchOrRunPlaceholder", defaultValue: "Search or run a command...")
    }

    static var paletteCreateSubtitle: String { string("palette.subtitle.create", defaultValue: "create") }
    static var paletteActionSubtitle: String { string("palette.subtitle.action", defaultValue: "action") }
    static var paletteScopeSubtitle: String { string("palette.subtitle.scope", defaultValue: "scope") }
    static var paletteUpdatesSubtitle: String { string("palette.subtitle.updates", defaultValue: "updates") }
    static var paletteContainerSubtitle: String { string("palette.subtitle.container", defaultValue: "container") }
    static var paletteSettingsSubtitle: String { string("palette.subtitle.settings", defaultValue: "settings") }
    static var paletteToggleSubtitle: String { string("palette.subtitle.toggle", defaultValue: "toggle") }
    static var paletteAppearanceSubtitle: String { string("palette.subtitle.appearance", defaultValue: "appearance") }
    static var paletteLocalImageSubtitle: String { string("palette.subtitle.localImage", defaultValue: "local image") }
    static var paletteImageSubtitle: String { string("palette.subtitle.image", defaultValue: "image") }
    static var paletteImageTagSubtitle: String { string("palette.subtitle.imageTag", defaultValue: "image tag") }
    static var paletteVolumeSubtitle: String { string("palette.subtitle.volume", defaultValue: "volume") }
    static var paletteNetworkSubtitle: String { string("palette.subtitle.network", defaultValue: "network") }
    static var paletteBuiltInNetworkSubtitle: String {
        string("palette.subtitle.builtInNetwork", defaultValue: "built-in network")
    }
    static var palettePullNewerTagsSubtitle: String {
        string("palette.subtitle.pullNewerTags", defaultValue: "pull newer tags")
    }
    static var paletteDoesNotRecreateContainersSubtitle: String {
        string("palette.subtitle.doesNotRecreateContainers", defaultValue: "does not recreate containers")
    }
    static func paletteContainerCountSubtitle(_ count: Int) -> String {
        string("palette.subtitle.containerCount", defaultValue: "\(count) containers")
    }
    static func paletteTagCountSubtitle(_ count: Int) -> String {
        string("palette.subtitle.tagCount", defaultValue: "\(count) tag\(count == 1 ? "" : "s")")
    }

    static var paletteRunContainer: String { string("palette.action.runContainer", defaultValue: "Run a container") }
    static var paletteNewVolume: String { string("palette.action.newVolume", defaultValue: "New volume") }
    static var paletteNewNetwork: String { string("palette.action.newNetwork", defaultValue: "New network") }
    static var paletteImportCompose: String { string("palette.action.importCompose", defaultValue: "Import compose...") }
    static var paletteRegistryLogin: String { string("palette.action.registryLogin", defaultValue: "Registry login") }
    static var paletteSearchDockerHub: String { string("palette.action.searchDockerHub", defaultValue: "Search Docker Hub") }
    static var paletteSearchLocalImages: String { string("palette.action.searchLocalImages", defaultValue: "Search local images") }
    static var paletteRefresh: String { string("palette.action.refresh", defaultValue: "Refresh") }
    static var paletteCheckAppUpdates: String {
        string("palette.action.checkAppUpdates", defaultValue: "Check for app updates...")
    }
    static var paletteCheckAllImageUpdates: String {
        string("palette.action.checkAllImageUpdates", defaultValue: "Check all image updates")
    }
    static var paletteUpdateAllImages: String {
        string("palette.action.updateAllImages", defaultValue: "Update all images with available updates")
    }
    static var paletteCheckAllContainerImages: String {
        string("palette.action.checkAllContainerImages", defaultValue: "Check all container images for updates")
    }
    static var palettePullContainerImageUpdates: String {
        string("palette.action.pullContainerImageUpdates", defaultValue: "Pull available container image updates")
    }
    static var paletteLoadImageTar: String { string("palette.action.loadImageTar", defaultValue: "Load image tar...") }
    static var palettePruneImages: String { string("palette.action.pruneImages", defaultValue: "Prune images...") }
    static var paletteSystemLogs: String { string("palette.action.systemLogs", defaultValue: "System logs") }
    static var paletteUnavailable: String { string("palette.unavailable", defaultValue: "Unavailable") }

    static func paletteSettingsTitle(_ page: String) -> String {
        string("palette.settingsTitle", defaultValue: "\(page) Settings")
    }
    static var paletteShowAllContainers: String {
        string("palette.action.showAllContainers", defaultValue: "Show All Containers")
    }
    static var paletteShowRunningContainersOnly: String {
        string("palette.action.showRunningOnly", defaultValue: "Show Running Containers Only")
    }
    static var paletteHideMenuBarItem: String {
        string("palette.action.hideMenuBarItem", defaultValue: "Hide Menu Bar Item")
    }
    static var paletteShowMenuBarItem: String {
        string("palette.action.showMenuBarItem", defaultValue: "Show Menu Bar Item")
    }
    static var paletteHideCLIPreviews: String {
        string("palette.action.hideCLIPreviews", defaultValue: "Hide CLI Previews")
    }
    static var paletteShowCLIPreviews: String {
        string("palette.action.showCLIPreviews", defaultValue: "Show CLI Previews")
    }
    static var paletteHideInfoTips: String { string("palette.action.hideInfoTips", defaultValue: "Hide Info Tips") }
    static var paletteShowInfoTips: String { string("palette.action.showInfoTips", defaultValue: "Show Info Tips") }
    static func paletteRunImage(_ reference: String) -> String {
        string("palette.action.runImage", defaultValue: "Run \(reference)")
    }
    static func paletteCheckImageUpdate(_ reference: String) -> String {
        string("palette.action.checkImageUpdate", defaultValue: "Check update for \(reference)")
    }
    static func palettePullImageUpdate(_ reference: String) -> String {
        string("palette.action.pullImageUpdate", defaultValue: "Pull update for \(reference)")
    }
    static func paletteUseVolume(_ name: String) -> String {
        string("palette.action.useVolume", defaultValue: "Use volume \(name)")
    }
    static func paletteRunOnNetwork(_ name: String) -> String {
        string("palette.action.runOnNetwork", defaultValue: "Run on network \(name)")
    }
    static func paletteEditContainer(_ name: String) -> String {
        string("palette.action.editContainer", defaultValue: "Edit \(name)")
    }
    static func paletteUpdateContainerImage(_ name: String) -> String {
        string("palette.action.updateContainerImage", defaultValue: "Update image for \(name)")
    }
    static func paletteStopContainer(_ name: String) -> String {
        string("palette.action.stopContainer", defaultValue: "Stop \(name)")
    }
    static func paletteRestartContainer(_ name: String) -> String {
        string("palette.action.restartContainer", defaultValue: "Restart \(name)")
    }
    static func paletteStartContainer(_ name: String) -> String {
        string("palette.action.startContainer", defaultValue: "Start \(name)")
    }

    static var paletteKindAction: String { string("palette.kind.action", defaultValue: "Action") }
    static var paletteKindCreate: String { string("palette.kind.create", defaultValue: "Create") }
    static var paletteKindNavigate: String { string("palette.kind.navigate", defaultValue: "Navigate") }
    static var paletteKindSettings: String { string("palette.kind.settings", defaultValue: "Settings") }
    static var paletteKindToggle: String { string("palette.kind.toggle", defaultValue: "Toggle") }
    static var paletteKindImage: String { string("palette.kind.image", defaultValue: "Image") }
    static var paletteKindContainer: String { string("palette.kind.container", defaultValue: "Container") }
    static var paletteKindResource: String { string("palette.kind.resource", defaultValue: "Resource") }
    static var paletteKindSearch: String { string("palette.kind.search", defaultValue: "Search") }
    static var paletteSectionCreateSearch: String {
        string("palette.section.createSearch", defaultValue: "Create & Search")
    }
    static var paletteSectionContainers: String { string("palette.section.containers", defaultValue: "Containers") }
    static var paletteSectionImages: String { string("palette.section.images", defaultValue: "Images") }
    static var paletteSectionVolumesNetworks: String {
        string("palette.section.volumesNetworks", defaultValue: "Volumes & Networks")
    }
    static var paletteSectionActions: String { string("palette.section.actions", defaultValue: "Actions") }

    static var paletteCommands: String { string("palette.commands", defaultValue: "Commands") }
    static var paletteBackToCommands: String { string("palette.backToCommands", defaultValue: "Back to commands") }
    static func paletteSearchDockerHubFor(_ query: String) -> String {
        string("palette.searchDockerHubFor", defaultValue: "Search Docker Hub for \(query)")
    }
    static func paletteMatchesCount(_ count: Int) -> String {
        string("palette.matchesCount", defaultValue: "\(count) match\(count == 1 ? "" : "es")")
    }
    static func paletteLocalImagesCount(_ count: Int) -> String {
        string("palette.localImagesCount", defaultValue: "\(count) local image\(count == 1 ? "" : "s")")
    }
    static var paletteSearching: String { string("palette.searching", defaultValue: "Searching...") }
    static var paletteDockerHubUnreachable: String {
        string("palette.dockerHubUnreachable", defaultValue: "Couldn't reach Docker Hub")
    }
    static var palettePopularImages: String { string("palette.popularImages", defaultValue: "Popular images") }
    static func paletteResultsCount(_ count: Int) -> String {
        string("palette.resultsCount", defaultValue: "\(count) result\(count == 1 ? "" : "s")")
    }
    static func paletteImagesCount(_ count: Int) -> String {
        string("palette.imagesCount", defaultValue: "\(count) image\(count == 1 ? "" : "s")")
    }
    static var paletteNoMatches: String { string("palette.noMatches", defaultValue: "No matches") }
    static var paletteNoMatchesDescription: String {
        string("palette.noMatchesDescription", defaultValue: "Try a setting, image, container, network, or action.")
    }
    static var paletteSearchingDockerHub: String {
        string("palette.searchingDockerHub", defaultValue: "Searching Docker Hub...")
    }
    static var paletteCouldNotSearchDockerHub: String {
        string("palette.couldNotSearchDockerHub", defaultValue: "Couldn't search Docker Hub")
    }
    static var paletteTypeToSearchDockerHub: String {
        string("palette.typeToSearchDockerHub", defaultValue: "Type to search Docker Hub")
    }
    static func paletteNoImagesFound(_ query: String) -> String {
        string("palette.noImagesFound", defaultValue: "No images found for \"\(query)\"")
    }
    static var paletteKeyboardSelect: String { string("palette.keyboard.select", defaultValue: "Select") }
    static var paletteKeyboardRun: String { string("palette.keyboard.run", defaultValue: "Run") }
    static var paletteKeyboardClearScope: String { string("palette.keyboard.clearScope", defaultValue: "Clear scope") }
    static var paletteOfficialImage: String { string("palette.officialImage", defaultValue: "Official image") }

    static var notificationContainerRestartedTitle: String {
        string("notification.containerRestarted.title", defaultValue: "Container restarted")
    }
    static func notificationContainerRestartedBody(name: String, attempt: Int) -> String {
        attempt > 1
            ? string("notification.containerRestarted.bodyWithAttempt",
                     defaultValue: "\(name) was restarted (attempt \(attempt)).")
            : string("notification.containerRestarted.body", defaultValue: "\(name) was restarted.")
    }
    static var notificationContainerStoppedTitle: String {
        string("notification.containerStopped.title", defaultValue: "Container stopped")
    }
    static func notificationContainerStoppedBody(_ name: String) -> String {
        string("notification.containerStopped.body", defaultValue: "\(name) exited unexpectedly.")
    }
    static var notificationContainerUnhealthyTitle: String {
        string("notification.containerUnhealthy.title", defaultValue: "Container unhealthy")
    }
    static func notificationContainerUnhealthyBody(_ name: String) -> String {
        string("notification.containerUnhealthy.body", defaultValue: "\(name) failed its healthcheck.")
    }

    static func activityPullingImage(_ reference: String) -> String {
        string("activity.pullingImage", defaultValue: "Pulling \(reference)...")
    }

    static func restartedContainer(_ name: String, attempt: Int) -> String {
        string("container.restartedAttempt", defaultValue: "Restarted \(name) (attempt \(attempt))")
    }

    static func containerUnhealthy(_ name: String) -> String {
        string("container.unhealthy", defaultValue: "\(name) is unhealthy")
    }

    static func createdContainer(_ id: String) -> String {
        string("container.created", defaultValue: "Created \(id)")
    }

    static func loadedFile(_ name: String) -> String {
        string("file.loaded", defaultValue: "Loaded \(name)")
    }

    static func createdVolume(_ name: String) -> String {
        string("volume.created", defaultValue: "Created volume \(name)")
    }

    static func createdNetwork(_ name: String) -> String {
        string("network.created", defaultValue: "Created network \(name)")
    }

    static func copiedFileToHost(_ name: String) -> String {
        string("files.copiedToHost", defaultValue: "Copied \(name) to host")
    }

    static func copiedFileIntoContainer(_ name: String) -> String {
        string("files.copiedIntoContainer", defaultValue: "Copied \(name) into container")
    }

    static func copyFileFromContainerPanel(_ name: String) -> String {
        string("files.copyFromContainerPanel", defaultValue: "Copy \(name) from the container")
    }

    static func copyFileIntoContainerPanel(_ path: String) -> String {
        string("files.copyIntoContainerPanel", defaultValue: "Copy a file into \(path)")
    }

    static var chooseHostFileOrFolder: String {
        string("files.chooseHostFileOrFolder", defaultValue: "Choose a host file or folder")
    }

    static var historyCleared: String {
        string("history.cleared", defaultValue: "History cleared")
    }

    static var keptReadableLocalData: String {
        string("backup.keptReadableLocalData", defaultValue: "Kept readable local data")
    }

    static var exportedBackupAndReset: String {
        string("backup.exportedAndReset", defaultValue: "Exported backup and reset local state")
    }

    static var exportedBackup: String {
        string("backup.exported", defaultValue: "Exported backup")
    }

    static var importedBackup: String {
        string("backup.imported", defaultValue: "Imported backup")
    }

    static func cleanedStaleRows(_ count: Int) -> String {
        string("cleanup.cleanedStaleRows", defaultValue: "Cleaned \(count) stale row(s)")
    }

    static func savedTemplate(_ name: String) -> String {
        string("template.saved", defaultValue: "Saved template \"\(name)\"")
    }

    static func deletedImage(_ reference: String) -> String {
        string("image.deleted", defaultValue: "Deleted \(reference)")
    }

    static func saveImageTarArchive(_ reference: String) -> String {
        string("image.saveTarArchive", defaultValue: "Save \(reference) to a tar archive")
    }

    static func savedFile(_ name: String) -> String {
        string("file.saved", defaultValue: "Saved \(name)")
    }

    static var recommendedKernelInstalled: String {
        string("runtime.recommendedKernelInstalled", defaultValue: "Recommended kernel installed")
    }

    static var runSpecChooseImageToRun: String {
        string("runSpec.validation.chooseImage", defaultValue: "Choose an image to run.")
    }

    static var runSpecCompletePortMappings: String {
        string("runSpec.validation.completePortMappings", defaultValue: "Complete or remove partial port mappings.")
    }

    static var runSpecCompleteVolumeMounts: String {
        string("runSpec.validation.completeVolumeMounts", defaultValue: "Complete or remove partial volume mounts.")
    }

    static var runSpecEnvironmentNeedsNames: String {
        string("runSpec.validation.environmentNeedsNames", defaultValue: "Environment variables with values need names.")
    }

    static var runSpecMemoryFormat: String {
        string("runSpec.validation.memoryFormat", defaultValue: "Memory must use a value like 512M or 2G.")
    }

    static func adoptedImageDefaults(_ count: Int) -> String {
        string("imageDefaults.adopted", defaultValue: "Adopted \(count) image default\(count == 1 ? "" : "s")")
    }

    static var imageDefaultsAlreadyRepresented: String {
        string("imageDefaults.alreadyRepresented", defaultValue: "Image defaults are already represented")
    }

    static var noLocalImagesToCheck: String {
        string("updates.noLocalImagesToCheck", defaultValue: "No local images to check")
    }

    static var noContainerImagesToCheck: String {
        string("updates.noContainerImagesToCheck", defaultValue: "No container images to check")
    }

    static var noImageUpdatesAvailable: String {
        string("updates.noImageUpdatesAvailable", defaultValue: "No image updates available")
    }

    static var noContainerImageUpdatesAvailable: String {
        string("updates.noContainerImageUpdatesAvailable", defaultValue: "No container image updates available")
    }

    static var imageUpdateImageNoun: String {
        string("updates.imageNoun", defaultValue: "image")
    }

    static var imageUpdateContainerImageNoun: String {
        string("updates.containerImageNoun", defaultValue: "container image")
    }

    static var imageUpdateImagesTitle: String {
        string("updates.imagesTitle", defaultValue: "Images")
    }

    static var imageUpdateContainerImagesTitle: String {
        string("updates.containerImagesTitle", defaultValue: "Container images")
    }

    static func imageLocalDigestUnavailable(_ reference: String) -> String {
        string("updates.localDigestUnavailable", defaultValue: "Couldn't compare \(reference): local digest unavailable")
    }

    static func imageUpdateAvailable(_ reference: String) -> String {
        string("updates.imageUpdateAvailable", defaultValue: "Update available for \(reference)")
    }

    static func imageUpToDate(_ reference: String) -> String {
        string("updates.imageUpToDate", defaultValue: "\(reference) is up to date")
    }

    static func updatedImage(_ reference: String) -> String {
        string("updates.updatedImage", defaultValue: "Updated \(reference)")
    }

    static func updateSweepResult(available: Int, singular: String, pluralTitle: String) -> String {
        if available == 0 {
            return string("updates.sweepUpToDate", defaultValue: "\(pluralTitle) are up to date")
        }
        return string(
            "updates.sweepAvailable",
            defaultValue: "\(available) \(singular) update\(available == 1 ? "" : "s") available"
        )
    }

    static func updatedItems(_ count: Int, singular: String) -> String {
        string("updates.updatedItems", defaultValue: "Updated \(count) \(singular)\(count == 1 ? "" : "s")")
    }

    static func selectedCount(_ count: Int) -> String {
        string("selection.count", defaultValue: "\(count) selected")
    }

    static func customizeAccessibilityLabel(_ name: String) -> String {
        string("customize.accessibilityLabel", defaultValue: "Customize \(name)")
    }

    static func customizeImageStyleAccessibility(_ name: String) -> String {
        string("customize.imageStyleAccessibilityLabel", defaultValue: "Customize \(name) image style")
    }

    static func containerCardAccessibility(name: String, status: String) -> String {
        string("containerCard.accessibilityLabel", defaultValue: "\(name), \(status)")
    }

    static func removeScopeAccessibility(_ scope: String) -> String {
        string("palette.removeScopeAccessibilityLabel", defaultValue: "Remove \(scope) scope")
    }

    static func setDesignTintTitle(_ tintName: String) -> String {
        string("palette.setDesignTint", defaultValue: "Set app tint to \(tintName)")
    }
}

extension DesignTint {
    var localizedDisplayName: String {
        switch self {
        case .multicolor: return AppText.string("tint.multicolor", defaultValue: "App Accent")
        case .graphite: return AppText.string("tint.graphite", defaultValue: "Graphite")
        case .azure: return AppText.string("tint.azure", defaultValue: "Azure")
        case .teal: return AppText.string("tint.teal", defaultValue: "Teal")
        case .coral: return AppText.string("tint.coral", defaultValue: "Coral")
        case .indigo: return AppText.string("tint.indigo", defaultValue: "Indigo")
        case .green: return AppText.string("tint.green", defaultValue: "Green")
        case .amber: return AppText.string("tint.amber", defaultValue: "Amber")
        case .pink: return AppText.string("tint.pink", defaultValue: "Pink")
        }
    }

    var localizedSearchAliases: [String] {
        switch self {
        case .multicolor:
            return [
                AppText.string("tint.multicolor.alias.default", defaultValue: "default"),
                AppText.string("tint.multicolor.alias.appAccent", defaultValue: "app accent"),
                AppText.string("tint.multicolor.alias.system", defaultValue: "system"),
                AppText.string("tint.multicolor.alias.auto", defaultValue: "auto"),
                AppText.string("tint.multicolor.alias.rainbow", defaultValue: "rainbow"),
            ]
        case .graphite:
            return [
                AppText.string("tint.graphite.alias.gray", defaultValue: "gray"),
                AppText.string("tint.graphite.alias.grey", defaultValue: "grey"),
                AppText.string("tint.graphite.alias.slate", defaultValue: "slate"),
                AppText.string("tint.graphite.alias.charcoal", defaultValue: "charcoal"),
                AppText.string("tint.graphite.alias.silver", defaultValue: "silver"),
                AppText.string("tint.graphite.alias.neutral", defaultValue: "neutral"),
                AppText.string("tint.graphite.alias.mono", defaultValue: "mono"),
            ]
        case .azure:
            return [
                AppText.string("tint.azure.alias.blue", defaultValue: "blue"),
                AppText.string("tint.azure.alias.sky", defaultValue: "sky"),
                AppText.string("tint.azure.alias.ocean", defaultValue: "ocean"),
                AppText.string("tint.azure.alias.cobalt", defaultValue: "cobalt"),
            ]
        case .teal:
            return [
                AppText.string("tint.teal.alias.cyan", defaultValue: "cyan"),
                AppText.string("tint.teal.alias.aqua", defaultValue: "aqua"),
                AppText.string("tint.teal.alias.turquoise", defaultValue: "turquoise"),
                AppText.string("tint.teal.alias.mint", defaultValue: "mint"),
                AppText.string("tint.teal.alias.seafoam", defaultValue: "seafoam"),
            ]
        case .coral:
            return [
                AppText.string("tint.coral.alias.orange", defaultValue: "orange"),
                AppText.string("tint.coral.alias.salmon", defaultValue: "salmon"),
                AppText.string("tint.coral.alias.burnt", defaultValue: "burnt"),
                AppText.string("tint.coral.alias.terracotta", defaultValue: "terracotta"),
                AppText.string("tint.coral.alias.rust", defaultValue: "rust"),
            ]
        case .indigo:
            return [
                AppText.string("tint.indigo.alias.purple", defaultValue: "purple"),
                AppText.string("tint.indigo.alias.violet", defaultValue: "violet"),
                AppText.string("tint.indigo.alias.blurple", defaultValue: "blurple"),
                AppText.string("tint.indigo.alias.royal", defaultValue: "royal"),
            ]
        case .green:
            return [
                AppText.string("tint.green.alias.lime", defaultValue: "lime"),
                AppText.string("tint.green.alias.olive", defaultValue: "olive"),
                AppText.string("tint.green.alias.emerald", defaultValue: "emerald"),
                AppText.string("tint.green.alias.forest", defaultValue: "forest"),
                AppText.string("tint.green.alias.moss", defaultValue: "moss"),
            ]
        case .amber:
            return [
                AppText.string("tint.amber.alias.yellow", defaultValue: "yellow"),
                AppText.string("tint.amber.alias.gold", defaultValue: "gold"),
                AppText.string("tint.amber.alias.honey", defaultValue: "honey"),
                AppText.string("tint.amber.alias.mustard", defaultValue: "mustard"),
            ]
        case .pink:
            return [
                AppText.string("tint.pink.alias.magenta", defaultValue: "magenta"),
                AppText.string("tint.pink.alias.rose", defaultValue: "rose"),
                AppText.string("tint.pink.alias.fuchsia", defaultValue: "fuchsia"),
                AppText.string("tint.pink.alias.crimson", defaultValue: "crimson"),
                AppText.string("tint.pink.alias.hotPink", defaultValue: "hot pink"),
            ]
        }
    }
}

extension AppearanceMode {
    var localizedDisplayName: String {
        switch self {
        case .system: return AppText.string("appearance.system", defaultValue: "System")
        case .light: return AppText.string("appearance.light", defaultValue: "Light")
        case .dark: return AppText.string("appearance.dark", defaultValue: "Dark")
        }
    }
}

extension CardDensity {
    var localizedDisplayName: String {
        switch self {
        case .small: return AppText.string("cardDensity.small", defaultValue: "Small")
        case .medium: return AppText.string("cardDensity.medium", defaultValue: "Medium")
        case .large: return AppText.string("cardDensity.large", defaultValue: "Large")
        }
    }
}

extension ColorLayerBlendMode {
    var localizedDisplayName: String {
        switch self {
        case .normal: return AppText.string("blendMode.normal", defaultValue: "Normal")
        case .softLight: return AppText.string("blendMode.softLight", defaultValue: "Soft Light")
        case .overlay: return AppText.string("blendMode.overlay", defaultValue: "Overlay")
        case .multiply: return AppText.string("blendMode.multiply", defaultValue: "Multiply")
        case .screen: return AppText.string("blendMode.screen", defaultValue: "Screen")
        }
    }
}

extension WindowMaterial {
    var localizedDisplayName: String {
        switch self {
        case .glassClear: return AppText.string("windowMaterial.glassClear", defaultValue: "Glass (Clear)")
        case .glassRegular: return AppText.string("windowMaterial.glassRegular", defaultValue: "Glass (Regular)")
        case .fullScreenUI: return AppText.string("windowMaterial.fullScreenUI", defaultValue: "Full-screen UI (default)")
        case .underWindowBackground: return AppText.string("windowMaterial.underWindowBackground", defaultValue: "Under Window")
        case .underPageBackground: return AppText.string("windowMaterial.underPageBackground", defaultValue: "Under Page")
        case .windowBackground: return AppText.string("windowMaterial.windowBackground", defaultValue: "Window")
        case .contentBackground: return AppText.string("windowMaterial.contentBackground", defaultValue: "Content")
        case .sidebar: return AppText.string("windowMaterial.sidebar", defaultValue: "Sidebar")
        case .headerView: return AppText.string("windowMaterial.headerView", defaultValue: "Header")
        case .titlebar: return AppText.string("windowMaterial.titlebar", defaultValue: "Titlebar")
        case .sheet: return AppText.string("windowMaterial.sheet", defaultValue: "Sheet")
        case .popover: return AppText.string("windowMaterial.popover", defaultValue: "Popover")
        case .menu: return AppText.string("windowMaterial.menu", defaultValue: "Menu")
        case .selection: return AppText.string("windowMaterial.selection", defaultValue: "Selection")
        case .hudWindow: return AppText.string("windowMaterial.hudWindow", defaultValue: "HUD")
        case .toolTip: return AppText.string("windowMaterial.toolTip", defaultValue: "Tooltip")
        }
    }
}

extension GraphStyle {
    var localizedDisplayName: String {
        switch self {
        case .area: return AppText.string("graphStyle.area", defaultValue: "Area")
        case .line: return AppText.string("graphStyle.line", defaultValue: "Line")
        case .bar: return AppText.string("graphStyle.bar", defaultValue: "Bar")
        case .points: return AppText.string("graphStyle.points", defaultValue: "Points")
        case .multiLine: return AppText.string("graphStyle.multiLine", defaultValue: "Multi-Line")
        case .range: return AppText.string("graphStyle.range", defaultValue: "Range")
        case .scatter: return AppText.string("graphStyle.scatter", defaultValue: "Scatter")
        }
    }
}

extension WidgetInterpolation {
    var localizedDisplayName: String {
        switch self {
        case .linear: return AppText.string("widgetInterpolation.linear", defaultValue: "Linear")
        case .catmullRom: return AppText.string("widgetInterpolation.catmullRom", defaultValue: "Smooth")
        case .cardinal: return AppText.string("widgetInterpolation.cardinal", defaultValue: "Cardinal")
        case .monotone: return AppText.string("widgetInterpolation.monotone", defaultValue: "Monotone")
        case .stepStart: return AppText.string("widgetInterpolation.stepStart", defaultValue: "Step Start")
        case .stepCenter: return AppText.string("widgetInterpolation.stepCenter", defaultValue: "Step Center")
        case .stepEnd: return AppText.string("widgetInterpolation.stepEnd", defaultValue: "Step End")
        }
    }
}

extension RestartPolicy {
    var localizedDisplayName: String {
        switch self {
        case .no: return AppText.string("restartPolicy.no", defaultValue: "No")
        case .onFailure: return AppText.string("restartPolicy.onFailure", defaultValue: "On failure")
        case .always: return AppText.string("restartPolicy.always", defaultValue: "Always")
        }
    }
}
