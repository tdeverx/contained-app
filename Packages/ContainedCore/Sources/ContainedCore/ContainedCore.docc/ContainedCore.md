# ``ContainedCore``

Backend orchestration, runtime translation, command execution, Compose
interchange, metrics, and display-neutral errors for Contained.

## Overview

`ContainedCore` exposes a nested `Core.*` API, matching the `UI.*` and `UX.*`
package style. App code talks to ``Core/Orchestrator``. Runtime adapters live
inside Core, including Apple container and Docker CLI adapters, so
the app does not create adapter clients or assemble backend argv.

Use Core for:

- runtime descriptors and capabilities
- canonical container create/edit/import/export models
- multi-runtime container and image inventory
- command previews and host command invocations
- Compose import/export plans
- run/edit schema conformance before validation and execution
- image defaults and registry helpers
- stats snapshots, metric normalization, and history inputs
- typed display-neutral package errors

`ContainedCore` does not import SwiftUI, Sparkle, SwiftTerm, ContainedUI, or
ContainedUX. It may own display-neutral semantic localization for schema
labels/help, validation messages, runtime capability reasons, Compose or
projection warnings, and typed package-error fallback descriptions. The app
still maps Core errors and technical identifiers into product-specific copy
where presentation policy matters.

Deterministic dev/test samples live in the separate `ContainedCoreFixtures`
product. Import that product only from tests, previews, or sandbox-only targets;
normal app and distributable bundle targets must not link it.

## Compose

Compose belongs to `Core.Compose` because it is a cross-runtime interchange
format. Yams is internal to `Core.Compose.YAML`; public APIs expose Core models
and plans rather than Yams types.

## Example

```swift
import ContainedCore

var document = Core.Schema.Document.containerCreate()
document.set(.containerName, .string("web"))
document.set(.imageReference, .string("nginx:latest"))

let core = Core.Orchestrator.testing(runner: PreviewRunner())
let preview = try core.previewCreateCommand(for: document)
```

## Fixtures

```swift
import ContainedCore
import ContainedCoreFixtures

let container = Core.Fixtures.AppleContainer.webContainer
let history = Core.Fixtures.Generic.metricHistory
```

Use `Core.Fixtures.AppleContainer.*` for Apple-container-specific samples and
`Core.Fixtures.Generic.*` only for runtime-neutral values. The app owns any
mapping from these semantic samples into localized labels, SwiftUI preview
state, personalization, or widget settings.
