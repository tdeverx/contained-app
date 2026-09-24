- Require Apple Container 1.4.1 or newer; support its expanded runtime status and live storage compaction; add kernel arguments, OCI masked/read-only paths, and build SSH forwarding; preserve new network metadata; and remove obsolete registry and stop-signal command output.

- Verify image-update recreations use the freshly pulled image and survive startup, and surface streamed pull failures instead of reporting false success.

- Fixed container context menus flashing during live metric updates while keeping card footer values and sparklines current.
- Moved expanded-container page commands into the shared card header, which now adapts to Logs, Terminal, and Files.
- Consolidated expanded container metrics into a Statistics page with selectable range and interpolation, independent hourly-snapping history charts, peak-preserving virtualization, latest-first positioning, theme colors, and standard graph padding; moved live metric cards into a flat horizontal Overview lane with the same shadowless card material and radius as the historical graphs, aligned Overview with Run/Edit/Settings section styling, and added a dedicated container Alerts page.
- Made the Overview metric lane edge-to-edge with inset-matched gaps, moved Terminal shell selection into the page header, and placed the transparent terminal layer inside the same shadowless material and corner radius used by Statistics graphs.

# Changes Since Last Nightly

- Group all local tags and versions from the same image repository into one image card while preserving each tag's digest and runtime availability.
- Split the Images panel into Updates and Images pages, with update-aware defaults and page-specific image management controls.
- Reduced panel opening work by projecting and refreshing only the active page.

- Prevented sparkline strokes and marks from clipping at chart boundaries, and expanded container sorting by activity, age, runtime, and attention state.

- Refined image and container cards with clearer tag typography, stable update-check ordering, shared grid elevation, smoother expanded-card shadows, tighter responsive sizing, and more flexible window dimensions.

- Fixed stale image-update badges reappearing after launch by consolidating duplicate persisted tag records and reconciling saved results with the live runtime inventory.
- Simplified navigation around the permanent toolbar and panels, retiring the legacy sidebar and redundant full-page utility routes.
- Made card footer metadata fill and scroll within the space left by intrinsic action buttons, and removed the five-widget limit from container personalization.
- Muted stopped container cards to a grey, softened compact state that restores their configured color and full content emphasis on hover without affecting expanded details.
- Made Containers the sole, flat primary grid; moved Networks into the System panel; and replaced the old page/filter controls with one top-left menu for session-local named groups, sorting, and the running-only filter.
- Unified design-card expansion across containers, images, resources, and palette results with panel-matched radii, non-displacing header controls, and pinned header, widget, and footer chrome.

- Fixed stale image-update badges reappearing after launch by consolidating duplicate persisted tag records and reconciling saved results with the live runtime inventory.
- Simplified navigation around the permanent toolbar and panels, retiring the legacy sidebar and redundant full-page utility routes.
- Made card footer metadata fill and scroll within the space left by intrinsic action buttons, and removed the five-widget limit from container personalization.

### Changed

- Container cards now infer a browser shortcut from their first published TCP port, with an optional per-container URL override for hosts and paths. Appearance inheritance now covers only icon, tint, and background; nickname, URL, status, and widgets remain container-specific. Available updates stay visible as the far-right footer action.
- Image, tag, and container nicknames now stay scoped to the resource being customized. Image and tag names compose in card references (for example, `nice-image:latest`) without nickname-only changes disabling inherited appearance.

### Changed

- Color selectors now lead with the inherited accent and a custom `#RRGGBB` option before SwiftUI's standard Apple color palette. Selecting custom reveals a dedicated “Custom” row using the host form's normal alignment and `#007AFF` as its example. The app-accent picker inherits the native macOS accent; other pickers inherit the selected app accent, which now scopes both native controls and explicit accent-colored selection, navigation, status, chart, and resource chrome throughout the app.
- Shared panel and form rows now move wide controls beneath their labels instead of clipping or squeezing important titles.

### Fixed

- Image and image-group customization now follows normalized image references, preserving existing styles when pulls replace a tag's digest or runtimes report an equivalent reference spelling.

### Fixed

