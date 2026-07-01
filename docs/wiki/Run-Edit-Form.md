# Run / Edit Form

The Run / Edit form is intentionally UI-first. It bridges Apple's `container run`
flags into controls that feel native on macOS, while the live CLI preview remains
the source of truth for exactly what will execute.

## Design rule

Use a structured control whenever the option has a bounded or recognizable value
space:

- toggles for booleans, such as `--detach`, `--rm`, `--tty`, `--read-only`,
  `--init`, `--ssh`, `--rosetta`, `--virtualization`, and `--no-dns`
- pickers for known option sets, such as platform presets, registry scheme, and
  progress mode
- sliders for host-bounded resource values, such as memory and shared memory
- steppers for small numeric limits, such as concurrent image downloads
- repeatable rows for lists, such as environment variables, labels, ports,
  volumes, sockets, capabilities, DNS servers, tmpfs mounts, ulimits, and env
  files

Keep free-form text fields only where the CLI genuinely accepts arbitrary
strings, paths, names, or raw specs.

## Form structure

The form uses native grouped macOS settings-style sections rather than mirroring
CLI flag order:

- Essentials: image, platform, name, command, and basic run behavior
- Resources: CPU and memory limits
- Networking: published ports, network attachment, and socket forwarding
- Storage: volume mounts
- Environment: variables and env files
- App Managed: restart policy and health checks
- Appearance: local-only card personalization
- Advanced Options: one toggle for process internals, security/runtime
  switches, DNS, raw mounts, and labels

The common sections stay visible. Compose import and Edit open Advanced Options
when they contain advanced values, so imported settings are not lost just because
they live behind the toggle.

The presentation path is shared. With toolbar panel navigation enabled, run and
edit open in the creation morph from their measured toolbar origin. With it
disabled, the same form state opens as a classic sheet so card buttons, menus,
keyboard shortcuts, and palette actions keep one routing model.

## UI abstractions over CLI flags

These controls deliberately do not mirror the CLI one-to-one:

| UI control | CLI output | Notes |
| --- | --- | --- |
| Platform picker | `--platform <os/arch[/variant]>` | The UI offers common Apple-silicon presets plus Custom. Separate `--os` and `--arch` controls are omitted to avoid duplicate platform concepts because `--platform` takes precedence. |
| Memory limit toggle + slider | `--memory <size>` | The user chooses a host-bounded amount; the app formats it as `M` or `G`. |
| Shared memory toggle + slider | `--shm-size <size>` | Same UI pattern as memory, with a small default of `64M`. |
| Registry scheme picker | `--scheme auto\|https\|http` | Empty means runtime default. |
| Progress picker | `--progress auto\|none\|ansi\|plain\|color` | Empty means runtime default. |
| Limit parallel downloads toggle + stepper | `--max-concurrent-downloads <n>` | Empty means runtime default. |
| Disable DNS toggle | `--no-dns` | When enabled, DNS-specific rows are hidden and the command omits `--dns*` flags so the UI cannot express contradictory settings. |
| Restart policy picker | `--label contained.restart=<policy>` | `container` has no native restart flag. Contained stores restart intent as a label and the app watchdog enforces it. |
| Health check section | local app state | `container` has no native healthcheck flag. Contained stores and runs probes itself. |
| Personalization section | local app state | Nickname, icon, tint, and card background are local-only and are not written as container labels. |

## Free-form by design

The following options stay textual because the CLI accepts arbitrary values and
the app should not pretend to know every valid shape:

- image reference, container name, command, entrypoint
- working directory, user, UID/GID
- env file paths
- volume paths and raw `--mount` specs
- socket paths
- label and environment key/value rows
- capability names
- network attachment string, including options such as `mac=` and `mtu=`
- container ID file, runtime handler, init image, kernel path
- DNS search/options, tmpfs entries, and ulimits

## Compose import behavior

Compose import follows the same UI-first rule: it fills editable Run forms rather
than directly launching an opaque stack. The importer maps every Compose service
field that has a Run form equivalent and warns for fields it cannot safely
translate.

Important translations:

- relative bind mounts are resolved relative to the compose file directory
- `platform` fills the platform picker/custom value
- `network_mode` fills Network
- `stdin_open` and `tty` fill the matching toggles
- `env_file` fills env file rows
- `restart: unless-stopped` is normalized to Contained's app-managed `Always`
  policy because user-initiated stops are already suppressed by the watchdog
- healthchecks become app-managed health checks

Unsupported or ambiguous Compose shapes are skipped with warnings instead of
creating partial form rows that would block Run. For example, a target-only port
like `8080` has no host port to publish for this runtime, so it is reported and
not added as an incomplete port row.
