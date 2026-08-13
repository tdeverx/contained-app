# Release

The maintainer runbook for cutting a build and feeding the Sparkle update channels. Most of this is scripted; the parts that need Apple credentials or the Sparkle signing key are called out. For just installing or building, see [Installation](/Documentation/App/Installation.md).

## Versioning

- **`CFBundleShortVersionString`** (marketing version) — semver, with a pre-release suffix per channel:
  - Stable: `1.0.0`
  - Beta: `1.0.0-beta.<build>+<shortsha>`
  - Nightly: `1.0.0-nightly.<build>+<shortsha>` (set automatically by CI)
- **`CFBundleVersion`** (build number) — a monotonic integer. `Scripts/package.sh version build` is the single source of truth for scripts and CI; no workflow should calculate or validate a build number directly. The script rejects non-numeric build values. Beta/stable workflows first try to reuse the matching nightly appcast build for the promoted commit, then fall back to `git rev-list --count HEAD`. Sparkle orders updates by this, so it must be retained across nightly, beta, and stable for the same promoted build.

Set the marketing version for a manual build with `VERSION=… ./Scripts/package.sh app`. `Scripts/package.sh notarized` defaults to the Stable channel; set `CHANNEL=beta` only when intentionally cutting a beta locally.

## Channels

Each channel has an `appcast.xml` at the root of its branch, served through `raw.githubusercontent.com`:

- **stable** — `stable/appcast.xml`
- **beta** — `beta/appcast.xml`
- **nightly** — `nightly/appcast.xml`, a superset feed containing the newest nightly item plus promoted beta/stable items

The app's Settings → Updates picker changes the feed URL. Appcast items do not need `<sparkle:channel>` tags because the selected branch feed is the channel.

## Release Notes

Release notes are composed by `Scripts/notes.sh body` and embedded by `Scripts/notes.sh html`.
`Scripts/package.sh app` also writes the same generated Markdown to `CurrentReleaseNotes.md` inside the
app bundle so the in-app What's New view reads the current build artifact instead of reconstructing
notes from the source changelog.

- Stable ships `Full Release Notes` for the base marketing version, such as `1.0.0`.
- Beta ships `Changes Since Last Beta` followed by `Full Release Notes`.
- Nightly ships `Changes Since Last Nightly` followed by `Full Release Notes`.

Keep `CHANGELOG.md` curated and version-level. It should describe durable
user-facing release notes for a version, not every PR, internal refactor, or
build-specific detail. Use the rolling note files for channel/build deltas:

- `Changes/Current.md` — the current PR/build note. Nightly consumes it, then CI prepends it into `Changes/Beta.md` and clears it.
- `Changes/Beta.md` — accumulated notes since the last beta. Beta consumes it, then CI clears it.
- `CHANGELOG.md` — full version notes used by Stable, Beta, and Nightly.

The note composer still accepts explicit override sources for local release
maintenance and fixtures:

- `RELEASE_NOTES=/path/to/file` — durable, version-wide notes.
- `CHANGES=/path/to/file` — channel/build-level changes.
- `CHANGES_DIR=/path/to/dir` — concatenates sorted `.md` files.

`Scripts/notes.sh collect` can compile explicit files, directories, or a git range:

```sh
./Scripts/notes.sh collect Changes/Current.md > updates/changes.md
./Scripts/notes.sh collect "v1.0.0-beta.78..HEAD" Changes/Current.md > updates/changes.md
CHANGES=updates/changes.md CHANNEL=beta VERSION_VALUE="$VERSION" ./Scripts/notes.sh body
```

Keep `Unreleased` above released version sections for release tooling, but
prefer `Changes/Current.md` for current PR/build notes. `Scripts/notes.sh delta`
remains available for diagnostics and fixtures, but the default CI release flow
uses the rolling files instead of deriving notes from appcast history.

Generated release-note files should be written under `updates/`, `.release/`, or `.release-notes/`. Do not commit generated notes from release workflows. The workflows commit `appcast.xml` and rolling note-file consumption with `[skip ci]`, and those paths are ignored by release triggers so they do not start another release build.

Run `./Scripts/check.sh repo` before opening release/workflow PRs. It checks bundled changelog sync, shell syntax, workflow YAML syntax, wiki coverage, stale path references, and PR release-note coverage when given a base ref. Material source/script/workflow changes must include `Changes/Current.md` or curated changelog updates unless the PR carries the `no-release-note` label for documentation, metadata, or dependency-only maintenance.

