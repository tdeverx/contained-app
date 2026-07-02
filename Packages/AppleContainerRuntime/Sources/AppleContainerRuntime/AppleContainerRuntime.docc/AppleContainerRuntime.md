# ``AppleContainerRuntime``

Apple `container` adapter for the shared runtime contract.

## Overview

This package owns Apple-specific process execution, decode behavior, create and
Compose translation, and stats parsing. It depends on `ContainedCore` for pure
models and on `ContainedRuntime` for the adapter protocol.

The app should talk to this package through `ContainerRuntimeClient`. SwiftUI
views should not assemble Apple CLI argv directly.
