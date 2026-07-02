# ContainedCore

`ContainedCore` is Contained's standalone backend/orchestration package. It
contains no SwiftUI, app state, Sparkle, SwiftTerm, localization resources,
persistence, or presentation policy.

## Owns

- `Core.Orchestrator`, the app-facing backend facade.
- `Core.Runtime` descriptors, capabilities, selected-runtime checks, and typed
  unsupported-operation errors.
- `Core.Container` semantic create/edit/import/export models.
- `Core.Compose` import/export plans and Compose YAML parsing/writing internals.
- `Core.Command` command previews, command execution, and host invocations.
- Core-internal runtime adapters, beginning with Apple container.
- Metrics, stats normalization, decoded resources, registry helpers, and
  display-neutral package errors.
- A separate `ContainedCoreFixtures` product for deterministic semantic samples
  used by tests, previews, and sandbox-only targets.

## Does Not Own

- Localized strings or user-facing copy.
- SwiftUI views, app routing, settings, stores, or Activity presentation.
- UI/UX packages, Sparkle, SwiftTerm, SwiftData, or app persistence.

## Runtime Example

```swift
import ContainedCore

let result = await Core.Orchestrator.bootstrap(
    configuration: Core.Configuration(
        appleContainer: .init(cliPathOverride: nil)
    )
)

let core: Core.Orchestrator
switch result {
case .ready(let orchestrator, _, _),
     .unsupported(let orchestrator, _, _):
    core = orchestrator
case .cliMissing:
    throw Core.Error.Command.cliNotFound(searched: ["PATH"])
}

let descriptors = core.availableRuntimeDescriptors
```

## Create Preview Example

```swift
var request = Core.Container.CreateRequest()
request.runtimeKind = .appleContainer
request.name = "web"
request.image = "nginx:latest"
request.ports = [.init(hostPort: "8080", containerPort: "80")]

let preview = try core.previewCreateCommand(for: request)
let command = preview.command
```

## Compose Example

```swift
let project = try Core.Compose.parse(composeText, projectName: "stack")
let plan = try core.translateCompose(project, baseDirectory: composeDirectory)
let requests = plan.items.map(\.request)
```

Compose is a Core-level interchange format. `Core.Compose.YAML` is the only
place that imports Yams; no public Core API exposes Yams types.

## Migration Planning Example

```swift
let document = Core.Container.Document(
    canonical: .init(createRequest: request)
)

let plan = try core.planMigration(document, to: .dockerCompatible)
if !plan.isAvailable {
    // The app maps the typed reason/context to localized Activity or alert copy.
}
```

## Fixtures

Core fixtures are available only by depending on the separate
`ContainedCoreFixtures` product. They are not linked by the normal app target or
distributable bundles.

```swift
import ContainedCore
import ContainedCoreFixtures

let container = Core.Fixtures.AppleContainer.webContainer
let history = Core.Fixtures.Generic.metricHistory
```

Use `Core.Fixtures.AppleContainer.*` for Apple-container-specific samples and
`Core.Fixtures.Generic.*` only for runtime-neutral values. App previews and UI
tests map these semantic samples into app-owned localization, presentation, and
view state.

## Build And Test

```sh
swift build --package-path Packages/ContainedCore
swift test --package-path Packages/ContainedCore
swift build --package-path Packages/ContainedCore --product ContainedCoreFixtures
```
