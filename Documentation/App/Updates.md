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

Release workflows only commit root `appcast.xml` back to channel branches.
Those appcast-only commits are path-ignored and marked `[skip ci]` to avoid
release loops.

CI validates generated appcasts before those commits. The validator requires a
numeric Sparkle build number, a short version, an enclosure URL, and embedded or
linked release notes. Stable feeds reject Beta/Nightly short versions, Beta feeds
require Beta short versions, and Nightly feeds allow all three channels because
Nightly users should receive promoted builds without switching channels.

Fresh installs default to Nightly during pre-1.0 development.

## Release notes

Release notes are generated from full release notes plus channel/build changes.
Full version notes come from `CHANGELOG.md`; Nightly build changes come from
`Changes/Current.md`; Beta build changes come from `Changes/Beta.md`. Explicit
`RELEASE_NOTES`, `CHANGES`, and `CHANGES_DIR` overrides remain available for
local release maintenance and fixtures. The release scripts embed the composed
notes into Sparkle appcasts, and the bundled in-app What's New view uses the
same order:

- channel/build changes first, when the channel has them
- full version notes second

Generated notes follow the channel:

- Stable: `Full Release Notes`.
- Beta: `Changes Since Last Beta` plus `Full Release Notes`.
- Nightly: `Changes Since Last Nightly` plus `Full Release Notes`.

For Nightly, CI consumes `Changes/Current.md`, then prepends it into
`Changes/Beta.md` and clears it. For Beta, CI consumes `Changes/Beta.md` and
clears it after the release has been published. The full version notes still
come from the base version section.

`Scripts/check.sh repo` checks that ordering before CI builds, and
`Scripts/check.sh repo` fails when the bundled in-app changelog resource has
drifted from the root `CHANGELOG.md`.
PR CI also requires material source/script/workflow changes to include a release
note or change fragment unless the PR is explicitly labeled `no-release-note`.

## Image updates

Image update checks compare local image digests with remote registry digests.
Results are stored locally and surface on image cards, container cards, toolbar
panels, palette results, and System.

Manual checks are available from Images, System, toolbar actions, and the command
palette. Background check cadence is set in **Settings → Updates → Image
updates**.