- Rebuilding Apple containers now preserves named volumes instead of treating their backing disk images as bind-mounted directories, and resolves replacement and recovery configuration before deleting the original container.

### Added

- Container cards now surface a dedicated Update action when their image tag has changed, while the context menu provides a safe Rebuild action at all times; both preserve local settings and the container's prior running or stopped state.

### Changed

- The menu-bar extra is now a compact runtime center with a stable sheet-material backdrop, shared System-panel cards, per-runtime status and controls, resource metrics, and focused quick actions.

### Fixed

- Nightly builds now use permanent versioned GitHub releases, preserving older builds for rollback and keeping Sparkle enclosure URLs immutable.

- Fixed Add, Run, and Edit crashing in packaged builds when ContainedCore localization resources were missing.

- Optional Startup settings to start a stopped container engine when Contained opens and to restore stopped containers marked Always after Contained starts that engine.
- Fixed container-grid cards and their detail transition overlapping when a container appears in multiple groups or runtimes.
- Fixed per-container History charts loading no data for runtime-scoped containers.
- Container history now keeps low-overhead, five-minute snapshots while Contained is running but its Containers view is hidden or inactive; charts mark long collection gaps instead of implying uninterrupted data.
- Stabilized the container grid so live metric updates no longer reflow card widths between rows, and tightened its responsive size so three columns fit in a narrower window.

- Optional Startup settings to start a stopped container engine when Contained opens and to restore stopped containers marked Always after Contained starts that engine.
- Fixed container-grid cards and their detail transition overlapping when a container appears in multiple groups or runtimes.
- Fixed per-container History charts loading no data for runtime-scoped containers.
- Container history now keeps low-overhead, five-minute snapshots while Contained is running but its Containers view is hidden or inactive; charts mark long collection gaps instead of implying uninterrupted data.
- Stabilized the container grid so live metric updates no longer reflow card widths between rows.

- Optional Startup settings to start a stopped container engine when Contained opens and to restore stopped containers marked Always after Contained starts that engine.
- Fixed container-grid cards and their detail transition overlapping when a container appears in multiple groups or runtimes.
- Fixed per-container History charts loading no data for runtime-scoped containers.
- Container history now keeps low-overhead, five-minute snapshots while Contained is running but its Containers view is hidden or inactive; charts mark long collection gaps instead of implying uninterrupted data.

- Optional Startup settings to start a stopped container engine when Contained opens and to restore stopped containers marked Always after Contained starts that engine.

# Faster, smoother navigation

- Made the experimental toolbar-first interface more responsive at idle and while moving between pages by removing persistent-data work from navigation controls.
- Improved container-grid scrolling, grouping, resizing, and card transitions with lighter compact graphs and less layout work during rendering.
- Made Activity, container History, and Logs faster to open and switch between by using bounded caches, cancellable history loads, and stable batched console updates.
- Reduced background refresh overhead by skipping unchanged inventory writes and preparing only containers whose stored details actually changed.
- Expanded SwiftPM and native Xcode coverage for these performance paths and documented repeatable Instruments checks for future regressions.

### Changed

- Replaced avoidable AppKit panels, pasteboard writes, haptics, and WebView bridges with SwiftUI-native file, copy, feedback, and WebKit surfaces while keeping AppKit isolated to platform wrappers, SwiftTerm hosting, and material/vibrancy support.

### Fixed

- Bundle the generated current release notes artifact into local app builds so in-app What's New matches the CI/Appcast release-note source.
- Harden container recreate after stale runtime snapshots and reduce repeated optional-runtime endpoint errors in Activity.
- Validate replacement and rollback recipes before destructive container edits, automatically restore the original after replacement failure, and retain its recipe when restoration also fails.
- Link Core fixtures only into the native Xcode test target and run that suite in PR CI so the Xcode and SwiftPM package graphs cannot drift silently.
- Keep raw CLI commands, stderr, paths, environment values, and credentials out of persistent Activity and public Console diagnostics while retaining runtime detail in immediate errors.

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
- Made Reveal CLI command previews render from each selected runtime descriptor instead of hardcoding the Apple `container` executable in the reusable UI package.
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
