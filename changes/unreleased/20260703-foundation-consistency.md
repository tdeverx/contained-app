### Architecture

- Split Contained into standalone local packages: `ContainedCore` for backend orchestration, `ContainedUI` for reusable visual primitives, `ContainedUX` for interaction infrastructure, and `ContainedApp` for app-owned SwiftUI, settings, persistence, localization, and feature policy.
- Added a checked-in Xcode workspace and native macOS app target that links the shared `ContainedApp` package product while keeping SwiftPM as the CI, release, signing, packaging, and appcast source of truth.
- Kept deterministic preview/test samples in the separate `ContainedCoreFixtures` product so normal app and distributable builds do not link fixture data.
- Reorganized docs into app, feature, architecture, development, release, package README, DocC, and wiki-map ownership areas.

### Runtime & Creation

- Consolidated runtime contracts, the Core orchestrator, the Apple `container` adapter, command previews, typed runtime methods, typed stats streams, Compose translation, image defaults, and runtime-neutral create/import models inside `ContainedCore`.
- Added open-ended runtime identifiers and disabled per-container runtime selection so future Docker-compatible, Podman, Lima-backed, remote, or other adapters can plug into Core without becoming app-side switches.
- Routed terminal exec, service lifecycle actions, package errors, and reusable-package copy through Core/app-owned presentation boundaries.

### UI & Performance

- Extracted Liquid Glass cards, panels, controls, toolbar chrome, command previews, charts, console surfaces, badges, keycaps, status indicators, tint controls, and contextual tokens into `ContainedUI`.
- Moved toolbar safe-area measurement, morph geometry, panel placement, and single-surface expansion infrastructure into `ContainedUX`.
- Centralized resource-card anatomy in `UI.Card.Scaffold`, with stable headers, sticky large widgets, body-hosted medium/small details, typed page controls, and packaged action/status routes.
- Reduced idle UI churn with one app-wide low-priority stats stream, narrower per-container metric invalidation, lazy long panels, deferred heavyweight expanded-card pages, cached style/tag lookups, and coalesced image refreshes.
- Improved metric rendering with chronological sparkline windows, fixed CPU/memory percentage scales, raw network/disk throughput shapes, configurable CPU/memory normalization, and clearer sub-1% CPU/memory readouts.

### Release & Repository

- Improved PR, release, CodeQL, Dependabot, support, security, issue-template, and release-note workflows so repository checks run for material source/script/workflow/package/test changes without rerunning for docs-only or appcast-only maintenance.
- Tightened release-note generation so stable releases ship full version notes, beta/nightly builds prepend channel changes, empty deltas are skipped deliberately, and release-script fixtures stay isolated unless a changes source is explicitly supplied.
- Added repository validation for script strict mode and headers, workflow path filters, docs indexes, wiki mapping drift, stale names, package-boundary imports, app adapter internals, raw token use, empty source/docs folders, and bundled changelog sync.
- Clarified that `CHANGELOG.md` remains curated version-level release notes while this consolidated change fragment carries PR/build-level deltas.
