# Runtime Adapters

Contained's app-facing runtime boundary is split into shared contracts and
concrete adapters:

- `ContainedRuntime` owns `ContainerRuntimeClient`, `RuntimeDescriptor`,
  `RuntimeKind`, `RuntimeCapability`, `CommandError`, and command execution
  primitives.
- `AppleContainerRuntime` owns the current Apple `container` CLI adapter:
  `AppleContainerClient`, `AppleContainerCLILocator`, and the Apple table stats
  parser.
- `ContainedCore` owns pure models, JSON decoding, compose parsing, decision
  helpers, and `ContainerCommands` argv builders.
- `Sources/Contained` owns app state, settings, stores, SwiftUI, SwiftData, and
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
define their own stable identifiers without editing the shared runtime target.
Use `RuntimeCapability` and `RuntimeDescriptor` to advertise support before a UI
route enables a command.

## Stats

The shared runtime protocol exposes typed `RuntimeStatsSnapshot` batches from
`streamStats(ids:)`. Apple `container` currently provides live stats only as an
ANSI table stream, so `AppleContainerRuntime` parses that table internally.
Future adapters should publish the same snapshot shape from their own native
source, such as an engine API stream, without leaking transport details into the
app.

## Transitional Surface

`runContainer(arguments:)` still accepts the existing generated command
arguments from `RunSpec`. That keeps this extraction behavior-preserving. A later
runtime-abstraction slice should replace it with a runtime-neutral run request
model before non-Apple adapters become user-selectable.
