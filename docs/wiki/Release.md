# Release

The maintainer runbook for cutting a build and feeding the Sparkle update channels. Most of this is scripted; the parts that need Apple credentials or the Sparkle signing key are called out. For just installing or building, see [[Installation]].

## Versioning

- **`CFBundleShortVersionString`** (marketing version) — semver, with a pre-release suffix per channel:
  - Stable: `1.0.0`
  - Beta: `1.0.0-beta.<build>+<shortsha>`
  - Nightly: `1.0.0-nightly.<build>+<shortsha>` (set automatically by CI)
- **`CFBundleVersion`** (build number) — a monotonic integer. `scripts/version-info.sh build` is the single source of truth for scripts and CI; no workflow should calculate or validate a build number directly. The script rejects non-numeric build values. Beta/stable workflows first try to reuse the matching nightly appcast build for the promoted commit, then fall back to `git rev-list --count HEAD`. Sparkle orders updates by this, so it must be retained across nightly, beta, and stable for the same promoted build.

Set the marketing version for a manual build with `VERSION=… ./scripts/bundle.sh`. `scripts/release.sh` defaults to the Stable channel; set `CHANNEL=beta` only when intentionally cutting a beta locally.

## Channels

Each channel has an `appcast.xml` at the root of its branch, served through `raw.githubusercontent.com`:

- **stable** — `stable/appcast.xml`
- **beta** — `beta/appcast.xml`
- **nightly** — `nightly/appcast.xml`, a superset feed containing the newest nightly item plus promoted beta/stable items

The app's Settings → Updates picker changes the feed URL. Appcast items do not need `<sparkle:channel>` tags because the selected branch feed is the channel.

## Release Notes

Release notes are composed by `scripts/release-body.sh` and embedded by `scripts/release-notes.sh`.
The bundled in-app What's New view mirrors that order so local release notes and Sparkle appcast
notes do not drift.

- Stable ships `Full Release Notes` for the base marketing version, such as `1.0.0`.
- Beta ships `Changes Since Last Beta` followed by `Full Release Notes`.
- Nightly ships `Changes Since Last Nightly` followed by `Full Release Notes`.

The current repo can keep using `CHANGELOG.md` as both sources. The scripts are also ready for split files:

- `RELEASE_NOTES.md` or `RELEASE_NOTES=/path/to/file` — durable, version-wide notes that can be built up while a release is in progress.
- `CHANGES.md` or `CHANGES=/path/to/file` — channel/build-level changes since the last comparable release.
- `CHANGES_DIR=/path/to/dir` — concatenates sorted `.md` fragments, useful when a beta should compile every change fragment accumulated since the previous beta.

Prefer one committed fragment per PR or user-facing change, not one file per commit. A good shape is `changes/unreleased/YYYYMMDD-short-slug.md`; channel-specific fragments can live in `changes/beta/` or `changes/nightly/` when needed. Multiple small files avoid merge conflicts and let CI concatenate every fragment changed since the previous beta/nightly marker.

`scripts/collect-changes.sh` can compile fragments from a directory or a git range:

```sh
./scripts/collect-changes.sh changes/unreleased > updates/changes.md
./scripts/collect-changes.sh "v1.0.0-beta.78..HEAD" changes/unreleased > updates/changes.md
CHANGES=updates/changes.md CHANNEL=beta VERSION_VALUE="$VERSION" ./scripts/release-body.sh
```

When using a single `CHANGELOG.md`, keep `Unreleased` above released version sections, put version-wide notes under the base version section, and put current channel/build changes under `Unreleased` or a channel section such as `## [beta]` / `## [nightly]`.

Generated release-note files should be written under `updates/`, `.release/`, or `.release-notes/`. Do not commit generated notes from release workflows. The workflows only commit `appcast.xml`, and appcast-only commits are path-ignored and marked `[skip ci]` so they do not start another release build.

Run `./scripts/ci-validate.sh` before opening release/workflow PRs. It checks bundled changelog sync, shell syntax, workflow YAML syntax, and the expected Stable/Beta/Nightly release-note shape. PR CI also passes a base ref so material source/script/workflow changes must include a release note or change fragment unless the PR carries the `no-release-note` label.

