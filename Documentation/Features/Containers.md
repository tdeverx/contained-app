# Containers

The Containers page is the main workload surface. When more than one runtime is
available, the grid aggregates containers from every reachable runtime.

## Grid and cards

- Personalized Liquid Glass cards show status, image, command, resource
  highlights, and local-only appearance choices.
- Card appearance (icon, tint, and background) can be set per container or
  inherited from image styling. Container-only choices such as nickname, web
  destination, status display, and widgets remain independently editable.
- Image, tag, and container nicknames are separate identities. Cards compose
  image and tag nicknames into compact references such as `nice-image:latest`,
  while a container keeps its own title.
- Local personalization is not written back to container labels.
- A card shows an **Open in browser** action when the container publishes a TCP
  port. Customize can supply a full URL or host/path override; otherwise the
  first published port opens on localhost.
- Cards expose full-card hit targets plus context actions for lifecycle and edit
  operations.
- The top-left group menu can create and switch between named, session-local
  container groups. Use **Add to Group** in a container's context menu to change
  membership; **All Containers** returns to the complete grid.

## Lifecycle

Container actions route through the shared app model and each container's
owning runtime:

- start
- stop
- restart
- delete
- refresh
- edit
- rebuild from the image currently behind the container's tag
- update when that tag has changed locally or a newer remote image is available

Rebuild is always available from a container's context menu. When the app knows
that the container's immutable image identity differs from the current tag—or a
newer registry digest is available—the action is relabeled **Update Container**
and an orange update button appears persistently at the far right of the card
footer. Updating pulls first only
when needed, then recreates through the same rollback path as Edit → Save.
Rebuild and Update preserve whether the container was running or stopped, while
ordinary Start, Stop, and Restart remain non-destructive lifecycle operations.

The app serializes refreshes around lifecycle actions so a user action and the
background polling tick do not fight over inventory and stats streams. While the
Containers screen is hidden or Contained is inactive, a five-minute, per-runtime
batched snapshot keeps persistent history current without a continuous stream.
Sampling stops when the app quits, and runtime identity is part of each
container's internal key, so Apple and Docker containers with the same runtime
ID do not collide.

## Detail

Expanded container detail surfaces include:

- Overview
- Logs
- Terminal
- Statistics
- Alerts
- Files

The expanded card header adapts to the active page. Page-wide commands such as
following, copying, or clearing logs; reconnecting a terminal; and navigating,
importing, or refreshing files stay in one consistent header action group.
Terminal shell selection also lives in that header, while the terminal content
uses the same flat card material and radius as the Statistics graphs.
Status readouts remain with their page content. Overview uses the same grouped
section rhythm as Run, Edit, and Settings, with live metric cards in an edge-to-edge
horizontal scroll lane whose gaps match the page inset. The Statistics header selects a 1, 6, 12, or 24-hour viewport and
the interpolation used by every chart. CPU, memory, network-in, network-out, disk-read, and
disk-write charts each independently scroll through the retained timeline and
settle on hourly boundaries. Visible scales update after scrolling settles, and
reduced long histories retain their low/high envelope instead of averaging short
peaks away. Charts retain the full scrollable time domain while rendering only a
small nearby buffer, keeping narrow 1-hour and 6-hour viewports responsive. They
open with the newest sample at the right edge, use the container's resolved theme
color, and retain the standard inset inside their rounded material surfaces.
Container-scoped lifecycle, health, image, and watchdog notifications live on
the Alerts page rather than being mixed into Statistics.

Expanded views use the same toolbar safe-area contract as morph panels, clearing
the permanent top and bottom toolbar bands.

## Restart and health

Apple `container` has no native restart policy or healthcheck. Contained stores
restart intent and health probes as app-managed state, runs probes through the
container's owning runtime, and records events in Activity and the container's
Alerts page.

In **Settings → General → Startup**, you can independently opt in to starting a
stopped controllable engine when Contained opens and to restoring stopped
containers marked **Always** after Contained starts that engine. The latter also
applies to Contained's Start Service and Restart Service actions. It does not
run when an already-running engine is merely detected, and **On failure** stays
reserved for live crash recovery.

## Edit

Container edit opens the same [Run / Edit Form](/Documentation/Features/Run-Edit-Form.md) used for new
containers in the [Creation Workflow](/Documentation/Features/Creation-Workflow.md) morph.

Runtime configuration is immutable, so saving an edit recreates the container.
Contained validates the replacement and a snapshot-derived rollback recipe before
deleting anything. If replacement creation then fails, Core automatically tries
to restore the original container. A failed restoration keeps the original recipe
in the app database for recovery; data that was not stored in volumes cannot be
reconstructed.
