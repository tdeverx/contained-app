# Features

Contained is organized around a small set of feature areas and shared workflows.
Containers is the permanent workload page. Images, System resources, Templates,
Activity, Settings, and creation or editing workflows open as focused toolbar panels.

## Feature areas

- **[Containers](/Documentation/Features/Containers.md)** — lifecycle, detail pages, logs,
  terminal, stats, files, app-managed restart/health, and local card
  personalization.
- **[Images](/Documentation/Features/Images.md)** — local images and tags, run, pull, load/save,
  tag, push, history, image updates, Docker Hub search, and the build workspace.
- **[Resources](/Documentation/Features/Resources.md)** — volumes, networks, registries,
  templates, and activity history.
- **[System & Settings](/Documentation/App/System-Settings.md)** — runtime status, runtime controls,
  app settings, experimental gates, updates, and local data.

## Shared workflows

- **[Creation Workflow](/Documentation/Features/Creation-Workflow.md)** — the shared front door for run,
  edit, pull/search, compose import, network creation, volume creation, and image
  build work.
- **[Run / Edit Form](/Documentation/Features/Run-Edit-Form.md)** — native controls over `container run`
  flags with a live CLI preview.
- **[Compose Import](/Documentation/Features/Compose-Import.md)** — paste, pick, or drag Compose YAML into
  editable run forms.
- **[Command Palette](/Documentation/Features/Command-Palette.md)** — fuzzy app-wide action index.
- **[Updates](/Documentation/App/Updates.md)** — Sparkle app updates, branch appcasts, image update checks,
  and release notes.

## Throughout

- Persistent history feeds per-container History and system-wide Activity while Contained is running; it uses a low-overhead five-minute snapshot when live container stats are not visible.
- App-managed restart and health checks cover behavior not provided by the
  `container` CLI.
- Local personalization stays local to Contained instead of being written back
  to container labels.
- Accessibility settings such as Reduce Transparency and Reduce Motion are
  respected where the UI supplies custom visual effects or animation.