Release helper behavior is covered by `./scripts/test-release-scripts.sh`. CI also runs:

```sh
./scripts/check-generated-clean.sh
VERSION="$VERSION" BUILD="$BUILD" ./scripts/validate-bundle.sh Contained.app
CHANNEL="$CHANNEL" ./scripts/validate-appcast.sh appcast.xml
```

`check-generated-clean.sh` catches tracked files rewritten by build/generation steps. `validate-bundle.sh` checks the bundle executable, Info.plist version/build values, bundled changelog, Sparkle.framework, and code signature. `validate-appcast.sh` checks XML structure, numeric Sparkle build numbers, short versions, enclosure URLs, release notes, and channel shape; the nightly channel intentionally allows Stable/Beta/Nightly items because it is the superset feed.

## One-time setup

1. **Sparkle EdDSA keys** — run Sparkle's `generate_keys` once. It stores the private key in your login keychain and prints the public key. Put the public key in `SUPublicEDKey` (in `scripts/bundle.sh`'s Info.plist block). **Never commit the private key.** For CI, export it as the `SPARKLE_ED_PRIVATE_KEY` repo secret.
2. **Developer ID** — a "Developer ID Application" certificate in your keychain (local signing) and, for CI, its `.p12` base64-encoded as `DEVELOPER_ID_CERT_P12` + `CERT_PASSWORD`.
3. **Notarization** — an App Store Connect API key; locally store it with `xcrun notarytool store-credentials` and pass the profile name; for CI add `NOTARYTOOL_API_KEY` / `NOTARYTOOL_KEY_ID` / `NOTARYTOOL_ISSUER`.
4. **Branch feeds** — each release branch serves its root `appcast.xml` through `https://raw.githubusercontent.com/tdeverx/contained-app/<branch>/appcast.xml`.

## Cutting a stable or beta release (local)

```sh
VERSION=1.0.0 ./scripts/release.sh                 # Stable build -> codesign -> DMG -> notarize -> staple
CHANNEL=beta VERSION=1.0.0-beta.79+abc123 ./scripts/release.sh
./scripts/appcast.sh /path/to/Sparkle/bin updates  # embed notes + generate root appcast.xml
```

Then:

1. Create a GitHub release tagged `v1.0.0` (or `v1.0.0-beta.N`, with **Pre-release** checked for betas); upload the `.dmg` as a release asset. The appcast's enclosure URLs point at these assets via `--download-url-prefix`.
2. Commit the updated root `appcast.xml` back to the same branch that owns the channel. When promoting beta or stable, merge that appcast item into `nightly/appcast.xml` too so Nightly users get the promoted build.

## Nightly (CI)

`.github/workflows/nightly.yml` builds the latest green `nightly` on every push (newest commit wins via `concurrency: cancel-in-progress`), ad-hoc signs, refreshes the rolling **nightly** pre-release with the new DMG, regenerates the nightly appcast item, preserves promoted beta/stable items already in the feed, and commits root `appcast.xml` to the `nightly` branch. It skips appcast signing when `SPARKLE_ED_PRIVATE_KEY` is absent.

`.github/workflows/beta.yml` and `.github/workflows/stable.yml` build promoted branches, retain the build number for the matching nightly commit when available, write their own branch appcast, and merge the promoted appcast item into the nightly feed. They upsert GitHub release assets on reruns so a retry refreshes the same tag instead of failing on an existing release. All workflows ask `scripts/version-info.sh` for the build number.

After appcast generation, workflows validate the branch feed before committing it. Beta and Stable workflows validate the promoted nightly feed inside the temporary nightly worktree before pushing the appcast-only `[skip ci]` commit.

## Notes

- Sparkle update *integrity* is the EdDSA signature on the appcast — that is the security boundary and works regardless of Apple notarization. Notarization is about Gatekeeper on first install; ship notarized builds so users aren't warned.
- The private Sparkle key and the Developer ID cert never live in the repo — only as keychain entries (local) or encrypted repo secrets (CI).
