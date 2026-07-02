# ``ContainedCore``

Pure models, command builders, compose parsing, and display-neutral error
metadata shared by Contained packages and the app.

## Overview

`ContainedCore` is intentionally UI-free. It can be imported by runtime
adapters, preview fixtures, tests, or future host apps without bringing in
SwiftUI, Sparkle, SwiftData, stores, or localization resources.

Use it for:

- runtime-neutral container create and recreate requests
- decoded Apple `container` JSON models
- Compose project parsing
- Apple `container` argv builders
- stats normalization helpers
- stable package error metadata

The app remains responsible for localized presentation and user-visible error
copy.

## Example

```swift
import ContainedCore

let kind = RuntimeKind(rawValue: "docker-compatible")
let context = StatsNormalizationContext(
    mode: .container,
    containerCPUCores: 2,
    containerMemoryLimitBytes: 2_147_483_648,
    hostCPUCores: 10,
    hostMemoryBytes: 34_359_738_368
)
```
