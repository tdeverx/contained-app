import Foundation
import ContainedCore
import SwiftData

/// A saved container recipe — a named `ContainerFormState`, persisted (encoded) so it can prefill the edit form
/// later. Stored in the same SwiftData container as the history models.
@Model
final class Template {
    var name: String
    var createdAt: Date
    var specData: Data

    init(name: String, spec: ContainerFormState, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
        self.specData = (try? JSONEncoder().encode(spec)) ?? Data()
    }

    init(snapshot: TemplateSnapshot) {
        self.name = snapshot.name
        self.createdAt = snapshot.createdAt
        self.specData = (try? JSONEncoder().encode(snapshot.spec)) ?? Data()
    }

    var spec: ContainerFormState? {
        let decoder = JSONDecoder()
        if let state = try? decoder.decode(ContainerFormState.self, from: specData) {
            return state
        }
        return (try? decoder.decode(LegacyContainerTemplateSpec.self, from: specData))?.formState
    }
}

private struct LegacyContainerTemplateSpec: Decodable {
    var runtimeKind: Core.Runtime.Kind? = .appleContainer
    var image = ""
    var platform = ""
    var name = ""
    var command = ""
    var entrypoint = ""
    var detach = true
    var removeOnExit = false
    var interactive = false
    var tty = false
    var cpus = ""
    var memory = ""
    var env: [KeyValue] = []
    var envFiles: [String] = []
    var ports: [PortMap] = []
    var volumes: [VolumeMap] = []
    var mounts: [String] = []
    var sockets: [SocketMap] = []
    var labels: [KeyValue] = []
    var readOnly = false
    var useInit = false
    var rosetta = false
    var ssh = false
    var virtualization = false
    var restart: Core.Container.RestartPolicy = .no
    var workingDir = ""
    var user = ""
    var uid = ""
    var gid = ""
    var shmSize = ""
    var capAdd: [String] = []
    var capDrop: [String] = []
    var cidFile = ""
    var initImage = ""
    var kernel = ""
    var network = ""
    var noDNS = false
    var dns: [String] = []
    var dnsDomain = ""
    var dnsSearch: [String] = []
    var dnsOption: [String] = []
    var tmpfs: [String] = []
    var ulimits: [String] = []
    var runtime = ""
    var scheme = ""
    var progress = ""
    var maxConcurrentDownloads = ""
    var personalization = Personalization()
    var healthCheck = Core.Container.HealthCheck()

