# System & Settings

System and Settings own runtime status, app preferences, update controls,
experimental gates, registries, and local data management.

## System

The System panel surfaces runtime status, runtime details, resource usage,
image update status, and app/runtime actions.

Runtime controls are rendered from descriptor capabilities. Apple container
currently exposes service lifecycle, kernel, and DNS controls; future runtimes
can expose their own endpoint or management sections without becoming a global
default runtime. Docker adapter groundwork exists in Core but is dormant, so
Docker runtime controls are not shown until Contained has a provider model that
does not depend on Docker Desktop. Privileged kernel or DNS operations may
trigger prompts handled by the CLI or macOS. Contained does not ask for or store
administrator credentials.

The Storage menu separates destructive pruning from Apple Container 1.4.1's
non-destructive compaction. **Compact running containers** asks the runtime to
release blocks for files already deleted inside running container filesystems
and writable named volumes; it does not delete containers or live files.
Stopped-container, image, volume, and network pruning remain explicit,
confirmation-gated actions.

Runtime -> **Storage analysis** separates host-allocated bytes from runtime-reported
logical usage and reclaimable estimates. It breaks allocation into writable container
disks, unpacked image snapshots, content blobs, named volumes, builder VM/cache,
snapshot ingest, and other files. A bounded background metadata scan does not follow
symlinks or read file contents; incomplete results are labeled. Shared layers, sparse
disks, concurrent activity, and upstream accounting gaps mean these totals need not
match and are not exact reclaim predictions.

Each Storage action previews exact identities, consequences, candidate allocation
when known, and CLI commands. Execution refreshes inventory and rejects changed or
five-minute-old previews. Deletion targets only previewed names, without force or a
broad prune against a later inventory. Running/stopped container references, builder
references, and default/system networks are protected. Volume and stopped-container
deletion are irreversible. The combined "Reclaim all" action is replaced with
individually reviewed categories so their different risks cannot be conflated.

Builder cache reset stops/deletes only the builder VM, interrupts external builds,
and discards BuildKit cache. The next build recreates it. Running-builder compaction
is also available without cache deletion. App builds/pulls disable cleanup. Activity
records safe result counts and before/after host allocation; partial failures are
surfaced. Concurrent workload writes can affect the observed allocation difference.

System -> Automation offers **automatic compaction**, off by default. Select running
application containers and/or the running builder, a 1–24-hour interval, and either
a minimum-free-space or maximum-allocated-space threshold. Checks run hourly while
Contained runs, skip incomplete scans/app builds/pulls, and compact at most 16
application containers per run, rotating through eligible identities with a persisted
per-runtime cursor so larger inventories are not starved. Automation never starts/stops containers or deletes
images, volumes, networks, stopped containers, or builder cache. Settings backups
retain this opt-in policy; it is not a macOS-wide scheduled job.

Runtimes without host-storage planning retain their native container/image/volume/
network prune actions. The confirmation names each runtime and explains that its
native prune command selects unused resources at execution; these are not exact
Apple Container inventory previews and never run automatically.

Pull, build, and recreate warn below 5 GiB free; below 1 GiB they pause and link to
System storage. Free-space reporting is advisory when the filesystem cannot provide
it. Unrecognized container directories and ingest entries are **report only**.
Contained never directly deletes Apple Container's internal data files. Generic guest
`/tmp`/cache/log deletion is unsafe: use image-specific cleanup with explicit approval
or truly disposable, size-limited tmpfs paths. Long-running bind-mounted containers
receive a risk advisory about virtio-fs holding deleted host files until stop; it does
not prove files are held, and Contained never stops the workload automatically.

