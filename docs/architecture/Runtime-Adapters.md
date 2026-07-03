# Runtime Orchestration

Contained's app-facing backend boundary is `ContainedCore`.

- `Core.Orchestrator` is the only backend object app stores own.
- `Core.Runtime` owns runtime descriptors, capabilities, runtime-scoped checks, and unsupported-operation errors.
- `Core.Compose` owns Compose as a cross-runtime interchange format. Yams is internal to `Core.Compose.YAML`.
- `Core.Container` owns canonical create/edit/import/export models.
- `Core.Command` owns command previews, process execution, and host invocations.
- Core-internal adapters (`Runtimes/AppleContainer` and `Runtimes/Docker`) translate canonical models to backend-specific behavior.

The app owns settings, routing, persistence, localization, Activity presentation,
and user decisions. It does not create adapter clients, call Apple CLI locators,
or assemble backend argv.

## Adapter Shape

Runtime adapters are folders inside `ContainedCore`, not standalone app
dependencies. Apple container lives under `Runtimes/AppleContainer`; Docker
lives under `Runtimes/Docker`. Future runtimes such as Podman, Lima-backed,
remote, or other runtimes should be added as sibling adapter folders under Core
and registered with `Core.Orchestrator`.

Do not add backend `switch` statements to SwiftUI views or stores. Stores call
Core. Core decides which adapter handles a selected runtime and returns typed
errors or unavailable plans when a capability is missing.

`Core.Runtime.Kind` is an open raw-value type, not a closed enum. New adapters
can define stable identifiers without forcing app-store or SwiftUI changes. Use
`Core.Runtime.Capability` and `Core.Runtime.Descriptor` to advertise support
before a UI route enables a command.

## Create, Import, Export, And Runtime Choice

The global Run/Edit form is app-owned form state, but editable runtime fields
round-trip through `Core.Schema.Document`, a runtime-neutral schema document.
Each document carries its intended runtime, so the runtime choice is per-container
or per-import item rather than a global app setting.

Core translates into and out of the shared model:

- `schemaDefinition(for:runtimeKind:)` publishes the selected runtime's run/edit field metadata.
- `previewCreateCommand(for:)` validates a schema document and returns the command preview for the selected runtime.
- `createContainer(_:)` and `recreateContainer(originalID:document:)` create from schema documents.
- `translateCompose(_:baseDirectory:runtimeKind:)` turns parsed Compose projects into schema documents plus warnings and provenance.
- `imageDefaults(for:in:)` lets the selected runtime provide image-specific defaults for the same schema fields.
- `planMigration(_:to:)` and `coreSwitchPlan(for:source:to:)` describe runtime move planning. `migrateContainer(_:sourceDocument:targetRuntimeKind:healthCheck:stabilizationTimeout:pollInterval:onPullProgress:)` owns the typed execution sequence: stop the source runtime instance, ensure the target image, create the target from normalized config plus preserved projections, wait for health/running stabilization, and only then remove the source. The app records progress, owns styling/health metadata, and presents recovery.

Before validation or execution, Core runs schema documents through
`Core.Schema.DocumentMigrator`. The migrator does not require a version ladder:
it compares values with the selected runtime's current schema, maps any
descriptor-published legacy paths, safely coerces simple value-kind drift, and
then lets validation report unresolved unknown or wrong-typed fields.

The UI does not store a global active/default runtime. Create, build, pull,
load, Compose, volume, and network flows either expose a runtime picker or route
from an existing resource's `runtimeKind`. Global prune/reclaim actions iterate
every reachable runtime with the required capability. Existing container actions
route through each resource's `runtimeKind`, so the container grid can aggregate
Apple and Docker containers without app-side runtime switching.

Images are unified at the group level by normalized reference or digest.
Registry search, remote digest checks, update status, and shared tag metadata
are app-wide, but local runnable availability is runtime-scoped: Docker
`nginx:latest` and Apple container `nginx:latest` are different local tags and
delete/tag/save/push through their owning runtime.

## Compose

Compose is a Core-level interchange format, not a Docker-only package boundary.
V1 import remains UI-first: it translates services into editable Run forms and
does not manage Docker Compose stacks. Apple container keeps `network_mode:
host` as default/blank networking, while Docker import maps it to
`--network host`. Docker, Podman, and nerdctl-style runtimes may support native
Compose execution or export later.

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
