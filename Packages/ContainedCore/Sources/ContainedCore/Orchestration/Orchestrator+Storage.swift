import Foundation

public extension Core.Orchestrator {
    func storageAnalysis(runtimeKind: Core.Runtime.Kind) async throws -> Core.System.StorageAnalysis {
        try await requireRuntime(runtimeKind, capability: .storageManagement,
                                 as: (any RuntimeStorageClient).self).storageAnalysis()
    }

    func storageCapacity(runtimeKind: Core.Runtime.Kind) async throws -> Core.System.StorageCapacity? {
        try await requireRuntime(runtimeKind, capability: .storageManagement,
                                 as: (any RuntimeStorageClient).self).storageCapacity()
    }

    func cleanupPlan(_ action: Core.System.CleanupAction, runtimeKind: Core.Runtime.Kind,
                     automatic: Bool = false, afterResourceID: String? = nil) async throws -> Core.System.CleanupPlan {
        if automatic, !action.automaticAllowed { throw Core.System.StorageError.unsupportedAutomation }
        return try await requireRuntime(runtimeKind, capability: .storageManagement,
                                        as: (any RuntimeStorageClient).self)
            .cleanupPlan(action, resourceLimit: automatic ? 16 : nil, afterResourceID: automatic ? afterResourceID : nil)
    }

    func executeCleanup(_ plan: Core.System.CleanupPlan) async throws -> Core.System.CleanupResult {
        try await requireRuntime(plan.runtimeKind, capability: .storageManagement,
                                 as: (any RuntimeStorageClient).self).executeCleanup(plan)
    }
}
