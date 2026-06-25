# Contributing

## Layout

```
Sources/ContainedCore/   pure logic — models, CLI wrapper, decoding, compose (no SwiftUI)
Sources/Contained/       the SwiftUI app
  DesignSystem/          glass helpers, tokens, shared components
  Features/<Domain>/     one folder per sidebar domain
  Navigation/ Stores/ Support/ History/
Tests/ContainedCoreTests/ golden-argv + decode + decision tests
docs/                    this wiki
scripts/                 bundle.sh, release.sh, appcast.sh
```

## Conventions

- **Every CLI action goes through a `ContainerCommands` builder** + a `ContainerClient` wrapper, with a golden-argv test. The UI never assembles argv inline — this keeps "Reveal CLI" honest.
- **Pure decision logic is factored into `ContainedCore`** (`RestartDecision`, `HealthDecision`, `ComposeOrder`) and unit-tested without spawning processes.
- **No `contained.*` personalization labels.** Card styles and healthchecks live in local stores. Only `contained.restart` and `contained.stack` are written (they must round-trip through the container).
- **Match the surrounding style** — comment density, naming, Liquid Glass idioms. AppKit bridges are flagged in comments.

## Before a PR

```sh
swift build && swift test          # must be green
./scripts/bundle.sh && open Contained.app   # smoke-test the screens you touched
```
