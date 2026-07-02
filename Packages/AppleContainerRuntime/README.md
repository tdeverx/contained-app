# AppleContainerRuntime

AppleContainerRuntime is the concrete adapter for Apple's `container` CLI. It
conforms to `ContainerRuntimeClient` and keeps Apple-specific translation out of
the app.

## Owns

- `AppleContainerClient`, the current `container` runtime client.
- Apple CLI discovery through `AppleContainerCLILocator`.
- Apple create/import/default translation from `ContainerCreateRequest`.
- Apple stats-table parsing for `container stats --format table`.

## Does Not Own

- SwiftUI views or app stores.
- Localized copy or app error presentation.
- Docker-compatible, Podman, Lima, remote, or future runtime behavior.

Future engines should be sibling packages that conform to
`ContainerRuntimeClient` rather than switches inside the app.

## Example

```swift
import AppleContainerRuntime
import ContainedCore

let client = AppleContainerClient()
let preview = try client.previewCreateCommand(for: ContainerCreateRequest())
print(preview.command)
```

## Build And Test

```sh
swift build --package-path Packages/AppleContainerRuntime
swift test --package-path Packages/AppleContainerRuntime
```
