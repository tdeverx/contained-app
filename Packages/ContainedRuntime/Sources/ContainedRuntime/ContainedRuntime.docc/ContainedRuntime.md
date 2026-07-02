# ``ContainedRuntime``

Adapter-neutral runtime contracts for container engines.

## Overview

`ContainedRuntime` is the boundary between app stores and concrete engine
adapters. Stores depend on `any ContainerRuntimeClient`; adapter packages
implement the protocol and advertise capabilities with `RuntimeDescriptor`.

Use this package to:

- describe a runtime and its capabilities
- translate shared create/import models into runtime-specific plans
- report unsupported operations as display-neutral typed errors
- return unavailable operation reasons as stable codes instead of UI copy
- run CLI-backed commands through `CommandRunner`

The app chooses which runtime to use for each container or import item, then maps
typed package errors into localized alerts, toasts, and Activity entries.
