### Changed

- Replaced avoidable AppKit panels, pasteboard writes, haptics, and WebView bridges with SwiftUI-native file, copy, feedback, and WebKit surfaces while keeping AppKit isolated to platform wrappers, SwiftTerm hosting, and material/vibrancy support.

### Fixed

- Bundle the generated current release notes artifact into local app builds so in-app What's New matches the CI/Appcast release-note source.
- Harden container recreate after stale runtime snapshots and reduce repeated optional-runtime endpoint errors in Activity.

### Runtime & Images

- Added dormant Docker CLI adapter groundwork in `ContainedCore`, with Docker command builders, decoders, create/Compose translation, runtime descriptors, CLI discovery, and direct adapter tests kept out of the default app registry.
- Kept Docker disabled in the default runtime registry so Contained discovers, probes, and offers Apple `container` only until a Docker provider model is chosen.
- Added runtime-scoped resource routing and image/tag models so future runtimes can aggregate containers and expose runtime-specific local image availability through each resource's owning runtime.
- Added runtime-scoped settings records; Apple service, kernel, and DNS controls remain Apple-only while dormant Docker path/endpoint UI stays hidden by default.
- Kept V1 image storage runtime-owned while centralizing registry search, remote digest/update metadata, and normalized tag grouping across runtimes.
- Scoped local image update comparisons to each runtime-owned tag so one runtime can be current while another has an update available for the same image reference.
- Removed implicit runtime fallbacks so create, pull, build, load, push, registry, network, volume, logs, stats, terminal, and migration actions route through an explicit runtime or an existing resource owner.
- Split registered runtime clients from ready runtime endpoints while keeping Apple-only service controls explicitly Apple-scoped.
- Hardened the Core runtime boundary with module-driven Apple container and Docker adapters, runtime-keyed CLI overrides/readiness, runtime-owned schema profiles, and static checks preventing concrete runtime behavior from leaking out of `Runtimes/**`.
- Moved the built-in module registry into shared `Runtime` infrastructure, kept `Runtimes/**` for concrete adapters only, and made canonical schema fields runtime-neutral while adapter profiles own support state and tips.
- Tightened the runtime cleanup pass by splitting Core runtime/Compose helpers, surfacing partial inventory failures, removing app-side Apple defaults from unowned flows, and recording typed app-database failures instead of crashing on corrupt records.
- Replaced alert-based runtime picking for no-context Compose/image archive imports with an in-app runtime selection sheet that preselects only when one compatible runtime is available.
- Moved migration visibility and runtime move progress into the app database/Core migration flow, retaining disappeared resources only when they carry Contained-owned value.
- Fixed the container-card morph regression by keying measured card frames and expanded overlays by runtime-scoped container IDs.

### Architecture

- Split Contained into standalone local packages: `ContainedCore` for backend orchestration, `ContainedUI` for reusable visual primitives, `ContainedUX` for interaction infrastructure, and `ContainedApp` for app-owned SwiftUI, settings, persistence, localization, and feature policy.
- Added a checked-in Xcode workspace and native macOS app target that links the shared `ContainedApp` package product while keeping SwiftPM as the CI, release, signing, packaging, and appcast source of truth.
- Kept deterministic preview/test samples in the separate `ContainedCoreFixtures` product so normal app and distributable builds do not link fixture data.
- Reorganized docs into app, feature, architecture, development, release, package README, DocC, and wiki-map ownership areas.

### Runtime & Creation

- Consolidated runtime contracts, the Core orchestrator, the Apple `container` adapter, command previews, typed runtime methods, typed stats streams, Compose translation, image defaults, and runtime-neutral schema/import models inside `ContainedCore`.
- Added open-ended runtime identifiers and runtime-scoped resource routing so future Docker, Podman, Lima-backed, remote, or other adapters can plug into Core without becoming app-side switches.
- Replaced the app-owned Run/Edit request shape with Core-published schema documents that carry generic field paths, Apple/Docker/Compose source aliases, runtime-specific tips, disabled-field explanations, provenance, schema-conformance migration, and Apple `--os`/`--arch` support.
- Routed terminal exec, service lifecycle actions, package errors, and reusable-package copy through Core/app-owned presentation boundaries.

### UI & Performance

- Extracted Liquid Glass cards, panels, controls, toolbar chrome, command previews, charts, console surfaces, badges, keycaps, status indicators, tint controls, and contextual tokens into `ContainedUI`.
- Moved toolbar safe-area measurement, morph geometry, panel placement, and single-surface expansion infrastructure into `ContainedUX`.
- Added colocated SwiftUI previews for design-system and UX primitives, removed the separate preview-only source directories, and documented that design previews live beside each element declaration.
- Introduced package-internal `ContainedUI/Shared` helpers for repeated capsule, swatch, label, row, and surface-rendering anatomy while keeping app-facing calls on the public `UI.*` routes.
- Centralized resource-card anatomy in `UI.Card.Scaffold`, with stable headers, sticky large widgets, body-hosted medium/small details, typed page controls, and packaged action/status routes.
- Reworked Run/Edit storage into Storage Groups, where each group can hold multiple host/internal paths and can optionally be backed by one runtime volume with Contained-managed symlinks.
- Reworked Run/Edit storage rows into one native form section per storage group, with labeled host folder, internal path, and explicit Read only/Read/Write access controls instead of a compact toggle.
- Moved Run/Edit and Settings back onto native grouped SwiftUI forms and section footers, added a Run/Edit header page switcher, and moved Run/Save to the command-preview footer while preserving row-level info popovers.
- Kept grouped form viewports transparent so only native section backgrounds carry the form surface.
- Added form label state colors so field-specific errors render red and changed-from-default rows render blue.
- Reworked the Volumes page into vertical runtime-volume and host-path mount card groups, with runtime-scoped inventory keys so same-named volumes from future runtimes remain distinct.
- Reduced idle UI churn with one app-wide low-priority stats stream, narrower per-container metric invalidation, lazy long panels, deferred heavyweight expanded-card pages, cached style/tag lookups, and coalesced image refreshes.
- Improved metric rendering with chronological sparkline windows, fixed CPU/memory percentage scales, raw network/disk throughput shapes, configurable CPU/memory normalization, and clearer sub-1% CPU/memory readouts.

### Release & Repository

- Improved PR, release, CodeQL, Dependabot, support, security, issue-template, and release-note workflows so repository checks run for material source/script/workflow/package/test changes without rerunning for docs-only or appcast-only maintenance.
- Capped PR, Nightly, Beta, and Stable macOS CI jobs with explicit 30-minute timeouts so wedged SwiftPM builds do not burn the six-hour GitHub Actions default.
- Tightened release-note generation so stable releases ship full version notes, beta/nightly builds prepend channel changes, empty deltas are skipped deliberately, and release-script fixtures stay isolated unless a changes source is explicitly supplied.
- Added repository validation for script strict mode and headers, workflow path filters, docs indexes, wiki mapping drift, stale names, package-boundary imports, app adapter internals, raw token use, empty source/docs folders, and bundled changelog sync.
- Clarified that `CHANGELOG.md` remains curated version-level release notes while this consolidated change fragment carries PR/build-level deltas.
