# ContainedCore

ContainedCore is the pure model and command-building package for Contained. It
contains no SwiftUI, app state, Sparkle, persistence, or presentation code.

## Owns

- Runtime-neutral models such as `ContainerSnapshot`, `ContainerCreateRequest`,
  `RuntimeKind`, resources, stats, and system information.
- Apple `container` command builders in `ContainerCommands`.
- Compose parsing and ordering helpers.
- Display-neutral package errors through `ContainedPackageError`.
- Pure metric and normalization helpers used by app widgets and history.

## Does Not Own

- Localized strings or user-facing copy.
- SwiftUI views, stores, routing, or settings.
- Runtime execution or process launching.
- Apple-specific create/import translation beyond argv builders.

## Example

```swift
import ContainedCore

var request = ContainerCreateRequest()
request.name = "web"
request.image = "nginx:latest"
request.runtimeKind = .appleContainer
request.ports = [.init(hostPort: "8080", containerPort: "80", proto: "tcp")]

let command = ContainerCommands.run(request)
```

## Build And Test

```sh
swift build --package-path Packages/ContainedCore
swift test --package-path Packages/ContainedCore
```
