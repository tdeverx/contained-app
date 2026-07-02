# ContainedPreviewSupport

ContainedPreviewSupport provides deterministic fixtures for previews, examples,
and lightweight package tests.

## Owns

- Sample containers, images, volumes, networks, runtime descriptors, stats,
  metric histories, card-style descriptors, widget descriptors, activity state
  identifiers, and representative package errors.
- Fixture values that packages and the app can reuse without spinning up the
  Apple `container` service.

## Does Not Own

- Localized strings.
- Production app state or persistence.
- Live runtime calls.

## Example

```swift
import ContainedPreviewSupport

let container = PreviewSamples.webContainer
let values = PreviewSamples.sparklineValues
let volume = PreviewSamples.volume
let network = PreviewSamples.network
let widgets = PreviewSamples.widgetConfigs
let errorCode = PreviewSamples.commandError.packageErrorCode
```

App previews should map `PreviewCardStyleDescriptor` and
`PreviewWidgetDescriptor` into app-owned style/state types. The package keeps
those descriptors runtime-neutral so it does not depend on `Sources/ContainedApp`.
Preview activity fixtures describe state and resource identifiers; apps still
provide the localized copy shown around that state.

## Build And Test

```sh
swift build --package-path Packages/ContainedPreviewSupport
swift test --package-path Packages/ContainedPreviewSupport
```
