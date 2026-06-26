# DMG assets (optional overrides)

`scripts/make-dmg.sh` builds a styled, vertical "drag to Applications" DMG per channel. It needs
**nothing** in here to look good — it auto-generates a tinted background (via
`scripts/dmg-background.swift`) and uses the main app icon as the volume icon. Drop files in to
override those defaults:

| File | Overrides | Falls back to |
|------|-----------|---------------|
| `background-<channel>.png` | The window background. 380×560 px (the window size — Finder paints it 1:1, so match these dimensions exactly). | Auto-generated tinted background. |
| `volume-<channel>.icns` | The mounted-volume icon. | `Resources/Contained.icns` (the main icon), then the system default. |

`<channel>` is `stable`, `beta`, or `nightly`.

When you build the real per-channel icons (see `Resources/IconKit/`), export each as `.icns` here as
`volume-<channel>.icns`, and optionally design matching backgrounds to replace the generated ones.
