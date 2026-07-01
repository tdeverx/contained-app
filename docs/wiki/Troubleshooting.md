# Troubleshooting

## "Couldn't find the `container` CLI"

Contained shells out to Apple's `container` binary. If onboarding can't find it:

- Install it from the [container releases](https://github.com/apple/container) (it lands in `/usr/local/bin` or `/opt/homebrew/bin`).
- If it's somewhere else, set the full path in **Settings → General → Container CLI path**.
- Confirm in a terminal: `container --version` should print `1.0.0`.

## The runtime service won't start

The onboarding screen runs `container system start`. If it fails:

- Run `container system start` yourself in a terminal and read the error.
- A first-time **kernel install** may be required — Contained surfaces this; it can trigger an admin-password prompt handled by the CLI. The app never asks for or stores your password.

## A privileged action asks for a password

Kernel and DNS operations (System → Kernel & DNS) may prompt for admin rights. That prompt comes from the `container` CLI / macOS, not Contained. Use **Reveal CLI** on the action to see the exact command before running it.

## Updates do nothing / "Check for Updates" is greyed out

- The updater is **inert in development builds** by design — it only runs in a signed release build pointed at the appcast feed.
- Make sure you installed a released `.dmg` (see [[Installation]]), not a locally-built `Contained.app`.
- Check your channel in **Settings → Updates**. Each channel reads its own branch-hosted appcast feed, and fresh pre-1.0 installs default to Nightly.

## I want bleeding-edge / pre-release builds

Switch **Settings → Updates → Update channel** to **Beta** or **Nightly**. Nightly is rebuilt from the `nightly` branch and may be rough. You can switch back to Stable at any time; you'll simply wait for the next stable build to catch up.

## Stats look choppy / not real-time

The `container stats --format json` command emits one frame and then blocks, so Contained **polls** on an interval rather than streaming. This is expected — adjust the cadence in **Settings → General → Refresh interval**.

## A container keeps restarting

That's the **app-managed restart policy** (`container` has no native `--restart`). Check the container's restart policy in its Edit form, or its healthcheck (a failing healthcheck can trigger a restart). The History tab shows the restart/health events.

## My personalization disappeared after recreating a container

Card styles are stored locally, keyed by container id (its stable name) with an image-level fallback — they are **not** written as container labels. Edit-in-place preserves the name so styles re-attach. If you delete and recreate with a different name, set the style to apply per-image so it follows the image.

## Reset preferences / local history

```sh
defaults delete com.contained.app
rm -rf ~/Library/Application\ Support/Contained
```

Your containers, images, and volumes belong to the `container` runtime and are untouched.

---

Still stuck? [Open an issue](https://github.com/tdeverx/contained-app/issues).
