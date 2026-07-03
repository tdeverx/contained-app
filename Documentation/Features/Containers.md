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
- update image when an image update is available

The app serializes refreshes around lifecycle actions so a user action and the
background polling tick do not fight over inventory and stats streams. Runtime
identity is part of each container's internal key, so Apple and Docker
containers with the same runtime ID do not collide.

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

## Edit

Container edit opens the same [Run / Edit Form](/Documentation/Features/Run-Edit-Form.md) used for new
containers. Toolbar panel navigation opens it in the [Creation Workflow](/Documentation/Features/Creation-Workflow.md)
morph; classic routing opens the same form state as a sheet.
