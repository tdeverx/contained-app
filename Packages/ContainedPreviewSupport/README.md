# ContainedPreviewSupport

ContainedPreviewSupport provides deterministic fixtures for previews, examples,
and lightweight package tests.

## Owns

- Sample containers, images, runtime descriptors, stats, histories, and activity
  states.
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
```

## Build And Test

```sh
swift build --package-path Packages/ContainedPreviewSupport
swift test --package-path Packages/ContainedPreviewSupport
```
