# Architecture

Contained is a SwiftUI-native macOS app that wraps Apple's `container` CLI. It shells out to the CLI with `--format json` and decodes typed models — there is no private API or daemon.

```
 SwiftUI Views  ──>  @Observable Stores  ──>  ContainerClient  ──>  CommandRunner  ──>  `container` CLI
 (Features/*)        (AppModel, …)            (typed facade)        (run / stream)       (--format json)
       ^                    │                       ^                                          │
       └──── design system, tokens ────────────────┘                                          │
                            └───────────────────  decoded models (ContainedCore)  ◀───────────┘
```

## Targets

- **`ContainedCore`** — pure, testable logic: models, the CLI wrapper, JSON decoding, compose parsing, and ordering/decision helpers. Depends only on Yams. No SwiftUI.
- **`Contained`** — the SwiftUI executable: views, `@Observable` stores, the design system, and the SwiftData history stack. Depends on `ContainedCore` + SwiftTerm + Sparkle.

## CLI wrapper (core)

- **`ContainerCommands`** — pure argv builders, side-effect-free so golden tests assert the exact arguments (the "Reveal CLI" affordances read from the same source of truth).
- **`CommandRunner`** — runs a one-shot command (`run`) or a streaming one (`stream`, an `AsyncThrowingStream`). Passwords are piped via `--password-stdin`, never argv.
- **`ContainerClient`** — a typed facade returning decoded models; maps decode failures to a single `CommandError`.

## Stores (app)

- **`AppModel`** — root state: locates the CLI, owns the client + feature stores, tracks bootstrap status, wires logging/updating, and runs the per-tick coordination.
- **`ContainersStore`** — the container list, live stats deltas, and lifecycle actions.
- **`RefreshCoordinator`** — adaptive polling (stats are polled, not truly streamed — the CLI emits one frame then blocks).
- **`RestartWatchdog`** — app-managed restart policy (`container` has no native `--restart`); diffs states each tick and re-issues `start` with backoff.
- **`HealthMonitor`** — app-managed healthchecks: interval-gated `exec` probes with consecutive-failure tracking.
- **`HistoryStore`** — SwiftData stack for the persistent event log + metric samples (the "rewind" timeline) with bounded retention.
- **`UpdaterController`** — wraps Sparkle; the user's selected update channel chooses an independent branch-hosted appcast feed.
- **`SettingsStore`** — persists appearance, update cadence, logging, material choices, and experimental feature gates.
- **`UIState`** — owns navigation, sidebar visibility, toolbar morph state, palette routing, and creation/edit flow handoff.

## Design system

Liquid Glass helpers and reusable primitives include `MorphPanelScaffold`, `PanelHeader`, `PanelSection`, `ResourceGlassCard`, `CommandPreviewBar`, `InfoButton`, `ToolbarIconButton`, and `Tokens` groups for toolbar, panel, spacing, radius, and icon sizing. See [[Design System|Design-System]].

## Local-only personalization

Card styles and healthchecks are stored locally (keyed by container id / image reference) — **never** injected as personalization labels, keeping the CLI and containers clean. Functional app-managed labels such as restart policy must round-trip through the container.

## Testing

`Tests/ContainedCoreTests` holds golden-argv tests (every `ContainerCommands` builder), decode tests against captured real CLI fixtures, and pure decision tests (`RestartDecision`, `HealthDecision`, compose ordering). `Tests/ContainedAppTests` covers `RunSpec` argv + compose mapping. Run with `swift test`.
