# Contained — Icon Composer layer kit

Layered vector source for building the app icon in **Icon Composer** (ships with Xcode 26). The
artwork here is deliberately **flat**: full-bleed 1024×1024, no rounded mask, no gloss, no shadow.
Icon Composer applies the squircle mask and all the Liquid Glass (specular, refraction, blur,
shadow, and the light/dark/clear/tinted variants) on top.

## Layers (bottom → top)

| Order | File | Notes |
|------|------|-------|
| 1 (bottom) | `icon-background-<channel>.svg` | The tint plane. Pick one per channel. |
| 2 | `icon-mark-cube.svg` | The shared container/cube mark (white, 3 faces for depth). |
| 3 | `icon-mark-highlight.svg` | Faint specular catch over the top face. Optional but recommended. |
| 4 (top) | `icon-ribbon-<channel>.svg` | **Beta / Nightly only.** Leave off for Stable. |

Backgrounds: `stable` = blue, `beta` = amber, `nightly` = indigo.

## Build each channel in Icon Composer

1. **New icon.** Set the canvas to 1024×1024.
2. Drag `icon-background-<channel>.svg` in as the **bottom** layer (or set it as the background fill).
3. Add `icon-mark-cube.svg` as a layer; put it in a **Liquid Glass** group so the system frosts it.
4. Add `icon-mark-highlight.svg` above the cube as a **specular/highlight** layer.
5. **Beta/Nightly only:** add `icon-ribbon-<channel>.svg` as the top layer.
6. Tune blur / translucency / shadow to taste, preview the dark + tinted variants, then **export**.

Repeat 3× (stable / beta / nightly), changing only the background and ribbon.

## Feeding the build

Our app bundle is assembled by `scripts/bundle.sh`, which copies `Resources/Contained.icns`.
Export a **1024 PNG** (or `.icns`) from Icon Composer and run `scripts/make-icon.sh` to produce the
`.icns` the bundle uses. (Full dynamic `.icon` adoption would need an asset catalog, which the
hand-assembled SPM bundle doesn't have yet — a later step.)

The same exported PNGs double as the **volume icon** and feed the DMG backgrounds, so the installer
and the app stay visually in sync per channel.

## Tweaks

- **Text ribbons:** if Icon Composer substitutes the font, outline the ribbon text to paths first.
  At very small sizes the ribbon text is illegible by design — it's there for Dock/Finder/DMG sizes;
  the menu-bar extra uses its own SF Symbol, not this icon.
- **The mark:** `icon-mark-cube.svg` is plain geometry on purpose. Swap in richer container artwork
  (seams, a lid, rounded edges) without changing the other layers.
