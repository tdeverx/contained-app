# Architecture

Contained is a SwiftUI-native macOS app that wraps CLI-backed container runtimes. It shells out to public CLI commands, usually with structured output, and decodes typed models. Apple `container` support is registered by default; Docker adapter groundwork lives behind the same Core runtime boundary but remains dormant until a provider model is chosen. There is no private API or daemon.

```text
 SwiftUI Views  ──>  @Observable Stores  ──>  Core.Orchestrator  ──>  Core runtime adapters
 (Features/*)        (AppModel, …)            (ContainedCore)         (AppleContainer, Docker)
       ^                    │                         │
       └──── ContainedUI + ContainedUX ───────────────┘
```

## Targets

- **`ContainedCore`** — the single backend/orchestration package. It owns `Core.*` namespaces for runtime descriptors/capabilities, canonical container models, command previews, command execution, Compose import/export semantics, Apple `container` adapter internals, dormant Docker adapter groundwork, metrics, typed display-neutral errors, and future migration/export planning. It depends on Foundation and Yams only. No SwiftUI.
- **`ContainedUI`** — a local reusable Swift package for app-agnostic SwiftUI/AppKit visual primitives. It must not depend on stores, Sparkle, SwiftData, app routing, or feature modules.
- **`ContainedUX`** — a local reusable Swift package for navigation and layout infrastructure that should not own app-specific routing. It currently owns toolbar safe-area policy/measurement primitives.
- **`ContainedApp`** — the shared SwiftUI app implementation: views, `@Observable` stores, app-specific presentation mappings, localization, navigation, and the SwiftData history stack. Depends on `ContainedCore`, `ContainedUI`, `ContainedUX`, SwiftTerm, and Sparkle.
- **`ContainedCoreFixtures`** — a separate dev/test product inside the Core package that exposes deterministic semantic samples under `Core.Fixtures.*`. Normal app, debug bundle, release, notarized, and non-notarized distributable targets must not link it.
- **`Contained`** — the tiny SwiftPM executable launcher used by command-line builds and bundle scripts.

Ownership shorthand: UI owns visuals, UX owns interaction/morph/panel movement,
Core owns backend orchestration, and ContainedApp joins those packages with
localization, persistence, settings, routing, and feature policy.

`ContainedApp` owns product copy such as navigation, settings layout, toasts,
alerts, onboarding, and Activity presentation. `ContainedCore` owns
display-neutral semantic localization where it helps the package stand alone:
schema labels/help, validation messages, runtime capability reasons,
projection/Compose warnings, and package-error fallback descriptions. Core
localization APIs support downstream override/wrap behavior; Contained uses the
Core-owned semantic strings directly because the app and package live in the
same repo.

Package errors follow the same ownership boundary. Core exposes
stable codes and compact context through `Core.Error.PackageError`; the app maps
those failures through `AppErrorPresentation` and `AppText` before showing
toasts, inline errors, alerts, or Activity history. Arbitrary backend stderr is
preserved for immediate runtime-detail presentation unless an adapter maps it to
a known typed case; persisted Activity and Console diagnostics retain only
allowlisted codes, phases, exit status, timings, and counts.

Package-local docs:

- [`Packages/ContainedCore/README.md`](../../Packages/ContainedCore/README.md)
- [`Packages/ContainedUI/README.md`](../../Packages/ContainedUI/README.md)
- [`Packages/ContainedUX/README.md`](../../Packages/ContainedUX/README.md)

`Contained.xcworkspace` is the Xcode entry point. It contains a checked-in
native `Contained.xcodeproj` app target with a tiny Xcode launcher in
`Xcode/Contained/`, and that target links the root package's `ContainedApp`
product. Xcode therefore builds and runs a real `Contained.app` for manual
SwiftUI work. The shared `Contained` scheme builds/runs the app and runs the
native `ContainedAppTests` bundle; local package schemes come from their package
manifests. SwiftPM remains the source of truth for CI, package tests, release
bundles, signing, notarization, and appcast scripts.

## Core Runtime Wrapper

- **`Core.Orchestrator`** — the only backend object app stores own. It bootstraps available CLI-backed runtimes, exposes runtime descriptors, routes runtime-scoped calls, aggregates multi-runtime container and image inventory, and returns typed command invocations for host-owned UI integrations such as SwiftTerm.
- **`Core.Runtime.Kind` / `Core.Runtime.Descriptor` / `Core.Runtime.Capability`** — open runtime identifiers and support metadata. Future runtimes register descriptors inside Core's shared runtime registry; the app reads capabilities instead of switching on backend names.
- **`Core.Schema.Document`** — runtime-neutral run/edit/recreate fields published by Core. Documents carry the intended runtime per container, generic field paths, source aliases, default semantic tips, runtime-profile support state, provenance, and validation; Core conforms documents to the selected schema before projecting executable values into `Core.Container.CreateRequest` internally.
- **`Core.Compose`** — Core-level interchange semantics for Compose import/export. Yams is internal to `Core.Compose.YAML`; public APIs expose Core models and typed plans, never Yams types.
- **`Runtimes/AppleContainer`** — Core-internal Apple adapter implementation. It owns CLI discovery, command execution, Apple create/import/default translation, command builders, and the Apple stats-table parser.
- **`Runtimes/Docker`** — Core-internal dormant Docker CLI-compatible adapter groundwork. It owns Docker CLI discovery, command builders, decoders, create/Compose translation, image actions, and Docker endpoint readiness mapping, but is not registered in the default runtime registry.
- **`Core.Error.PackageError`** — display-neutral error metadata shared by reusable packages. It gives the app a package name, stable code, and context without forcing packages to own localized copy.

