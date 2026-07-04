import Foundation
import ContainedCore

typealias KeyValue = Core.Container.KeyValue
typealias PortMap = Core.Container.Port
typealias VolumeMap = Core.Container.VolumeMount
typealias SocketMap = Core.Container.Socket

/// App-owned create/edit working state. Runtime-editable fields live in the Core schema document;
/// local-only presentation/automation fields stay beside it.
struct ContainerFormState: Codable {
    var document: Core.Schema.Document
    var personalization = Personalization()
    var healthCheck = Core.Container.HealthCheck()
    var linkedVolumePaths: [VolumeLinkedPath] = []
    var storageGroups: [StorageGroup] = []

    init(document: Core.Schema.Document,
         healthCheck: Core.Container.HealthCheck? = nil) {
        self.document = document
        if let healthCheck { self.healthCheck = healthCheck }
    }

    init(runtimeKind: Core.Runtime.Kind,
         healthCheck: Core.Container.HealthCheck? = nil) {
        self.init(document: .containerCreate(runtimeKind: runtimeKind),
                  healthCheck: healthCheck)
    }

    init(from config: Core.Container.Configuration) {
        self.document = Core.Schema.Document.containerEdit(from: config)
    }

    private enum CodingKeys: String, CodingKey {
        case document
        case personalization
        case healthCheck
        case linkedVolumePaths
        case storageGroups
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        document = try c.decode(Core.Schema.Document.self, forKey: .document)
        personalization = try c.decodeIfPresent(Personalization.self, forKey: .personalization) ?? Personalization()
        healthCheck = try c.decodeIfPresent(Core.Container.HealthCheck.self, forKey: .healthCheck) ?? Core.Container.HealthCheck()
        linkedVolumePaths = try c.decodeIfPresent([VolumeLinkedPath].self, forKey: .linkedVolumePaths) ?? []
        storageGroups = try c.decodeIfPresent([StorageGroup].self, forKey: .storageGroups) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(document, forKey: .document)
        try c.encode(personalization, forKey: .personalization)
        try c.encode(healthCheck, forKey: .healthCheck)
        try c.encode(linkedVolumePaths, forKey: .linkedVolumePaths)
        try c.encode(storageGroups, forKey: .storageGroups)
    }

    var definition: Core.Schema.Definition {
        Core.Schema.Definition.containerRunEdit(runtimeKind: effectiveRuntimeKind, operation: document.operation)
    }

    var runtimeKind: Core.Runtime.Kind? {
        get { document.runtimeKind }
        set {
            document.runtimeKind = newValue ?? AppRuntimeIntent.placeholderKind
            document.set(.runtimeKind, .string(document.runtimeKind.rawValue))
        }
    }

    var effectiveRuntimeKind: Core.Runtime.Kind { document.runtimeKind }

    var image: String {
        get { string(.imageReference) }
        set { setString(.imageReference, newValue) }
    }

    var platform: String {
        get { string(.imagePlatform) }
        set { setString(.imagePlatform, newValue) }
    }

    var imageOS: String {
        get { string(.imageOS) }
        set { setString(.imageOS, newValue) }
    }

    var imageArchitecture: String {
        get { string(.imageArchitecture) }
        set { setString(.imageArchitecture, newValue) }
    }

    var name: String {
        get { string(.containerName) }
        set { setString(.containerName, newValue) }
    }

    var command: String {
        get { strings(.processCommand).joined(separator: " ") }
        set { set(.processCommand, .commandLine(newValue.split(separator: " ").map(String.init))) }
    }

    var entrypoint: String {
        get { string(.processEntrypoint) }
        set { setString(.processEntrypoint, newValue) }
    }

    var detach: Bool {
        get { bool(.processDetach) }
        set { set(.processDetach, .bool(newValue)) }
    }

    var removeOnExit: Bool {
        get { bool(.processRemoveOnExit) }
        set { set(.processRemoveOnExit, .bool(newValue)) }
    }

    var interactive: Bool {
        get { bool(.processInteractive) }
        set { set(.processInteractive, .bool(newValue)) }
    }

    var tty: Bool {
        get { bool(.processTTY) }
        set { set(.processTTY, .bool(newValue)) }
    }