These boundaries follow Apple's [resource usage](https://github.com/apple/container/blob/1.4.1/docs/resource-usage.md)
and [volume](https://github.com/apple/container/blob/1.4.1/docs/volumes.md) guides,
and [periodic cleaning](https://github.com/apple/container/issues/2206),
[unified pruning](https://github.com/apple/container/issues/891),
[virtio-fs deletion](https://github.com/apple/container/issues/2021), and
[`system df` accounting](https://github.com/apple/container/issues/1526) issues.

## Menu-bar runtime center

The optional menu-bar extra is the compact companion to System. It shows one
card per detected runtime with reachability, CLI version, running and stopped
container counts, image count, and capability-scoped start, stop, restart, or
retry controls. The card's System action opens the full management surface.
Run, Activity, and update checks remain available as focused quick actions;
creation, navigation, settings, and support workflows stay in the main app.

## Settings tabs

Settings tabs use native grouped SwiftUI forms inside the shared Settings panel.
Editable rows use the same label-state rules as Run/Edit: red means that row has
a specific issue, and blue means the setting differs from the shipped default.

- General: app behavior, menu bar, CLI previews, metric normalization, info tips, and related defaults.
- Appearance: tint, material, card, panel, and theme choices.
- Data: backup/export/import and local state controls.
- Runtime: runtime reachability, runtime path overrides, and capability-scoped service/kernel/DNS or endpoint controls.
- Registries: registry login/logout and credential management.
- Updates: app channel, Sparkle checks, release notes, and image update cadence.
- Experimental: opt-in feature gates.
- About: app and runtime information.

## Experimental gates

Experimental features default off:

- Command palette
- Docker Hub search
- Compose import
- Image build workspace
- Keyboard shortcuts

Each gate hides or disables the matching menu commands, toolbar affordances, and
creation entry points where applicable.

## Registry update failures

Settings -> Registries shows affected hosts, classified errors, affected tag counts,
retry times, **Retry Now**, and **Refresh Login**. Updates links there when checks fail.
Authentication/token failures coalesce per runtime/registry, with exponential retries
from five minutes to a six-hour cap and one Activity entry per episode. Manual checks,
retry, login/logout, changed credential metadata, and authenticated success reset
backoff. Public tags on the same registry and unrelated registries remain eligible;
network/rate-limit failures pause the affected runtime/registry until retry is due.
Credential changes retain affected references as immediately due until a check
succeeds, so refreshing login cannot hide the retry controls while leaving stale failures.
Not-found and unexpected-response outcomes are distinct from authentication failures.

Apple update checks try anonymous access before reusing accessible registry logins
from Apple's Keychain domain. Background reads never prompt. If macOS denies access,
authorize Contained for the registry item in Keychain Access before retrying. Passwords
are sent only over HTTPS to the same registry authority or Docker's explicit
`auth.docker.io` token service. Other cross-host realms are not automatically trusted;
native runtime pull/login remains available. Manifest/token redirects are not followed.
Credentials/raw authorization responses are never persisted or written to Activity;
diagnostics retain only safe host/code/timing information.

## Local data

Contained stores settings, personalization, templates, health checks, activity
history, image update status, and backups locally. Versioned backup and migration
envelopes protect data created by newer app schema versions.

General -> Data shows the allocated app-database size, including its write-ahead
log. Unchanged inventory, readiness, settings, personalization, and health-check
polls do not rewrite stored records. Activity and metric retention runs on launch
and hourly while recording; SwiftData transaction history is maintained separately
using its supported history API and does not remove app history or templates.
SwiftData retains framework transactions independently of model retention; this
single-process, non-CloudKit store has no external history consumer. Hourly
maintenance clears that framework history rather than treating it as app history.
At the one-minute sample limit, seven-day retention holds at most about 10,141
metric rows per continuously monitored container (10,080 retained minutes plus
the hourly pruning margin). For 32 containers that is about 324,512 rows; stored
bytes vary with SQLite indexes and page allocation. The deterministic three-
container, ten-day simulation verifies the retention window reaches a plateau.

**Maintain Transaction History** requests that maintenance immediately.
**Compact App Database** pauses app writes and uses SQLite checkpoint/VACUUM to
reclaim free database pages. It requires enough temporary free space and reports a
safe error code if the database is busy or space is insufficient. It does not
delete settings, templates, container records, or retained history.

If database reads or saves fail, Contained rolls back pending changes and pauses
new writes until explicit recovery succeeds. Waiting alone never resumes writes.
An alert links to General settings and an explicit retry.
Successful explicit retry reloads saved preferences, registry retry state, and cleanup/
image-update scheduling state, history counts, and loaded recent activity without
saving fallback defaults. It then reruns runtime detection using the restored CLI paths.
Saved image update results are reconciled immediately when live inventory is already
loaded, including invalidating the sweep deadline when a local digest changed.
Repair, missing runtime defaults, and normalization writes are committed together
only after every required recovery read succeeds; failed reads or saves roll them back.
Startup validates the saved schema before duplicate repair or app-store writes.
If a newer saved schema is discovered, writes and repair remain paused until the existing
downgrade decision is explicitly accepted; ordinary retry does not grant acceptance.
Configuration export reads saved personalization and health checks directly without
enabling writes or normalization. Unreadable records abort export instead of producing
a successful-looking backup with missing data.
Forced runtime detection queues behind an in-flight
startup check rather than reusing its pre-recovery configuration.
Diagnostics show only an error domain/code, not database contents or private paths.
Startup/retry consolidates legacy duplicate identities, preserving the newest
snapshot and associated personalization, health checks, migration metadata, and
linked-volume information. Failed startup loads of personalization/health checks
must reload successfully before later edits can replace any stored entries.
App-level identity checks are serialized on the main
actor; asynchronous inventory preparation is discarded if another write intervenes.
Existing stores are repaired before any schema uniqueness migration is attempted.

## Metric normalization

Settings -> General -> Data -> Normalize stats controls how CPU and memory
percentages are scaled across cards, live stats, mini chips, widgets, and
history charts:

- Container: each container card is scaled against that container's configured
  CPU and memory limits.
- Machine: every card is scaled against the available runtime machine CPU and
  memory resources when available, so container usage appears in runtime-wide
  context.

Network and disk widgets remain raw bytes-per-second rates in both modes.
History keeps raw samples on disk and applies the selected normalization mode
when rendering charts, so older samples remain usable if the mode changes. While
live stats are visible, Contained persists at most one metrics sample per minute;
otherwise it requests a low-priority snapshot every five minutes. The selected
history-retention setting controls how far back the horizontally scrollable
history timeline can travel.

The neighboring **List refresh interval** setting controls background service,
container list, and resource-cache polling. Live metric widgets use their own
low-priority runtime stream instead of this interval.
