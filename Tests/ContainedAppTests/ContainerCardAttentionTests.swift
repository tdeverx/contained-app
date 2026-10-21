import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Container card attention")
struct ContainerCardAttentionTests {
    @Test func idleRecoveryTakesPriorityAndUpdatesUseDownload() {
        for state in [Core.Image.ContainerUpdateState.unknown, .current, .updateReady, .updateAvailable] {
            #expect(ContainerCardAttention.resolve(update: state, requiresRecovery: true, isBusy: false) == .recovery)
            #expect(ContainerCardAttention.resolve(update: state, requiresRecovery: false, isBusy: false) == (state.requiresUpdate ? .update : nil))
        }
        #expect(ContainerCardAttention.recovery.systemImage == "exclamationmark.triangle.fill")
        #expect(ContainerCardAttention.update.systemImage == "arrow.down.circle")
    }

    @Test func inFlightWorkDoesNotShowAttentionUntilIdleAndStillPending() {
        for state in [Core.Image.ContainerUpdateState.unknown, .current, .updateReady, .updateAvailable] {
            for requiresRecovery in [false, true] {
                #expect(ContainerCardAttention.resolve(update: state, requiresRecovery: requiresRecovery, isBusy: true) == nil)
            }
        }
        #expect(ContainerCardAttention.resolve(update: .current, requiresRecovery: true, isBusy: false) == .recovery)
        #expect(ContainerCardAttention.resolve(update: .current, requiresRecovery: false, isBusy: false) == nil)
    }
}
