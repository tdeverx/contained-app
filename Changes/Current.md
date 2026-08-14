### Changed

- Container cards now infer a browser shortcut from their first published TCP port, with an optional per-container URL override for hosts and paths. Appearance inheritance now covers only icon, tint, and background; nickname, URL, status, and widgets remain container-specific. Available updates stay visible as the far-right footer action.
- Image, tag, and container nicknames now stay scoped to the resource being customized. Image and tag names compose in card references (for example, `nice-image:latest`) without nickname-only changes disabling inherited appearance.
