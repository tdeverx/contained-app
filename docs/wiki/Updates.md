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

Fresh installs default to Nightly during pre-1.0 development.

## Release notes

Release notes come from `CHANGELOG.md`. The release scripts embed matching notes
into Sparkle appcasts and the app can show:

- What's New in This Build
- What's New in an available update

Pre-release versions such as `1.0.0-nightly.N+sha` resolve notes from the base
`1.0.0` changelog section.

## Image updates

Image update checks compare local image digests with remote registry digests.
Results are stored locally and surface on image cards, container cards, toolbar
panels, palette results, and System.

Manual checks are available from Images, System, toolbar actions, and the command
palette. Background check cadence is set in **Settings → Updates → Image
updates**.
