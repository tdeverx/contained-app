# Resources

Resources cover volumes, networks, registries, templates, and activity history.

## Volumes

Volumes can be browsed from the System panel, created, attached during container runs, and
deleted or pruned when appropriate. The panel groups runtime-managed volumes and
host-path or temporary mounts vertically so the source type stays obvious.
Volume styling is local app state and can be used for scan-friendly resource
cards.

## Networks

Networks can be browsed from the System panel, created, attached during container runs, and
deleted or pruned when appropriate. The create-network path is part of the
shared [Creation Workflow](/Documentation/Features/Creation-Workflow.md).

## Registries

Registry credentials live under **Settings → Registries** rather than a
standalone app page. Login pipes credentials via `--password-stdin` so passwords
are not placed in process argv.

Registry actions are still discoverable through menus and the command palette,
but they route to Settings.

## Templates

Templates save reusable container run configurations. Using a template fills the
same [Run / Edit Form](/Documentation/Features/Run-Edit-Form.md) as other creation paths.
They are browsed from the Templates toolbar panel rather than a separate page.

## Activity

Activity is the persistent event log for app operations, lifecycle events,
long-running tasks, and errors. The toolbar Activity panel shows unread state.
