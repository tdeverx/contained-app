import ContainedCore

enum StoragePresentation {
    static func title(_ action: Core.System.CleanupAction) -> String {
        switch action {
        case .compactRunningContainers: AppText.string("storage.compactContainers", defaultValue: "Compact running containers")
        case .compactRunningBuilder: AppText.string("storage.compactBuilder", defaultValue: "Compact running builder")
        case .resetBuilderCache: AppText.string("storage.resetBuilder", defaultValue: "Reset builder cache")
        case .danglingImages: AppText.string("storage.danglingImages", defaultValue: "Remove dangling images")
        case .unusedImages: AppText.string("storage.unusedImages", defaultValue: "Remove all unreferenced images")
        case .unusedVolumes: AppText.string("storage.unusedVolumes", defaultValue: "Remove unused volumes")
        case .unusedNetworks: AppText.string("storage.unusedNetworks", defaultValue: "Remove unused networks")
        case .stoppedContainers: AppText.string("storage.stoppedContainers", defaultValue: "Remove stopped containers")
        }
    }

    static func consequence(_ action: Core.System.CleanupAction) -> String {
        switch action {
        case .compactRunningContainers, .compactRunningBuilder:
            AppText.string("storage.compact.consequence", defaultValue: "Releases blocks already freed inside running sparse filesystems and writable named volumes. Does not delete guest files or start stopped containers. Actual reclaimed bytes cannot be predicted; old guest agents may need container recreation.")
        case .resetBuilderCache:
            AppText.string("storage.builder.consequence", defaultValue: "Stops the builder, interrupting any external builds, and deletes its VM and BuildKit cache. Application containers are preserved. Future builds recreate the builder and rebuild cached layers.")
        case .danglingImages, .unusedImages:
            AppText.string("storage.images.consequence", defaultValue: "Removes only these unreferenced local image names. Running and stopped container image references are protected. Future use may require a new pull. Shared layers mean an exact reclaim estimate is unavailable.")
        case .unusedNetworks:
            AppText.string("storage.networks.consequence", defaultValue: "Removes these unused custom network definitions. Referenced, default, and system networks are protected.")
        case .unusedVolumes:
            AppText.string("storage.volumes.consequence", defaultValue: "Permanently deletes these unreferenced volumes and their data, including anonymous volumes. Cannot be undone. Running and stopped container references are protected.")
        case .stoppedContainers:
            AppText.string("storage.containers.consequence", defaultValue: "Permanently deletes these stopped container definitions and writable root filesystems. Named volumes remain. Cannot be undone.")
        }
    }

    static func title(_ category: Core.System.StorageCategory) -> String {
        switch category {
        case .containers: AppText.string("storage.category.containers", defaultValue: "Container writable disks")
        case .imageSnapshots: AppText.string("storage.category.snapshots", defaultValue: "Unpacked image snapshots")
        case .imageContent: AppText.string("storage.category.content", defaultValue: "Image content blobs")
        case .volumes: AppText.string("storage.category.volumes", defaultValue: "Named volumes")
        case .builder: AppText.string("storage.category.builder", defaultValue: "Builder VM / cache")
        case .ingest: AppText.string("storage.category.ingest", defaultValue: "Snapshot ingest — report only")
        case .other: AppText.string("storage.category.other", defaultValue: "Other / unclassified — report only")
        }
    }
}
