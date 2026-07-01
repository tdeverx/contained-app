# Release

The maintainer runbook for cutting a build and feeding the Sparkle update channels. Most of this is scripted; the parts that need Apple credentials or the Sparkle signing key are called out. For just installing or building, see [[Installation]].

## Versioning

- **`CFBundleShortVersionString`** (marketing version) — semver, with a pre-release suffix per channel:
  - Stable: `1.0.0`
  - Beta: `1.0.0-beta.1`, `1.0.0-beta.2`, …
  - Nightly: `1.0.0-nightly.<build>+<shortsha>` (set automatically by CI)
- **`CFBundleVersion`** (build number) — a monotonic integer; `scripts/bundle.sh` derives it from `git rev-list --count HEAD`. Sparkle orders updates by this, so it must only ever increase.

Set the marketing version for a manual build with `VERSION=… ./scripts/bundle.sh`.

## Channels

Each channel owns an independent `appcast.xml` at the root of its branch, served through `raw.githubusercontent.com`:

- **stable** — `stable/appcast.xml`
- **beta** — `beta/appcast.xml`
- **nightly** — `nightly/appcast.xml`

The app's Settings → Updates picker changes the feed URL. Appcast items do not need `<sparkle:channel>` tags because the selected branch feed is the channel.

## One-time setup

1. **Sparkle EdDSA keys** — run Sparkle's `generate_keys` once. It stores the private key in your login keychain and prints the public key. Put the public key in `SUPublicEDKey` (in `scripts/bundle.sh`'s Info.plist block). **Never commit the private key.** For CI, export it as the `SPARKLE_ED_PRIVATE_KEY` repo secret.
2. **Developer ID** — a "Developer ID Application" certificate in your keychain (local signing) and, for CI, its `.p12` base64-encoded as `DEVELOPER_ID_CERT_P12` + `CERT_PASSWORD`.
3. **Notarization** — an App Store Connect API key; locally store it with `xcrun notarytool store-credentials` and pass the profile name; for CI add `NOTARYTOOL_API_KEY` / `NOTARYTOOL_KEY_ID` / `NOTARYTOOL_ISSUER`.
4. **Branch feeds** — each release branch serves its root `appcast.xml` through `https://raw.githubusercontent.com/tdeverx/contained-app/<branch>/appcast.xml`.

## Cutting a stable or beta release (local)

```sh
VERSION=1.0.0 ./scripts/release.sh                 # build → codesign → DMG → notarize → staple
./scripts/appcast.sh /path/to/Sparkle/bin updates  # embed notes + generate root appcast.xml
```

Then:

1. Create a GitHub release tagged `v1.0.0` (or `v1.0.0-beta.N`, with **Pre-release** checked for betas); upload the `.dmg` as a release asset. The appcast's enclosure URLs point at these assets via `--download-url-prefix`.
2. Commit the updated root `appcast.xml` back to the same branch that owns the channel. Clients on that channel get offered the update.

## Nightly (CI)

`.github/workflows/nightly.yml` builds the latest green `nightly` on every push (newest commit wins via `concurrency: cancel-in-progress`), signs + notarizes, refreshes the rolling **nightly** pre-release with the new DMG, regenerates the nightly appcast item, and commits root `appcast.xml` to the `nightly` branch. It **skips the sign/notarize/publish steps cleanly when the secrets above are absent**, so the workflow stays green on a fresh public repo until you add them.

`.github/workflows/release.yml` is the manual (`workflow_dispatch`) equivalent for stable/beta tags.

> **Note:** GitHub doesn't yet offer macOS 26 / Xcode 26 runners. Both workflows detect the runner's Xcode version and skip the build (staying green) until a macOS 26 image is available — bump `runs-on` then.

## Notes

- Sparkle update *integrity* is the EdDSA signature on the appcast — that is the security boundary and works regardless of Apple notarization. Notarization is about Gatekeeper on first install; ship notarized builds so users aren't warned.
- The private Sparkle key and the Developer ID cert never live in the repo — only as keychain entries (local) or encrypted repo secrets (CI).
