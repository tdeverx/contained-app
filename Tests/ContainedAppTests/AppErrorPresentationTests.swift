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

    @Test func persistedCommandFailureSummaryExcludesRuntimeDetail() {
        let secret = "token-SENTINEL"
        let path = "/private/SENTINEL/config"
        let error = Core.Command.Error.nonZeroExit(
            code: 17,
            stderr: "authentication failed for \(secret)",
            command: "run --env API_TOKEN=\(secret) --volume \(path):/config"
        )

        let immediate = AppErrorPresentation.message(for: error)
        let activity = AppErrorPresentation.activityMessage("Container run failed", error: error)
        let summary = AppErrorPresentation.packageSummary(for: error) ?? ""

        #expect(immediate.contains(secret))
        #expect(activity.contains("exitCode=17"))
        #expect(!activity.contains(secret))
        #expect(!activity.contains(path))
        #expect(!activity.contains("API_TOKEN"))
        #expect(!summary.contains(secret))
        #expect(!summary.contains(path))
    }
}
