import Foundation

public extension Core.Runtime {
enum SystemAction: String, CaseIterable, Sendable {
    case start
    case stop
}

internal protocol Module: Sendable {
    var descriptor: Core.Runtime.Descriptor { get }

    func locateCLI(override: String?) -> URL?
    func makeClient(runner: any Core.Command.Running) -> any RuntimeClient
    func readiness(cliURL: URL, runner: any Core.Command.Running) async -> Core.RuntimeReadiness
    func terminalInvocation(containerID: String, shell: String, cliURL: URL) -> Core.Command.Invocation
    func runPreview(for request: Core.Container.CreateRequest) -> [String]
    func buildPreview(context: String, tag: String?, dockerfile: String?,
                      buildArgs: [String: String], noCache: Bool,
                      platform: String?) -> [String]
    func networkCreatePreview(name: String, subnet: String?, internalOnly: Bool) -> [String]
    func volumeCreatePreview(name: String, size: String?) -> [String]
    func schemaProfile() -> Core.Schema.RuntimeProfile
}
}
