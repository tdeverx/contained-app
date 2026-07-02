import ContainedCore
import Testing
@testable import ContainedApp

@Suite("App error presentation")
struct AppErrorPresentationTests {
    @Test func composeErrorsUseAppOwnedCopy() {
        #expect(AppErrorPresentation.message(for: ComposeError.invalid("")) == "Invalid compose file.")
        #expect(
            AppErrorPresentation.message(for: ComposeError.invalid("Top level is not a mapping."))
                == "Invalid compose file: Top level is not a mapping."
        )
    }
}