    var cpus: String {
        get { string(.resourcesCPULimit) }
        set { setString(.resourcesCPULimit, newValue) }
    }

    var memory: String {
        get { string(.resourcesMemoryLimit) }
        set { setString(.resourcesMemoryLimit, newValue) }
    }

    var env: [KeyValue] {
        get { document.keyValues(.environmentVariables, in: definition) }
        set { set(.environmentVariables, .keyValueList(newValue)) }
    }

    var envFiles: [String] {
        get { strings(.environmentFiles) }
        set { set(.environmentFiles, .stringList(newValue)) }
    }

    var ports: [PortMap] {
        get { document.ports(.networkPorts, in: definition) }
        set { set(.networkPorts, .portList(newValue)) }
    }

    var volumes: [VolumeMap] {
        get { document.volumes(.storageVolumes, in: definition) }
        set { set(.storageVolumes, .volumeList(newValue)) }
    }

    var mounts: [String] {
        get { strings(.storageMounts) }
        set { set(.storageMounts, .stringList(newValue)) }
    }

    var storageGroupsForEditing: [StorageGroup] {
        get {
            storageGroups.isEmpty
                ? StorageGroup.groups(from: volumes, linkedVolumePaths: linkedVolumePaths)
                : storageGroups
        }
        set {
            applyStorageGroups(newValue)
        }
    }

    var sockets: [SocketMap] {
        get { document.sockets(.networkSockets, in: definition) }
        set { set(.networkSockets, .socketList(newValue)) }
    }

    var labels: [KeyValue] {
        get { document.keyValues(.metadataLabels, in: definition) }
        set { set(.metadataLabels, .keyValueList(newValue)) }
    }

    var readOnly: Bool {
        get { bool(.securityReadOnlyRootFS) }
        set { set(.securityReadOnlyRootFS, .bool(newValue)) }
    }

    var useInit: Bool {
        get { bool(.securityUseInit) }
        set { set(.securityUseInit, .bool(newValue)) }
    }

    var rosetta: Bool {
        get { bool(.securityRosetta) }
        set { set(.securityRosetta, .bool(newValue)) }
    }

    var ssh: Bool {
        get { bool(.securitySSHAgent) }
        set { set(.securitySSHAgent, .bool(newValue)) }
    }

    var virtualization: Bool {
        get { bool(.securityVirtualization) }
        set { set(.securityVirtualization, .bool(newValue)) }
    }

    var restart: Core.Container.RestartPolicy {
        get { Core.Container.RestartPolicy(rawValue: string(.lifecycleRestartPolicy)) ?? .no }
        set { set(.lifecycleRestartPolicy, .enumeration(newValue.rawValue)) }
    }

    var workingDir: String {
        get { string(.processWorkingDirectory) }
        set { setString(.processWorkingDirectory, newValue) }
    }

    var user: String {
        get { string(.processUser) }
        set { setString(.processUser, newValue) }
    }

    var uid: String {
        get { string(.processUserID) }
        set { setString(.processUserID, newValue) }
    }

    var gid: String {
        get { string(.processGroupID) }
        set { setString(.processGroupID, newValue) }
    }

    var shmSize: String {
        get { string(.resourcesSharedMemorySize) }
        set { setString(.resourcesSharedMemorySize, newValue) }
    }

    var capAdd: [String] {
        get { strings(.securityCapabilitiesAdd) }
        set { set(.securityCapabilitiesAdd, .stringList(newValue)) }
    }

    var capDrop: [String] {
        get { strings(.securityCapabilitiesDrop) }
        set { set(.securityCapabilitiesDrop, .stringList(newValue)) }
    }

    var cidFile: String {
        get { string(.outputContainerIDFile) }
        set { setString(.outputContainerIDFile, newValue) }
    }

    var initImage: String {
        get { string(.imageInitReference) }
        set { setString(.imageInitReference, newValue) }
    }

    var kernel: String {
        get { string(.kernelPath) }
        set { setString(.kernelPath, newValue) }
    }

    var network: String {
        get { string(.networkName) }
        set { setString(.networkName, newValue) }
    }

    var noDNS: Bool {
        get { bool(.networkDNSDisabled) }
        set { set(.networkDNSDisabled, .bool(newValue)) }
    }

