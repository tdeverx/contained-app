# DMG assets (optional overrides)

`scripts/make-dmg.sh` builds a styled, vertical "drag to Applications" DMG per channel. It needs
**nothing** in here to look good — it auto-generates a tinted background (via
`scripts/dmg-background.swift`) and uses the main app icon as the volume icon. Drop files in to
override those defaults:

| File | Overrides | Falls back to |
|------|-----------|---------------|
| `background-<channel>.tiff` or `.png` | The window background. For Retina, supply a HiDPI `.tiff` (1× + 2× via `tiffutil -cathidpicheck bg.png bg@2x.png -out bg.tiff`); a plain `.png` must be 380×560 (the window size, painted 1:1). `.tiff` wins if both exist. | Auto-generated HiDPI background. |
| `volume-<channel>.icns` | The mounted-volume icon. | `Resources/Contained.icns` (the main icon), then the system default. |

`<channel>` is `stable`, `beta`, or `nightly`.

When you build the real per-channel icons (see `Resources/IconKit/`), export each as `.icns` here as
`volume-<channel>.icns`, and optionally design matching backgrounds to replace the generated ones.
