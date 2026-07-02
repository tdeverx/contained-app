# Runtime Orchestration

Contained's app-facing backend boundary is `ContainedCore`.

- `Core.Orchestrator` is the only backend object app stores own.
- `Core.Runtime` owns runtime descriptors, capabilities, selected-runtime checks, and unsupported-operation errors.
- `Core.Compose` owns Compose as a cross-runtime interchange format. Yams is internal to `Core.Compose.YAML`.
- `Core.Container` owns canonical create/edit/import/export models.
- `Core.Command` owns command previews, process execution, and host invocations.
- Core-internal adapters, beginning with `Runtimes/AppleContainer`, translate canonical models to backend-specific behavior.

The app owns settings, routing, persistence, localization, Activity presentation,
and user decisions. It does not create adapter clients, call Apple CLI locators,
or assemble backend argv.

## Adapter Shape

Runtime adapters are folders inside `ContainedCore`, not standalone app
dependencies. The current adapter is Apple container. Future engines such as
Docker-compatible, Podman, Lima-backed, remote, or other runtimes should be
added as sibling adapter folders under Core and registered with
`Core.Orchestrator`.

Do not add backend `switch` statements to SwiftUI views or stores. Stores call
Core. Core decides which adapter handles a selected runtime and returns typed
errors or unavailable plans when a capability is missing.

`Core.Runtime.Kind` is an open raw-value type, not a closed enum. New adapters
can define stable identifiers without forcing app-store or SwiftUI changes. Use
`Core.Runtime.Capability` and `Core.Runtime.Descriptor` to advertise support
before a UI route enables a command.

## Create, Import, Export, And Core Choice

The global Run/Edit form is app-owned form state, but it round-trips through
`Core.Container.CreateRequest`, a runtime-neutral model. Each request carries
its intended runtime, so the core choice is per-container or per-import item
rather than a global app setting.

Core translates into and out of the shared model:

- `previewCreateCommand(for:)` returns the command preview for the selected runtime.
- `createContainer(_:)` and `recreateContainer(originalID:request:)` create from shared fields.
- `translateCompose(_:baseDirectory:runtimeKind:)` turns parsed Compose projects into standardized create requests plus warnings.
- `imageDefaults(for:in:)` lets the selected runtime provide image-specific defaults for the same form fields.
- `planMigration(_:to:)` and `coreSwitchPlan(for:source:to:)` describe future export/import migration before the app enables a cross-core swap.

The UI currently shows Apple container as the only enabled core and disables the
picker until another runtime descriptor is registered. The disabled control is
intentional: it proves where future Docker-compatible or other adapters will
plug in without making Apple-specific fields the app/backend boundary.

## Compose

Compose is a Core-level interchange format, not a Docker-only package boundary.
Docker, Podman, and nerdctl-style engines may support native Compose execution
or export later. Apple container does not execute Compose natively, but Core can
parse Compose and translate services into Apple container create specs.

Dialect differences belong under `Core.Compose.Dialect`; YAML parsing/writing
belongs under `Core.Compose.YAML` and remains the only place that imports Yams.
Public APIs expose Core models and typed plans, never Yams types.

## Errors And Stats

Core throws typed display-neutral errors with stable package codes/context. The
app maps them through `AppErrorPresentation` and `AppText` before showing
toasts, inline messages, alerts, or Activity history.

Core exposes typed `Core.Metrics.RuntimeStatsSnapshot` batches from
`streamStats(ids:)`. Apple container currently provides live stats only as an
ANSI table stream, so the Apple adapter parses that table internally. Future
adapters should publish the same snapshot shape from their own native source
without leaking transport details into the app.