    var dns: [String] {
        get { strings(.networkDNSServers) }
        set { set(.networkDNSServers, .stringList(newValue)) }
    }

    var dnsDomain: String {
        get { string(.networkDNSDomain) }
        set { setString(.networkDNSDomain, newValue) }
    }

    var dnsSearch: [String] {
        get { strings(.networkDNSSearchDomains) }
        set { set(.networkDNSSearchDomains, .stringList(newValue)) }
    }

    var dnsOption: [String] {
        get { strings(.networkDNSOptions) }
        set { set(.networkDNSOptions, .stringList(newValue)) }
    }

    var tmpfs: [String] {
        get { strings(.storageTmpfs) }
        set { set(.storageTmpfs, .stringList(newValue)) }
    }

    var ulimits: [String] {
        get { strings(.processUlimits) }
        set { set(.processUlimits, .stringList(newValue)) }
    }

    var runtime: String {
        get { string(.runtimeHandler) }
        set { setString(.runtimeHandler, newValue) }
    }

    var scheme: String {
        get { string(.registryScheme) }
        set { set(.registryScheme, .enumeration(newValue)) }
    }

    var progress: String {
        get { string(.progressMode) }
        set { set(.progressMode, .enumeration(newValue)) }
    }

    var maxConcurrentDownloads: String {
        get { string(.imageMaxConcurrentDownloads) }
        set { setString(.imageMaxConcurrentDownloads, newValue) }
    }

    var validationIssues: [Core.Schema.ValidationIssue] {
        document.validationIssues(in: definition)
    }

    var validationMessages: [String] {
        validationIssues
            .filter { $0.severity == .error }
            .map(\.defaultMessage)
    }

    var warningMessages: [String] {
        validationIssues
            .filter { $0.severity == .warning }
            .map(\.defaultMessage)
    }

    var isRunnable: Bool { validationMessages.isEmpty }

    var normalizedImageReference: String {
        Self.normalizedImageReference(image)
    }

    static func normalizedImageReference(_ reference: String) -> String {
        let short = Format.shortImage(reference.trimmingCharacters(in: .whitespaces))
        let nameStart = short.lastIndex(of: "/").map { short.index(after: $0) } ?? short.startIndex
        let namePart = short[nameStart...]
        if namePart.contains(":") || namePart.contains("@") { return short }
        return short + ":latest"
    }

    @discardableResult
    mutating func adoptImageDefaults(from defaults: Core.Container.ImageDefaults) -> Int {
        var applied = 0
        if command.trimmingCharacters(in: .whitespaces).isEmpty, !defaults.command.isEmpty {
            command = defaults.command.joined(separator: " ")
            applied += 1
        }
        if entrypoint.trimmingCharacters(in: .whitespaces).isEmpty, !defaults.entrypoint.isEmpty {
            entrypoint = defaults.entrypoint.joined(separator: " ")
            applied += 1
        }
        if workingDir.trimmingCharacters(in: .whitespaces).isEmpty,
           let workingDirValue = defaults.workingDirectory,
           !workingDirValue.isEmpty {
            workingDir = workingDirValue
            applied += 1
        }
        if user.trimmingCharacters(in: .whitespaces).isEmpty,
           let userValue = defaults.user,
           !userValue.isEmpty {
            user = userValue
            applied += 1
        }
        let existingEnvKeys = Set(env.map(\.key))
        var updatedEnv = env
        for entry in defaults.environment {
            guard entry.isValid, !existingEnvKeys.contains(entry.key) else { continue }
            updatedEnv.append(entry)
            applied += 1
        }
        env = updatedEnv
        return applied
    }

    var hasGeneralOptions: Bool {
        hasValues(in: [.runtime, .essentials])
    }

    var hasResourceOptions: Bool {
        hasValues(in: [.resources])
    }

    var hasNetworkingOptions: Bool {
        hasValues(in: [.networking])
    }

    var hasStorageOptions: Bool {
        hasValues(in: [.storage]) || !linkedVolumePaths.isEmpty || !storageGroups.isEmpty
    }

    var hasEnvironmentOptions: Bool {
        hasValues(in: [.environment])
    }

    var hasPersonalizationOptions: Bool {
        !personalization.isDefault
    }

    var hasAppManagedOptions: Bool {
        restart != .no || healthCheck.isActive
    }

