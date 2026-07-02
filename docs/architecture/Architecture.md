# Architecture

Contained is a SwiftUI-native macOS app that wraps Apple's `container` CLI. It shells out to public CLI commands, usually with `--format json`, and decodes typed models. Visible container stats are the exception: Apple container only streams stats in table mode, so Contained parses that public table stream behind the same runtime boundary. There is no private API or daemon.

```text
 SwiftUI Views  ──>  @Observable Stores  ──>  Core.Orchestrator  ──>  Core runtime adapters
 (Features/*)        (AppModel, …)            (ContainedCore)         (Runtimes/AppleContainer, future engines)
       ^                    │                         │
       └──── ContainedUI + ContainedUX ───────────────┘
```

## Targets

- **`ContainedCore`** — the single backend/orchestration package. It owns `Core.*` namespaces for runtime descriptors/capabilities, canonical container models, command previews, command execution, Compose import/export semantics, Apple `container` adapter internals, metrics, typed display-neutral errors, and future migration/export planning. It depends on Foundation and Yams only. No SwiftUI.
- **`ContainedUI`** — a local reusable Swift package for app-agnostic SwiftUI/AppKit visual primitives. It must not depend on stores, Sparkle, SwiftData, app routing, or feature modules.
- **`ContainedUX`** — a local reusable Swift package for navigation and layout infrastructure that should not own app-specific routing. It currently owns toolbar safe-area policy/measurement primitives.
- **`ContainedApp`** — the shared SwiftUI app implementation: views, `@Observable` stores, app-specific presentation mappings, localization, navigation, and the SwiftData history stack. Depends on `ContainedCore`, `ContainedUI`, `ContainedUX`, SwiftTerm, and Sparkle.
- **`ContainedCoreFixtures`** — a separate dev/test product inside the Core package that exposes deterministic semantic samples under `Core.Fixtures.*`. Normal app, debug bundle, release, notarized, and non-notarized distributable targets must not link it.
- **`Contained`** — the tiny SwiftPM executable launcher used by command-line builds and bundle scripts.

Ownership shorthand: UI owns visuals, UX owns interaction/morph/panel movement,
Core owns backend orchestration, and ContainedApp joins those packages with
localization, persistence, settings, routing, and feature policy.

`ContainedApp` owns localization. Reusable packages do not ship localized
resources or English UI defaults; app code supplies user-facing text through
package parameters and routes reusable enum labels/dynamic templates through
`AppText`. `ContainedCore` stays language-free unless it exposes technical
identifiers such as raw values, runtime descriptors, package error codes, or
backend command output.

Package errors follow the same ownership boundary. Core exposes
stable codes and compact context through `ContainedPackageError`; the app maps
those failures through `AppErrorPresentation` and `AppText` before showing
toasts, inline errors, alerts, or Activity history. Arbitrary backend stderr is
preserved as runtime-provided detail unless an adapter maps it to a known typed
case.

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

- **`Core.Orchestrator`** — the only backend object app stores own. It bootstraps the Apple CLI today, exposes available runtime descriptors, routes selected-runtime operations, and returns typed command invocations for host-owned UI integrations such as SwiftTerm.
- **`Core.Runtime.Kind` / `Core.Runtime.Descriptor` / `Core.Runtime.Capability`** — open runtime identifiers and support metadata. Future engines register descriptors inside Core; the app reads capabilities instead of switching on backend names.
- **`Core.Container.CreateRequest`** — runtime-neutral create/recreate fields used by the app form and adapter import/default translation. It carries the intended runtime per container so the core choice is not app-global.
- **`Core.Compose`** — Core-level interchange semantics for Compose import/export. Yams is internal to `Core.Compose.YAML`; public APIs expose Core models and typed plans, never Yams types.
- **`Runtimes/AppleContainer`** — Core-internal Apple adapter implementation. It owns CLI discovery, command execution, Apple create/import/default translation, command builders, and the Apple stats-table parser.
- **`Core.Error.PackageError`** — display-neutral error metadata shared by reusable packages. It gives the app a package name, stable code, and context without forcing packages to own localized copy.

