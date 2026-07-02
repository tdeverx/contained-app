# Features

Contained is organized around a small set of feature areas and shared workflows.
The classic sidebar is the default shell, with full-page destinations for
Containers, Images, Volumes, Networks, System, Templates, Activity, and Settings.
Toolbar-first UI and toolbar panel navigation are experimental opt-ins from
**Settings → Experimental**.

## Feature areas

- **[Containers](/docs/features/Containers.md)** — lifecycle, detail pages, logs,
  terminal, stats, files, app-managed restart/health, and local card
  personalization.
- **[Images](/docs/features/Images.md)** — local images and tags, run, pull, load/save,
  tag, push, history, image updates, Docker Hub search, and the build workspace.
- **[Resources](/docs/features/Resources.md)** — volumes, networks, registries,
  templates, and activity history.
- **[System & Settings](/docs/app/System-Settings.md)** — service status, runtime defaults,
  app settings, experimental gates, updates, and local data.

## Shared workflows

- **[Creation Workflow](/docs/features/Creation-Workflow.md)** — the shared front door for run,
  edit, pull/search, compose import, network creation, volume creation, and image
  build work.
- **[Run / Edit Form](/docs/features/Run-Edit-Form.md)** — native controls over `container run`
  flags with a live CLI preview.
- **[Compose Import](/docs/features/Compose-Import.md)** — paste, pick, or drag Compose YAML into
  editable run forms.
- **[Command Palette](/docs/features/Command-Palette.md)** — fuzzy app-wide action index.
- **[Updates](/docs/app/Updates.md)** — Sparkle app updates, branch appcasts, image update checks,
  and release notes.

## Throughout

- Persistent history feeds per-container History and system-wide Activity.
- App-managed restart and health checks cover behavior not provided by the
  `container` CLI.
- Local personalization stays local to Contained instead of being written back
  to container labels.
- Accessibility settings such as Reduce Transparency and Reduce Motion are
  respected where the UI supplies custom visual effects or animation.
