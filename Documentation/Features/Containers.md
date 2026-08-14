# Containers

The Containers page is the main workload surface. When more than one runtime is
available, the grid aggregates containers from every reachable runtime.

## Grid and cards

- Personalized Liquid Glass cards show status, image, command, resource
  highlights, and local-only appearance choices.
- Card personalization can be set per container or inherited from image styling.
- Local tint, nickname, icon, and card background are not written back to
  container labels.
- Cards expose full-card hit targets plus context actions for lifecycle and edit
  operations.

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
and an orange update button appears in the card footer. Updating pulls first only
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
- Stats
- History
- Files

Expanded views use the same toolbar safe-area contract as morph panels, clearing
top and bottom toolbar bands when the experimental toolbar is visible.

## Restart and health

Apple `container` has no native restart policy or healthcheck. Contained stores
restart intent and health probes as app-managed state, runs probes through the
container's owning runtime, and records events in Activity/History.

In **Settings → General → Startup**, you can independently opt in to starting a
stopped controllable engine when Contained opens and to restoring stopped
containers marked **Always** after Contained starts that engine. The latter also
applies to Contained's Start Service and Restart Service actions. It does not
run when an already-running engine is merely detected, and **On failure** stays
reserved for live crash recovery.

## Edit

Container edit opens the same [Run / Edit Form](/Documentation/Features/Run-Edit-Form.md) used for new
containers. Toolbar panel navigation opens it in the [Creation Workflow](/Documentation/Features/Creation-Workflow.md)
morph; classic routing opens the same form state as a sheet.

Runtime configuration is immutable, so saving an edit recreates the container.
Contained validates the replacement and a snapshot-derived rollback recipe before
deleting anything. If replacement creation then fails, Core automatically tries
to restore the original container. A failed restoration keeps the original recipe
in the app database for recovery; data that was not stored in volumes cannot be
reconstructed.
