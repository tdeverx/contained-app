# Release

The maintainer runbook for cutting a build and feeding the Sparkle update channels. Most of this is
scripted; the parts that need your Apple credentials or the Sparkle signing key are called out.

## Versioning

- **`CFBundleShortVersionString`** (marketing version) — semver, with a pre-release suffix per channel:
  - Stable: `1.0.0`
  - Beta: `1.0.0-beta.1`, `1.0.0-beta.2`, …
  - Nightly: `1.0.0-nightly.<build>+<shortsha>` (set automatically by CI)
- **`CFBundleVersion`** (build number) — a monotonic integer; `scripts/bundle.sh` derives it from
  `git rev-list --count HEAD`. Sparkle orders updates by this, so it must only ever increase.

Set the marketing version for a manual build with `VERSION=… ./scripts/bundle.sh`.

## Channels

One appcast (`docs/appcast.xml`, served by GitHub Pages) carries all three channels:

- **stable** — items with no `<sparkle:channel>` tag.
- **beta** — items tagged `<sparkle:channel>beta</sparkle:channel>`.
- **nightly** — items tagged `<sparkle:channel>nightly</sparkle:channel>`.

The app's Settings → Updates picker maps to Sparkle's `allowedChannels`: Stable → `{}`, Beta →
`{beta}`, Nightly → `{beta, nightly}` (cumulative).

## One-time setup

1. **Sparkle EdDSA keys** — run Sparkle's `generate_keys` once. It stores the private key in your
   login keychain and prints the public key. Put the public key in `SUPublicEDKey` (in
   `scripts/bundle.sh`'s Info.plist block). **Never commit the private key.** For CI, export it as the
   `SPARKLE_ED_PRIVATE_KEY` repo secret.
2. **Developer ID** — a "Developer ID Application" certificate in your keychain (local signing) and,
   for CI, its `.p12` base64-encoded as `DEVELOPER_ID_CERT_P12` + `CERT_PASSWORD`.
3. **Notarization** — an App Store Connect API key; locally store it with
   `xcrun notarytool store-credentials` and pass the profile name; for CI add
   `NOTARYTOOL_API_KEY` / `NOTARYTOOL_KEY_ID` / `NOTARYTOOL_ISSUER`.
4. **GitHub Pages** — enable Pages serving `/docs` on `main` so the appcast resolves at
   `https://<owner>.github.io/contained-app/appcast.xml` (the `SUFeedURL`).

## Cutting a stable or beta release (local)

```sh
VERSION=1.0.0 ./scripts/release.sh        # build → codesign (Developer ID) → DMG → notarize → staple
./scripts/appcast.sh /path/to/Sparkle/bin updates   # sign DMG(s) + (re)generate docs/appcast.xml
```

Then:

1. Create a GitHub release tagged `v1.0.0` (or `v1.0.0-beta.N`, with **Pre-release** checked for betas);
   upload the `.dmg` as a release asset. The appcast's enclosure URLs point at these assets via
   `--download-url-prefix`.
2. Commit the updated `docs/appcast.xml`. Pages serves it; clients on the matching channel get offered
   the update.

## Nightly (CI)

`.github/workflows/nightly.yml` builds the latest green `main` on every push (newest commit wins via
`concurrency: cancel-in-progress`), signs + notarizes, refreshes the rolling **`nightly`** pre-release
with the new DMG, regenerates the nightly appcast item, and commits `docs/appcast.xml`. It **skips the
sign/notarize/publish steps cleanly when the secrets above are absent**, so the workflow stays green on
a fresh public repo until you add them.

`.github/workflows/release.yml` is the manual (`workflow_dispatch`) equivalent for stable/beta tags.

## Notes

- Sparkle update *integrity* is the EdDSA signature on the appcast — that is the security boundary and
  works regardless of Apple notarization. Notarization is about Gatekeeper on first install; ship
  notarized builds so users aren't warned.
- The private Sparkle key and the Developer ID cert never live in the repo — only as keychain entries
  (local) or encrypted repo secrets (CI).