Release helper behavior is covered by `./Scripts/check.sh release`. CI also runs:

```sh
./Scripts/check.sh generated
VERSION="$VERSION" BUILD="$BUILD" ./Scripts/package.sh smoke Contained.app
CHANNEL="$CHANNEL" ./Scripts/appcast.sh validate appcast.xml
```

`Scripts/check.sh generated` catches tracked files rewritten by build/generation steps. `Scripts/package.sh smoke` checks the bundle executable, Info.plist version/build values, required SwiftPM resource bundles, bundled changelog, Sparkle.framework, and code signature. `Scripts/appcast.sh validate` checks XML structure, numeric Sparkle build numbers, short versions, enclosure URLs, release notes, and channel shape; the nightly channel intentionally allows Stable/Beta/Nightly items because it is the superset feed.

## One-time setup

1. **Sparkle EdDSA keys** — run Sparkle's `generate_keys` once. It stores the private key in your login keychain and prints the public key. Put the public key in `SUPublicEDKey` (in `Scripts/package.sh app`'s Info.plist block). **Never commit the private key.** For CI, export it as the `SPARKLE_ED_PRIVATE_KEY` repo secret.
2. **Developer ID** — a "Developer ID Application" certificate in your keychain (local signing) and, for CI, its `.p12` base64-encoded as `DEVELOPER_ID_CERT_P12` + `CERT_PASSWORD`.
3. **Notarization** — an App Store Connect API key; locally store it with `xcrun notarytool store-credentials` and pass the profile name; for CI add `NOTARYTOOL_API_KEY` / `NOTARYTOOL_KEY_ID` / `NOTARYTOOL_ISSUER`.
4. **Branch feeds** — each release branch serves its root `appcast.xml` through `https://raw.githubusercontent.com/tdeverx/contained-app/<branch>/appcast.xml`.

## Cutting a stable or beta release (local)

```sh
VERSION=1.0.0 ./Scripts/package.sh notarized                 # Stable build -> codesign -> DMG -> notarize -> staple
CHANNEL=beta VERSION=1.0.0-beta.79+abc123 ./Scripts/package.sh notarized
./Scripts/appcast.sh generate /path/to/Sparkle/bin updates  # embed notes + generate root appcast.xml
```

Then:

1. Create a GitHub release tagged `v1.0.0` (or `v1.0.0-beta.N`, with **Pre-release** checked for betas); upload the `.dmg` as a release asset. The appcast's enclosure URLs point at these assets via `--download-url-prefix`.
2. Commit the updated root `appcast.xml` back to the same branch that owns the channel. When promoting beta or stable, merge that appcast item into `nightly/appcast.xml` too so Nightly users get the promoted build.

## Nightly (CI)

`.github/workflows/nightly.yml` builds the latest green `nightly` on every push (newest commit wins via `concurrency: cancel-in-progress`), ad-hoc signs, publishes a versioned **nightly** pre-release with the new DMG, regenerates the nightly appcast item with that permanent release URL, preserves promoted beta/stable items already in the feed, and commits root `appcast.xml` to the `nightly` branch. It skips appcast signing when `SPARKLE_ED_PRIVATE_KEY` is absent. Historical nightly releases remain available for manual rollback and regression testing; Sparkle advertises only the newest nightly item.

`.github/workflows/beta.yml` and `.github/workflows/stable.yml` build promoted branches, retain the build number for the matching nightly commit when available, write their own branch appcast, and merge the promoted appcast item into the nightly feed. Published release tags and assets are immutable. On a workflow retry, the existing asset is downloaded and verified before appcast generation instead of being replaced. All workflows ask `Scripts/package.sh version` for the build number.

GitHub release immutability must remain enabled for the repository. GitHub CLI creates a draft internally while uploading assets and publishes only after the upload succeeds; publication locks the tag and assets and creates the release attestation used by workflow retries.

After appcast generation, workflows validate the branch feed before committing it. Beta and Stable workflows validate the promoted nightly feed inside the scratch nightly worktree before pushing the appcast-only `[skip ci]` commit.

## Notes

- Sparkle update *integrity* is the EdDSA signature on the appcast — that is the security boundary and works regardless of Apple notarization. Notarization is about Gatekeeper on first install; ship notarized builds so users aren't warned.
- The private Sparkle key and the Developer ID cert never live in the repo — only as keychain entries (local) or encrypted repo secrets (CI).
