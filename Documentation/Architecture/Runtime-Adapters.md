# Runtime Orchestration

Contained's app-facing backend boundary is `ContainedCore`.

- `Core.Orchestrator` is the only backend object app stores own.
- `Core.Runtime` owns runtime identity, descriptors, capabilities, runtime-scoped checks, module registration, and unsupported-operation errors.
- `Core.Compose` owns Compose as a cross-runtime interchange format. Yams is internal to `Core.Compose.YAML`.
- `Core.Container` owns canonical create/edit/import/export models.
- `Core.Command` owns command previews, process execution, and host invocations.
- Core-internal adapters translate canonical models to backend-specific behavior through `Core.Runtime.Module`. `Runtimes/AppleContainer` is registered by default; `Runtimes/Docker` is dormant groundwork and must not be added to the default registry until a Docker provider model is chosen.

The app owns settings, routing, persistence, localization, Activity presentation,
and user decisions. It does not create adapter clients, call Apple CLI locators,
or assemble backend argv.

## Adapter Shape

Runtime adapters are folders inside `ContainedCore`, not standalone app
dependencies. Apple container lives under `Runtimes/AppleContainer`; dormant
Docker groundwork lives under `Runtimes/Docker`. Future runtimes such as Podman,
Lima-backed, remote, or other runtimes should be added as sibling adapter
folders under Core and registered in the built-in runtime module registry only
when they are ready to be app-discoverable.

The shared registry lives in `Runtime/ModuleRegistry.swift`; `Runtimes/**`
contains concrete adapter behavior only. Shared `Runtime/**` files define the
module contract, descriptors, capabilities, readiness state, client protocols,
configuration, unsupported-capability errors, and migration contracts.

Each adapter module owns its descriptor, capability preset, CLI lookup, client
creation, readiness probing, command previews, terminal invocation, schema
support profile, Compose projection, and runtime-specific Core strings. Shared
Core owns the contracts and normalized models; it does not construct concrete
clients, call concrete CLI locators, or branch on Docker/Apple command builders
outside the runtime tree.

Do not add backend `switch` statements to SwiftUI views or stores. Stores call
Core. Core decides which adapter handles a selected runtime and returns typed
errors or unavailable plans when a capability is missing.

`Core.Runtime.Kind` is an open raw-value type, not a closed enum. New adapters
can define stable identifiers without forcing app-store or SwiftUI changes.
Shipped kinds such as `apple-container` and `docker` are stable identity
constants only; unknown or unregistered kinds are unsupported instead of being
silently remapped. Use `Core.Runtime.Capability` and `Core.Runtime.Descriptor`
to advertise support before a UI route enables a command.

Bootstrap returns readiness for every registered module. A runtime can be
`cliMissing`, `unsupported`, `endpointUnavailable`, or `ready`, so the app can
present missing CLI, unsupported CLI, and stopped daemon/service states without
guessing from a single global bootstrap value.

Runtime inventory is aggregated per capability. If one runtime fails while
another succeeds, Core returns the successful resources with typed partial
failure details so the app can keep the grid usable and surface the degraded
runtime instead of hiding the problem.

## Create, Import, Export, And Runtime Choice

The global Run/Edit form is app-owned form state, but editable runtime fields
round-trip through `Core.Schema.Document`, a runtime-neutral schema document.
Each document carries its intended runtime, so the runtime choice is per-container
or per-import item rather than a global app setting.

Core translates into and out of the shared model through the selected runtime
module:

- `schemaDefinition(for:runtimeKind:)` publishes canonical field definitions with the selected module's schema profile applied.
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

Runtime settings are keyed by `Core.Runtime.Kind` and rendered from descriptors
and capabilities. Path overrides are runtime records. Service, kernel, DNS, and
endpoint controls appear only when a descriptor advertises the matching runtime
capability, so the app does not need a hardcoded active/default runtime.

Images are unified at the group level by normalized reference or digest.
Registry search, remote digest checks, and shared image metadata are app-wide,
while local update status and runnable availability are runtime-scoped per tag:
Docker
`nginx:latest` and Apple container `nginx:latest` are different local tags and
delete/tag/save/push through their owning runtime.

## Compose

Compose is a Core-level interchange format, not a Docker-only package boundary.
V1 import remains UI-first: it translates services into editable Run forms and
does not manage Docker Compose stacks. Apple container keeps `network_mode:
host` as default/blank networking, while Docker import maps it to
`--network host`. Docker, Podman, and nerdctl-style runtimes may support native
Compose execution or export later.

YAML parsing/writing belongs under `Core.Compose.YAML` and remains the only
place that imports Yams. Runtime-specific host networking, unsupported-field
preservation, and create/edit projection belong inside each runtime adapter
folder. Public APIs expose Core models and typed plans, never Yams types.

## Errors And Stats

Core throws typed display-neutral errors with stable package codes/context. The
app maps them through `AppErrorPresentation` and `AppText` before showing
toasts, inline messages, alerts, or Activity history.

Core exposes typed `Core.Metrics.RuntimeStatsSnapshot` batches from
`streamStats(ids:)`. Apple container currently provides live stats only as an
ANSI table stream, so the Apple adapter parses that table internally. Future
adapters should publish the same snapshot shape from their own native source
without leaking transport details into the app.
