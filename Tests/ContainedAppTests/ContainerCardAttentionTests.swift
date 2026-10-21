import Testing
import ContainedCore
@testable import ContainedApp

@Suite("Container card attention")
struct ContainerCardAttentionTests {
    @Test func recoveryTakesPriorityAndUpdatesUseCaution() {
        for state in [Core.Image.ContainerUpdateState.unknown, .current, .updateReady, .updateAvailable] {
            #expect(ContainerCardAttention.resolve(update: state, requiresRecovery: true) == .recovery)
            #expect(ContainerCardAttention.resolve(update: state, requiresRecovery: false) == (state.requiresUpdate ? .update : nil))
        }
        #expect(ContainerCardAttention.recovery.systemImage == "exclamationmark.triangle.fill")
        #expect(ContainerCardAttention.update.systemImage == "exclamationmark.triangle")
    }
}
