# Updates

Contained has two update systems: Sparkle app updates and registry image update
checks.

## App updates

Signed distribution builds use Sparkle. Development bundles are inert until a
signed build points at a published appcast feed.

Channels are selected in **Settings → Updates**:

| Channel | Feed |
| --- | --- |
| Stable | `stable/appcast.xml` |
| Beta | `beta/appcast.xml` |
| Nightly | `nightly/appcast.xml` |

Each appcast lives at the root of its branch and is served by
`raw.githubusercontent.com`. The selected feed is the channel, so appcast items
do not need Sparkle channel tags.

The Nightly feed is intentionally a superset: it contains nightly builds plus
promoted Beta and Stable appcast items. Sparkle orders them by `CFBundleVersion`,
so release workflows retain the same build number when a commit moves between
Nightly, Beta, and Stable.

Fresh installs default to Nightly during pre-1.0 development.

## Release notes

Release notes are generated from full release notes plus channel/build changes.
By default both come from `CHANGELOG.md`; `RELEASE_NOTES.md`, `CHANGES.md`, and
`CHANGES_DIR` are supported when maintainers want split sources. The release
scripts embed the composed notes into Sparkle appcasts and the app can show:

- What's New in This Build
- What's New in an available update

Generated notes follow the channel:

- Stable: `Full Release Notes`.
- Beta: `Changes Since Last Beta` plus `Full Release Notes`.
- Nightly: `Changes Since Last Nightly` plus `Full Release Notes`.

## Image updates

Image update checks compare local image digests with remote registry digests.
Results are stored locally and surface on image cards, container cards, toolbar
panels, palette results, and System.

Manual checks are available from Images, System, toolbar actions, and the command
palette. Background check cadence is set in **Settings → Updates → Image
updates**.
