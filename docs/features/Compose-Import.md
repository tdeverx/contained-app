# Compose Import

Compose import maps Docker Compose YAML into editable Run forms. It is
experimental and defaults off; enable **Settings → Experimental → Compose
import**.

## Entry points

Compose import can start from:

- paste
- file picker
- drag and drop
- menu command
- command palette action

## Behavior

Compose import fills one or more editable [Run / Edit Form](/docs/features/Run-Edit-Form.md)
entries instead of launching an opaque stack. The selected runtime adapter
translates parsed services into standardized create fields, then the app fills
the global Run/Edit form. Services with images become prefilled runs;
unsupported or ambiguous fields produce warnings.

Important translations:

- relative bind mounts resolve relative to the compose file directory
- `platform` fills the platform picker/custom value
- `network_mode` fills Network
- `stdin_open` and `tty` fill matching toggles
- `env_file` fills env file rows
- `restart: unless-stopped` normalizes to Contained's app-managed Always policy
- healthchecks become app-managed health checks

Target-only ports such as `8080` are skipped with a warning because they do not
provide a host port to publish for this runtime.

## Ownership

The importer should preserve user control: imported values remain editable, the
CLI preview stays visible, and unsupported values are reported rather than
silently guessed.

Runtime-specific import rules belong in the adapter. Apple container currently
owns the Compose-to-`ContainerCreateRequest` translation; future Docker-compatible
or other adapters should return the same standardized fields with their own
warnings and unsupported-operation plans.
