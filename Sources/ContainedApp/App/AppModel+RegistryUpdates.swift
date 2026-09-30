import Foundation
import ContainedCore

extension AppModel {
    var registryUpdateFailures: [Core.Registry.UpdateRetryPolicy.Entry] {
        registryRetryPolicy.entries.values.sorted { $0.id < $1.id }
    }

    func registryCredentialsChanged(host: String, runtimeKind: Core.Runtime.Kind) {
        registryRetryPolicy.reset(host: host, runtimeKind: runtimeKind)
    }

    func retryRegistryUpdates(_ entry: Core.Registry.UpdateRetryPolicy.Entry) async {
        registryCredentialsChanged(host: entry.host, runtimeKind: entry.runtimeKind)
        for reference in entry.references {
            await checkImageUpdate(reference, runtimeKind: entry.runtimeKind, notify: false)
        }
    }

    func registryFailureMessage(host: String, kind: Core.Registry.UpdateFailureKind) -> String {
        switch kind {
        case .unauthorized:
            AppText.string("registry.updates.unauthorized", defaultValue: "\(host): authentication required. Refresh login in Settings → Registries, then retry. [unauthorized]")
        case .tokenUnavailable:
            AppText.string("registry.updates.tokenUnavailable", defaultValue: "\(host): authentication token unavailable. Check login and Keychain access in Settings → Registries, then retry. [tokenUnavailable]")
        case .rateLimited:
            AppText.string("registry.updates.rateLimited", defaultValue: "\(host): registry rate limit reached. Update checks will retry later. [rateLimited]")
        case .network:
            AppText.string("registry.updates.network", defaultValue: "\(host): registry could not be reached. Check connectivity, then retry. [network]")
        case .notFound:
            AppText.string("registry.updates.notFound", defaultValue: "\(host): image manifest not found. Check the repository and tag. [notFound]")
        case .invalidResponse:
            AppText.string("registry.updates.invalidResponse", defaultValue: "\(host): registry returned an unexpected response. Update checks will retry later. [invalidResponse]")
        }
    }
}
