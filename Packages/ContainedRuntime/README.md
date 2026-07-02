# ContainedRuntime

ContainedRuntime defines the backend contract used by the app and concrete
runtime adapters. It is adapter-neutral and owns no SwiftUI or display policy.

## Owns

- `ContainerRuntimeClient`, the async operation protocol for runtime adapters.
- `RuntimeDescriptor` and `RuntimeCapability`, used by the app to decide what a
  selected runtime can support.
- Runtime translation result models for create, Compose import, image defaults,
  and future core switching.
- `CommandRunner` and `CommandError` for CLI-backed adapters.
- Display-neutral error and unavailable-reason codes that the app maps to
  localized alerts, toasts, and Activity entries.

## Does Not Own

- Apple-, Docker-, Podman-, Lima-, or remote-specific policy.
- UI routes, app settings, or localization.
- User-facing error messages.

## Example

```swift
import ContainedCore
import ContainedRuntime

let descriptor = RuntimeDescriptor(
    kind: RuntimeKind(rawValue: "future-runtime"),
    displayName: "Future runtime",
    executableName: "future",
    capabilities: [.containers, .composeImport]
)

if descriptor.supports(.composeImport) {
    // Enable a runtime-specific Compose import route.
}
```

## Build And Test

```sh
swift build --package-path Packages/ContainedRuntime
swift test --package-path Packages/ContainedRuntime
```
