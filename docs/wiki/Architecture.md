# Architecture

Contained is a SwiftUI-native macOS app that wraps Apple's `container` CLI. It shells out to public CLI commands, usually with `--format json`, and decodes typed models. Visible container stats are the exception: Apple container only streams stats in table mode, so Contained parses that public table stream behind the same runtime boundary. There is no private API or daemon.

```
 SwiftUI Views  ──>  @Observable Stores  ──>  ContainerClient  ──>  CommandRunner  ──>  `container` CLI
 (Features/*)        (AppModel, …)            (typed facade)        (run / stream)       (json / table)
       ^                    │                       ^                                          │
       └──── ContainedDesignSystem ────────────────┘                                          │
                            └───────────────────  decoded models (ContainedCore)  ◀───────────┘
```

## Targets

- **`ContainedCore`** — pure, testable logic: models, the CLI wrapper, JSON decoding, compose parsing, and ordering/decision helpers. Depends only on Yams. No SwiftUI.
- **`ContainedDesignSystem`** — a local reusable Swift package for app-agnostic SwiftUI/AppKit visual primitives. It must not depend on stores, Sparkle, SwiftData, app routing, or feature modules.
- **`ContainedNavigation`** — a local reusable Swift package for navigation and layout infrastructure that should not own app-specific routing. It currently owns toolbar safe-area policy/measurement primitives.
- **`Contained`** — the SwiftUI executable: views, `@Observable` stores, app-specific presentation mappings, navigation, and the SwiftData history stack. Depends on `ContainedCore`, `ContainedDesignSystem`, `ContainedNavigation`, SwiftTerm, and Sparkle.

Package-local docs:

- [`Packages/ContainedDesignSystem/README.md`](../../Packages/ContainedDesignSystem/README.md)
- [`Packages/ContainedNavigation/README.md`](../../Packages/ContainedNavigation/README.md)

`Contained.xcworkspace` is the optional Xcode entry point. It references the
root `Package.swift` and local package manifests; the SwiftPM package graph
remains the source of truth for builds, tests, and release scripts.

## CLI wrapper (core)

- **`ContainerCommands`** — pure argv builders, side-effect-free so golden tests assert the exact arguments (the "Reveal CLI" affordances read from the same source of truth).
- **`CommandRunner`** — runs a one-shot command (`run`) or a streaming one (`stream`, an `AsyncThrowingStream`). Commands can opt into utility/background priority for vanity work such as stats. Passwords are piped via `--password-stdin`, never argv.
- **`ContainerClient`** — the Apple `container` implementation of `ContainerRuntimeClient`; returns decoded models and maps decode failures to a single `CommandError`.
- **`ContainerStatsTableParser`** — dependency-free parser for the ANSI table emitted by `container stats --format table`. It converts table frames into runtime-agnostic snapshots so the app can keep one visible stats stream open instead of spawning repeated JSON stats processes.
- **`ContainerRuntimeClient`** — the backend-facing operation contract. `RuntimeDescriptor` and `RuntimeCapability` advertise what a selected runtime can do before future Docker-compatible integration reaches the UI.

## Stores (app)

- **`AppModel`** — root state: locates the CLI, owns the client + feature stores, tracks bootstrap status, wires logging/updating, and runs the per-tick coordination. Focused extensions own image/resource style lookup, image-update sweeps, and configuration import/export.
- **`ContainersStore`** — the container list, live stats deltas, streamed stats conversion, and lifecycle actions.
- **`RefreshCoordinator`** — adaptive polling for service/list refreshes. Stats are maintained app-wide by one utility-priority table stream for the running containers, so normal refreshes and lifecycle actions relist containers without forcing vanity stats.
- **`RestartWatchdog`** — app-managed restart policy (`container` has no native `--restart`); diffs states each tick and re-issues `start` with backoff.
- **`HealthMonitor`** — app-managed healthchecks: interval-gated `exec` probes with consecutive-failure tracking.
- **`HistoryStore`** — SwiftData stack for the persistent event log + metric samples (the "rewind" timeline) with bounded retention.
- **`UpdaterController`** — wraps Sparkle; the user's selected update channel chooses a branch-hosted appcast feed. Stable and Beta feeds are branch-local, while Nightly is a superset that also carries promoted release items.
- **`SettingsStore`** — persists appearance, update cadence, logging, material choices, and experimental feature gates. `SettingsBackup` owns the portable export/import shape.
- **`UIState`** — owns navigation, sidebar visibility, toolbar morph state, palette routing, and creation/edit flow handoff. Toolbar grouping/sort/filter enums and one-shot actions live in adjacent navigation files so routing state stays readable.

## Design system

Liquid Glass helpers and reusable primitives include `MorphPanelScaffold`, `PanelHeader`, `PanelSection`, `PanelRow`, `PanelField`, `ResourceCard`, `ResourceCardInsetSection`, `DesignActionGroup`, `DesignTextActionButton`, `DesignGlassToggle`, `DesignSelectionActionBar`, `DesignStatusBanner`, `DesignContentSurface`, `DesignInputSurface`, `CommandPreviewBar`, `InfoButton`, `DesignStatusBadge`, `DesignKeyCap`, `LiveSparkline`, and `Tokens` groups for toolbar, panel, spacing, radius, icon sizing, resource cards, badges, charts, terminal chrome, and form widths. `ContainedDesignSystem` owns app-agnostic visual tokens and primitives; feature code should not introduce local spacing, radius, material, shadow, opacity, surface modifiers, glass button styles, or micro-chrome recipes. App-state-aware mappings such as runtime status and graph metric extraction stay in the executable until they can cross the boundary without depending on app/core policy. App-side resource cards should use `ResourceCard` rather than assembling `ResourceGlassCard`, headers, page rails, widgets, or footers directly, and app-side command chrome should use the named design action/toolbar controls rather than `GlassButton`, `glassSurface`, or `.buttonStyle(.glass*)` directly. Use the package READMEs for import instructions and copy-pasteable examples, and see [[Design System|Design-System]] for app-level conventions.

## Local-only personalization

Card styles and healthchecks are stored locally (keyed by container id / image reference) — **never** injected as personalization labels, keeping the CLI and containers clean. `Personalization` owns the resolved style shape, `WidgetConfiguration` owns metric widget schema/options, and `PersonalizationStore` owns persistence and inheritance. Functional app-managed labels such as restart policy must round-trip through the container.

## Testing

`Tests/ContainedCoreTests` holds golden-argv tests (every `ContainerCommands` builder), decode tests against captured real CLI fixtures, and pure decision tests (`RestartDecision`, `HealthDecision`, compose ordering). `Tests/ContainedAppTests` covers `RunSpec` argv + compose mapping. Run with `swift test`.
