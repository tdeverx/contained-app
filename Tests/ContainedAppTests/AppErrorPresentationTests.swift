import ContainedCore
import Testing
@testable import ContainedApp

@Suite("App error presentation")
struct AppErrorPresentationTests {
    @Test func composeErrorsUseAppOwnedCopy() {
        #expect(AppErrorPresentation.message(for: Core.Compose.Error.invalid("")) == "Invalid compose file.")
        #expect(
            AppErrorPresentation.message(for: Core.Compose.Error.invalid("Top level is not a mapping."))
                == "Invalid compose file: Top level is not a mapping."
        )
    }
}