    var hasAdvancedOptions: Bool {
        hasValues(in: [.process, .security, .imageFetch, .metadata, .dockerCompose])
    }

    var hasUnsupportedRuntimeValues: Bool {
        definition.fields.contains { field in
            field.support(for: effectiveRuntimeKind).state == .disabled &&
            !(document.value(field.path, in: definition) ?? field.defaultValue).isEmpty
        }
    }

    private func hasValues(in sections: Set<Core.Schema.FieldSection>) -> Bool {
        definition.fields.contains { field in
            sections.contains(field.section) &&
            field.path != .imageReference &&
            field.path != .processDetach &&
            field.path != .runtimeKind &&
            !(document.value(field.path, in: definition) ?? field.defaultValue).isEmpty
        }
    }

    private func string(_ path: Core.Field.Path) -> String {
        document.string(path, in: definition)
    }

    private func bool(_ path: Core.Field.Path) -> Bool {
        document.bool(path, in: definition)
    }

    private func strings(_ path: Core.Field.Path) -> [String] {
        document.strings(path, in: definition)
    }

    private mutating func setString(_ path: Core.Field.Path, _ value: String) {
        set(path, .string(value))
    }

    private mutating func set(_ path: Core.Field.Path, _ value: Core.Schema.Value) {
        document.set(path, value)
    }
}

extension ContainerFormState {
    mutating func applyStorageGroups(_ groups: [StorageGroup]) {
        storageGroups = groups
        volumes = StorageGroup.volumeMounts(from: groups)
        linkedVolumePaths = StorageGroup.linkedPaths(from: groups)
    }

    mutating func applyLinkedVolumePaths(_ links: [VolumeLinkedPath]) {
        linkedVolumePaths = links.map { link in
            guard let volume = parentVolume(for: link) else { return link }
            return link.attached(to: volume)
        }
        storageGroups = StorageGroup.groups(from: volumes, linkedVolumePaths: linkedVolumePaths)
    }

    var linkedVolumePathsForPersistence: [VolumeLinkedPath] {
        linkedVolumePaths.compactMap { link in
            guard let volume = parentVolume(for: link) else { return nil }
            return link.attached(to: volume)
        }
    }

    func materializedDocumentForRun() -> Core.Schema.Document {
        var materialized = document
        var materializedVolumes = volumes
        for link in linkedVolumePaths where link.isValid {
            guard let parent = parentVolume(for: link),
                  !link.resolvedLinkPath(in: parent).isEmpty else { continue }
            appendUnique(link.hostMount(), to: &materializedVolumes)
        }
        materialized.set(.storageVolumes, .volumeList(materializedVolumes))
        return materialized
    }

    func volumeLinkPlan() -> VolumeLinkPlan? {
        var mountedVolumes: [Core.Container.VolumeMount] = []
        var links: [(linkPath: String, targetPath: String)] = []
        for link in linkedVolumePaths where link.isValid {
            guard let parent = parentVolume(for: link) else { continue }
            let resolvedLinkPath = link.resolvedLinkPath(in: parent)
            guard !resolvedLinkPath.isEmpty else { continue }
            var setupVolume = parent
            setupVolume.readOnly = false
            appendUnique(setupVolume, to: &mountedVolumes)
            appendUnique(link.hostMount(), to: &mountedVolumes)
            links.append((linkPath: resolvedLinkPath, targetPath: link.mountTarget))
        }
        guard !links.isEmpty else { return nil }
        return VolumeLinkPlan(runtimeKind: effectiveRuntimeKind,
                              image: image,
                              platform: platform,
                              os: imageOS,
                              architecture: imageArchitecture,
                              volumeMounts: mountedVolumes,
                              links: links)
    }

    private func parentVolume(for link: VolumeLinkedPath) -> Core.Container.VolumeMount? {
        volumes.first { $0.isValid && link.isAttached(to: $0) }
    }

    private func appendUnique(_ volume: Core.Container.VolumeMount,
                              to volumes: inout [Core.Container.VolumeMount]) {
        guard volume.isValid else { return }
        guard !volumes.contains(where: { existing in
            existing.source == volume.source &&
            existing.target == volume.target &&
            existing.readOnly == volume.readOnly
        }) else { return }
        volumes.append(volume)
    }
}