    private enum CodingKeys: String, CodingKey {
        case runtimeKind
        case image
        case platform
        case name
        case command
        case entrypoint
        case detach
        case removeOnExit
        case interactive
        case tty
        case cpus
        case memory
        case env
        case envFiles
        case ports
        case volumes
        case mounts
        case sockets
        case labels
        case readOnly
        case useInit
        case rosetta
        case ssh
        case virtualization
        case restart
        case workingDir
        case user
        case uid
        case gid
        case shmSize
        case capAdd
        case capDrop
        case cidFile
        case initImage
        case kernel
        case network
        case noDNS
        case dns
        case dnsDomain
        case dnsSearch
        case dnsOption
        case tmpfs
        case ulimits
        case runtime
        case scheme
        case progress
        case maxConcurrentDownloads
        case personalization
        case healthCheck
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runtimeKind = try container.decodeIfPresent(Core.Runtime.Kind.self, forKey: .runtimeKind) ?? .appleContainer
        image = try container.decodeIfPresent(String.self, forKey: .image) ?? ""
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        command = try container.decodeIfPresent(String.self, forKey: .command) ?? ""
        entrypoint = try container.decodeIfPresent(String.self, forKey: .entrypoint) ?? ""
        detach = try container.decodeIfPresent(Bool.self, forKey: .detach) ?? true
        removeOnExit = try container.decodeIfPresent(Bool.self, forKey: .removeOnExit) ?? false
        interactive = try container.decodeIfPresent(Bool.self, forKey: .interactive) ?? false
        tty = try container.decodeIfPresent(Bool.self, forKey: .tty) ?? false
        cpus = try container.decodeIfPresent(String.self, forKey: .cpus) ?? ""
        memory = try container.decodeIfPresent(String.self, forKey: .memory) ?? ""
        env = try container.decodeIfPresent([KeyValue].self, forKey: .env) ?? []
        envFiles = try container.decodeIfPresent([String].self, forKey: .envFiles) ?? []
        ports = try container.decodeIfPresent([PortMap].self, forKey: .ports) ?? []
        volumes = try container.decodeIfPresent([VolumeMap].self, forKey: .volumes) ?? []
        mounts = try container.decodeIfPresent([String].self, forKey: .mounts) ?? []
        sockets = try container.decodeIfPresent([SocketMap].self, forKey: .sockets) ?? []
        labels = try container.decodeIfPresent([KeyValue].self, forKey: .labels) ?? []
        readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly) ?? false
        useInit = try container.decodeIfPresent(Bool.self, forKey: .useInit) ?? false
        rosetta = try container.decodeIfPresent(Bool.self, forKey: .rosetta) ?? false
        ssh = try container.decodeIfPresent(Bool.self, forKey: .ssh) ?? false
        virtualization = try container.decodeIfPresent(Bool.self, forKey: .virtualization) ?? false
        restart = try container.decodeIfPresent(Core.Container.RestartPolicy.self, forKey: .restart) ?? .no
        workingDir = try container.decodeIfPresent(String.self, forKey: .workingDir) ?? ""
        user = try container.decodeIfPresent(String.self, forKey: .user) ?? ""
        uid = try container.decodeIfPresent(String.self, forKey: .uid) ?? ""
        gid = try container.decodeIfPresent(String.self, forKey: .gid) ?? ""
        shmSize = try container.decodeIfPresent(String.self, forKey: .shmSize) ?? ""
        capAdd = try container.decodeIfPresent([String].self, forKey: .capAdd) ?? []
        capDrop = try container.decodeIfPresent([String].self, forKey: .capDrop) ?? []
        cidFile = try container.decodeIfPresent(String.self, forKey: .cidFile) ?? ""
        initImage = try container.decodeIfPresent(String.self, forKey: .initImage) ?? ""
        kernel = try container.decodeIfPresent(String.self, forKey: .kernel) ?? ""
        network = try container.decodeIfPresent(String.self, forKey: .network) ?? ""
        noDNS = try container.decodeIfPresent(Bool.self, forKey: .noDNS) ?? false
        dns = try container.decodeIfPresent([String].self, forKey: .dns) ?? []
        dnsDomain = try container.decodeIfPresent(String.self, forKey: .dnsDomain) ?? ""
        dnsSearch = try container.decodeIfPresent([String].self, forKey: .dnsSearch) ?? []
        dnsOption = try container.decodeIfPresent([String].self, forKey: .dnsOption) ?? []
        tmpfs = try container.decodeIfPresent([String].self, forKey: .tmpfs) ?? []
        ulimits = try container.decodeIfPresent([String].self, forKey: .ulimits) ?? []
        runtime = try container.decodeIfPresent(String.self, forKey: .runtime) ?? ""
        scheme = try container.decodeIfPresent(String.self, forKey: .scheme) ?? ""
        progress = try container.decodeIfPresent(String.self, forKey: .progress) ?? ""
        maxConcurrentDownloads = try container.decodeIfPresent(String.self, forKey: .maxConcurrentDownloads) ?? ""
        personalization = try container.decodeIfPresent(Personalization.self, forKey: .personalization) ?? Personalization()
        healthCheck = try container.decodeIfPresent(Core.Container.HealthCheck.self, forKey: .healthCheck) ?? Core.Container.HealthCheck()
    }

    var formState: ContainerFormState {
        var request = Core.Container.CreateRequest()
        request.runtimeKind = runtimeKind ?? .appleContainer
        request.image = image
        request.platform = platform
        request.name = name
        request.command = command.split(separator: " ").map(String.init)
        request.entrypoint = entrypoint
        request.detach = detach
        request.removeOnExit = removeOnExit
        request.interactive = interactive
        request.tty = tty
        request.cpus = cpus
        request.memory = memory
        request.env = env
        request.envFiles = envFiles
        request.ports = ports
        request.volumes = volumes
        request.mounts = mounts
        request.sockets = sockets
        request.labels = labels
        request.readOnly = readOnly
        request.useInit = useInit
        request.rosetta = rosetta
        request.ssh = ssh
        request.virtualization = virtualization
        request.restart = restart
        request.workingDir = workingDir
        request.user = user
        request.uid = uid
        request.gid = gid
        request.shmSize = shmSize
        request.capAdd = capAdd
        request.capDrop = capDrop
        request.cidFile = cidFile
        request.initImage = initImage
        request.kernel = kernel
        request.network = network
        request.noDNS = noDNS
        request.dns = dns
        request.dnsDomain = dnsDomain
        request.dnsSearch = dnsSearch
        request.dnsOption = dnsOption
        request.tmpfs = tmpfs
        request.ulimits = ulimits
        request.runtime = runtime
        request.scheme = scheme
        request.progress = progress
        request.maxConcurrentDownloads = maxConcurrentDownloads

        var state = ContainerFormState(document: .containerCreate(from: request), healthCheck: healthCheck)
        state.personalization = personalization
        return state
    }
}

struct TemplateSnapshot: Codable {
    var name: String
    var createdAt: Date
    var spec: ContainerFormState

    init?(_ template: Template) {
        guard let spec = template.spec else { return nil }
        self.name = template.name
        self.createdAt = template.createdAt
        self.spec = spec
    }
}

/// A few ready-to-run starters offered alongside the user's saved templates.
enum BuiltinTemplate {
    static let all: [(name: String, symbol: String, spec: ContainerFormState)] = [
        make("Postgres", symbol: "cylinder.split.1x2", image: "postgres:16",
             ports: [("5432", "5432")], env: [("POSTGRES_PASSWORD", "postgres")]),
        make("Redis", symbol: "bolt.horizontal", image: "redis:7", ports: [("6379", "6379")]),
        make("nginx", symbol: "globe", image: "nginx:latest", ports: [("8080", "80")]),
        make("Alpine (shell)", symbol: "terminal", image: "alpine:latest", command: "sleep infinity"),
    ]

    private static func make(_ name: String, symbol: String, image: String,
                             command: String = "", ports: [(String, String)] = [],
                             env: [(String, String)] = []) -> (name: String, symbol: String, spec: ContainerFormState) {
        var spec = ContainerFormState()
        spec.image = image
        spec.command = command
        spec.ports = ports.map { PortMap(hostPort: $0.0, containerPort: $0.1, proto: "tcp") }
        spec.env = env.map { KeyValue(key: $0.0, value: $0.1) }
        return (name, symbol, spec)
    }
}
