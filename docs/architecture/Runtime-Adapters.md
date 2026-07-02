# Runtime Adapters

Contained's app-facing runtime boundary is split into shared contracts and
concrete adapters:

- `ContainedRuntime` owns `ContainerRuntimeClient`, `RuntimeDescriptor`,
  `RuntimeCapability`, runtime translation plans, `CommandError`, and command
  execution primitives.
- `AppleContainerRuntime` owns the current Apple `container` CLI adapter:
  `AppleContainerClient`, `AppleContainerCLILocator`, Apple create/import/default
  translation, and the Apple table stats parser.
- `ContainedCore` owns pure models, JSON decoding, compose parsing, decision
  helpers, open-ended `RuntimeKind`, runtime-neutral create/recreate request
  fields, and `ContainerCommands` argv builders.
- `Sources/ContainedApp` owns app state, settings, stores, SwiftUI, SwiftData, and
  app-specific presentation mapping.

## Adapter Shape

Runtime adapters are sibling SwiftPM targets. The current adapter is
`AppleContainerRuntime`; future engines such as Docker-compatible, Podman,
Lima-backed, remote, or other runtimes should be added as new adapter targets
that conform to `ContainerRuntimeClient`.

Do not add backend `switch` statements to SwiftUI views or stores. Stores should
depend on `any ContainerRuntimeClient`, while bootstrap/configuration chooses the
concrete adapter.

`RuntimeKind` is an open raw-value type, not a closed enum. New adapters can
define their own stable identifiers without editing the shared runtime package.
Use `RuntimeCapability` and `RuntimeDescriptor` to advertise support before a UI
route enables a command.

## Create, Import, And Core Choice

The global Run/Edit form is app-owned form state, but it now round-trips through
`ContainerCreateRequest`, a runtime-neutral model in `ContainedCore`. Each
request carries its intended `RuntimeKind`, so the core choice is per-container
or per-import item rather than a global app setting.

The UI currently shows Apple container as the only core and disables the picker
until another runtime descriptor is registered. The disabled control is still
intentional: it proves where future Docker-compatible or other adapters will
plug in without making Apple-specific fields the app/backend boundary.

Adapters translate into and out of the shared model:

- `previewCreateCommand(for:)` returns the command preview for the selected
  runtime.
- `createContainer(_:)` and `recreateContainer(originalID:request:)` create from
  the shared fields.
- `translateCompose(_:baseDirectory:)` turns parsed Compose projects into one
  or more standardized create requests plus warnings.
- `imageDefaults(for:in:)` lets an adapter provide image-specific defaults for
  the same form fields.
- `coreSwitchPlan(for:to:)` describes future export/import migration before the
  app enables a cross-core swap.

`ContainerCommands` remains the Apple argv source of truth. The Apple adapter
uses it to translate `ContainerCreateRequest` into `container run` today. Future
adapters should implement their own translator without adding backend `switch`
statements to SwiftUI views.

## Error Boundary

Runtime and core packages throw typed errors. They expose stable package names,
error codes, and machine-readable context through `ContainedPackageError`; they
do not decide how those failures are displayed to users.

The app target maps package errors through `AppErrorPresentation` and `AppText`.
That keeps toast copy, inline messages, alerts, and Activity history wording in
`Sources/ContainedApp`, while reusable packages remain suitable for other hosts.
Backend stderr is not translated wholesale; non-zero CLI output is preserved as
runtime-provided detail unless the adapter maps it to a known typed case.

When adding a new adapter or package error, prefer a specific error case with a
stable `packageErrorCode` over throwing a preformatted English sentence.

## Stats

The shared runtime protocol exposes typed `RuntimeStatsSnapshot` batches from
`streamStats(ids:)`. Apple `container` currently provides live stats only as an
ANSI table stream, so `AppleContainerRuntime` parses that table internally.
Future adapters should publish the same snapshot shape from their own native
source, such as an engine API stream, without leaking transport details into the
app.

## Low-Level Commands

`runContainer(arguments:)` remains available for compatibility and direct
Apple-container affordances, but Run/Edit creation should use
`ContainerCreateRequest` through the selected runtime client. Do not assemble
backend argv in SwiftUI or stores.
