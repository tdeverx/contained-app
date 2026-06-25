# Architecture

Contained is a SwiftUI-native macOS app that wraps Apple's `container` CLI. It shells out to the CLI with `--format json` and decodes typed models — there is no private API or daemon.

## Targets

- **`ContainedCore`** — pure, testable logic: models, the CLI wrapper, JSON decoding, compose parsing, and ordering/decision helpers. Depends only on Yams. No SwiftUI.
- **`Contained`** — the SwiftUI executable: views, `@Observable` stores, the design system, and the SwiftData history stack. Depends on `ContainedCore` + SwiftTerm.

## CLI wrapper (core)

- **`ContainerCommands`** — pure argv builders, side-effect-free so golden tests assert the exact arguments (the "Reveal CLI" affordances read from the same source of truth).
- **`CommandRunner`** — runs a one-shot command (`run`) or a streaming one (`stream`, an `AsyncThrowingStream`). Passwords are piped via `--password-stdin`, never argv.
- **`ContainerClient`** — a typed facade returning decoded models; maps decode failures to a single `CommandError`.

## Stores (app)

- **`AppModel`** — root state: locates the CLI, owns the client + feature stores, tracks bootstrap status, and runs the per-tick coordination.
- **`ContainersStore`** — the container list, live stats deltas, and lifecycle actions.
- **`RefreshCoordinator`** — adaptive polling (stats are polled, not truly streamed — the CLI emits one frame then blocks).
- **`RestartWatchdog`** — app-managed restart policy (`container` has no native `--restart`); diffs states each tick and re-issues `start` with backoff.
- **`HealthMonitor`** — app-managed healthchecks: interval-gated `exec` probes with consecutive-failure tracking.
- **`HistoryStore`** — SwiftData stack for the persistent event log + metric samples (the "rewind" timeline).

## Design system

Liquid Glass helpers (`glassSurface`, `GlassCircleButton`, `GlassRowMenu`, `SheetHeader`, `InfoButton`), tokens (`Tokens.Space/Radius/SheetSize/IconSize`), and reusable resource chrome (`ResourceScaffold`, `ResourceRow`, `JSONInspectorSheet`).

## Local-only personalization

Card styles and healthchecks are stored locally (keyed by container id / image reference) — **never** injected as `contained.*` labels, keeping the CLI and containers clean. The only functional labels written are `contained.restart` (restart policy) and `contained.stack` (stack grouping).
