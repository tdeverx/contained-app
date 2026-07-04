import Foundation
@testable import ContainedCore

func appTestOrchestrator(runner: any Core.Command.Running,
                         cliURL: URL? = nil,
                         runtimeKind: Core.Runtime.Kind) -> Core.Orchestrator {
    var cliURLs: [Core.Runtime.Kind: URL] = [:]
    if let cliURL {
        cliURLs[runtimeKind] = cliURL
    }
    return appTestOrchestrator(runners: [runtimeKind: runner], cliURLs: cliURLs)
}

func appTestOrchestrator(runners: [Core.Runtime.Kind: any Core.Command.Running],
                         cliURLs: [Core.Runtime.Kind: URL] = [:]) -> Core.Orchestrator {
    let availableModules: [Core.Runtime.Kind: any Core.Runtime.Module] = [
        .appleContainer: AppleContainerRuntimeModule(),
        .docker: DockerRuntimeModule(),
    ]
    var selectedModules: [Core.Runtime.Kind: any Core.Runtime.Module] = [:]
    var clients: [Core.Runtime.Kind: any RuntimeClient] = [:]

    for (kind, runner) in runners {
        guard let module = availableModules[kind] else {
            preconditionFailure("No app test runtime module for \(kind.rawValue)")
        }
        selectedModules[kind] = module
        clients[kind] = module.makeClient(runner: runner)
    }

    let resolvedURLs = Dictionary(uniqueKeysWithValues: clients.keys.map { kind in
        let executableName = selectedModules[kind]?.descriptor.executableName ?? kind.rawValue
        return (kind, cliURLs[kind] ?? URL(fileURLWithPath: "/usr/bin/\(executableName)"))
    })
    return Core.Orchestrator(cliURLs: resolvedURLs, runtimes: clients, modules: selectedModules)
}