## Stores (app)

- **`AppModel`** — root state: bootstraps `Core.Orchestrator`, owns feature stores, tracks bootstrap status, wires logging/updating, and runs the per-tick coordination. Focused extensions own image/resource style lookup, image-update sweeps, and configuration import/export.
- **`ContainersStore`** — the container list, live stats deltas, streamed stats conversion, and lifecycle actions against `Core.Orchestrator`.
- **`RefreshCoordinator`** — adaptive polling for service/list refreshes. Stats are maintained by one utility-priority runtime stream only while the Containers surface is visible; hiding it cancels the stream rather than spending idle CPU on invisible charts. Normal refreshes and lifecycle actions relist containers without forcing vanity stats.
- **`RestartWatchdog`** — app-managed live-crash restart policy (`container` has no native `--restart`); diffs states each tick and re-issues `start` with backoff. Core separately restores stopped `Always` containers after a Contained-initiated engine start when the app preference permits it.
- **`HealthMonitor`** — app-managed healthchecks: interval-gated `exec` probes with consecutive-failure tracking.
- **`HistoryStore`** — SwiftData stack for the persistent event log + metric samples (the "rewind" timeline) with bounded retention.
- **`UpdaterController`** — wraps Sparkle; the user's selected update channel chooses a branch-hosted appcast feed. Stable and Beta feeds are branch-local, while Nightly is a superset that also carries promoted release items.
- **`SettingsStore`** — persists appearance, update cadence, logging, material choices, and experimental feature gates. `SettingsBackup` owns the portable export/import shape.
- **`UIState`** — owns container-group selection, toolbar morph state, palette routing, and creation/edit flow handoff. Panel-specific filter state, container sorting, and one-shot actions live in adjacent navigation files so routing state stays readable.

## Design system

Liquid Glass helpers and reusable primitives include `UI.Panel.Scaffold`, `UI.Panel.Header`, `UI.Panel.Section`, `UI.Panel.Row`, `UI.Panel.Field`, `UI.Card.Scaffold`, `UI.Card.InsetSection`, `UI.Action.Group`, `UI.Action.TextButton`, `UI.Action.ToggleButton`, `UI.Action.SelectionBar`, `UI.State.Banner`, `UI.Surface.Content`, `UI.Surface.Input`, `UI.Command.PreviewBar`, `UI.Control.InfoButton`, `UI.Badge.Status`, `UI.Control.KeyCap`, `UI.Chart.Sparkline`, and `UI.Tokens` groups for toolbar, panel, spacing, radius, icon sizing, design cards, badges, charts, terminal chrome, and form widths. `ContainedUI` owns app-agnostic visual tokens and primitives; feature code should not introduce local spacing, radius, material, shadow, opacity, surface modifiers, glass button styles, or micro-chrome recipes. App-side cards use `UI.Card.Scaffold`; card shell/header/page-rail assembly and low-level glass button/surface routes are package-internal. App-state-aware mappings such as runtime status and graph metric extraction stay in `ContainedApp` until they can cross the boundary without depending on app/core policy. Use the package READMEs for import instructions and copy-pasteable examples, and see [Design System](Design-System.md) for app-level conventions.

## Local-only personalization

Card styles and healthchecks are stored locally (keyed by container id / image reference) — **never** injected as personalization labels, keeping the CLI and containers clean. `Personalization` owns the resolved style shape, `WidgetConfiguration` owns metric widget schema/options, and `PersonalizationStore` owns persistence and inheritance. Functional app-managed labels such as restart policy must round-trip through the container.

## Testing

Package-local tests hold golden-argv tests, decode tests against captured real CLI fixtures, pure decision tests, runtime descriptor contracts, Apple adapter decoding/streaming, create/import translation, unsupported capabilities, typed stats snapshots, design-system layout rules, navigation behavior, and preview fixtures. `Tests/ContainedAppTests` covers app-owned form state, create-request round-trips, and runtime-translated compose mapping. Run with `swift test` at the root or `swift test --package-path Packages/<PackageName>` for a standalone package.