## Stores (app)

- **`AppModel`** — root state: bootstraps `Core.Orchestrator`, owns feature stores, tracks bootstrap status, wires logging/updating, and runs the per-tick coordination. Focused extensions own image/resource style lookup, image-update sweeps, and configuration import/export.
- **`ContainersStore`** — the container list, live stats deltas, streamed stats conversion, and lifecycle actions against `Core.Orchestrator`.
- **`RefreshCoordinator`** — adaptive polling for service/list refreshes. Stats are maintained app-wide by one utility-priority runtime stats stream for the running containers, so normal refreshes and lifecycle actions relist containers without forcing vanity stats.
- **`RestartWatchdog`** — app-managed restart policy (`container` has no native `--restart`); diffs states each tick and re-issues `start` with backoff.
- **`HealthMonitor`** — app-managed healthchecks: interval-gated `exec` probes with consecutive-failure tracking.
- **`HistoryStore`** — SwiftData stack for the persistent event log + metric samples (the "rewind" timeline) with bounded retention.
- **`UpdaterController`** — wraps Sparkle; the user's selected update channel chooses a branch-hosted appcast feed. Stable and Beta feeds are branch-local, while Nightly is a superset that also carries promoted release items.
- **`SettingsStore`** — persists appearance, update cadence, logging, material choices, and experimental feature gates. `SettingsBackup` owns the portable export/import shape.
- **`UIState`** — owns navigation, sidebar visibility, toolbar morph state, palette routing, and creation/edit flow handoff. Toolbar grouping/sort/filter enums and one-shot actions live in adjacent navigation files so routing state stays readable.

## Design system

Liquid Glass helpers and reusable primitives include `UI.Panel.Scaffold`, `UI.Panel.Header`, `UI.Panel.Section`, `UI.Panel.Row`, `UI.Panel.Field`, `UI.Card.Scaffold`, `UI.Card.InsetSection`, `UI.Action.Group`, `UI.Action.TextButton`, `UI.Action.ToggleButton`, `UI.Action.SelectionBar`, `UI.State.Banner`, `UI.Surface.Content`, `UI.Surface.Input`, `UI.Command.PreviewBar`, `UI.Control.InfoButton`, `UI.Badge.Status`, `UI.Control.KeyCap`, `UI.Chart.Sparkline`, and `UI.Tokens` groups for toolbar, panel, spacing, radius, icon sizing, design cards, badges, charts, terminal chrome, and form widths. `ContainedUI` owns app-agnostic visual tokens and primitives; feature code should not introduce local spacing, radius, material, shadow, opacity, surface modifiers, glass button styles, or micro-chrome recipes. App-side cards use `UI.Card.Scaffold`; card shell/header/page-rail assembly and low-level glass button/surface routes are package-internal. App-state-aware mappings such as runtime status and graph metric extraction stay in `ContainedApp` until they can cross the boundary without depending on app/core policy. Use the package READMEs for import instructions and copy-pasteable examples, and see [Design System](Design-System.md) for app-level conventions.

## Local-only personalization

Card styles and healthchecks are stored locally (keyed by container id / image reference) — **never** injected as personalization labels, keeping the CLI and containers clean. `Personalization` owns the resolved style shape, `WidgetConfiguration` owns metric widget schema/options, and `PersonalizationStore` owns persistence and inheritance. Functional app-managed labels such as restart policy must round-trip through the container.

## Testing

Package-local tests hold golden-argv tests, decode tests against captured real CLI fixtures, pure decision tests, runtime descriptor contracts, Apple adapter decoding/streaming, create/import translation, unsupported capabilities, typed stats snapshots, design-system layout rules, navigation behavior, and preview fixtures. `Tests/ContainedAppTests` covers app-owned form state, create-request round-trips, and runtime-translated compose mapping. Run with `swift test` at the root or `swift test --package-path Packages/<PackageName>` for a standalone package.
