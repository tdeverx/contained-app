# Resources

Resources cover volumes, networks, registries, templates, and activity history.

## Volumes

Volumes can be browsed, created, attached during container runs, and
deleted or pruned when appropriate. Volume styling is local app state and can be
used for scan-friendly resource cards.

## Networks

Networks can be browsed, created, attached during container runs, and
deleted or pruned when appropriate. The create-network path is part of the
shared [[Creation Workflow|Creation-Workflow]].

## Registries

Registry credentials live under **Settings → Registries** rather than a
standalone app page. Login pipes credentials via `--password-stdin` so passwords
are not placed in process argv.

Registry actions are still discoverable through menus and the command palette,
but they route to Settings.

## Templates

Templates save reusable container run configurations. Using a template fills the
same [[Run / Edit Form|Run-Edit-Form]] as other creation paths.

## Activity

Activity is the persistent event log for app operations, lifecycle events,
long-running tasks, and errors. The toolbar Activity surface shows unread state
when the experimental toolbar is enabled; the full page remains available from
the sidebar shell.
