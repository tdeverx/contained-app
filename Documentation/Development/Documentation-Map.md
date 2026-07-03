# Documentation Map

This page explains where documentation belongs in the repo and how it maps to
the separate GitHub wiki repository.

## Repo Docs

Use `Documentation/` for maintained product, feature, architecture, development, and
release documentation.

| Location | Belongs here |
| --- | --- |
| `Documentation/App/` | User-facing setup, updates, settings, troubleshooting, localization, and app behavior |
| `Documentation/Features/` | Feature workflows such as containers, images, resources, creation, run/edit, Compose import, and command palette |
| `Documentation/Architecture/` | Package boundaries, runtime architecture, UI/UX ownership, and cross-cutting technical decisions |
| `Documentation/Development/` | Contribution workflow, issue routing, documentation ownership, and maintainer process |
| `Documentation/Release/` | Release, packaging, appcast, signing, and channel runbooks |

Keep `Documentation/README.md` as the entry point for the maintained docs tree.
Root `README.md`, `Documentation/README.md`, and `Documentation/Wiki/README.md` are repo-local
entry/index pages. They should point readers at maintained sources, but they are
not synced as wiki content.

## Package Docs

Reusable package docs live beside their package so API examples change with the
code they describe.

| Package | README | DocC |
| --- | --- | --- |
| `ContainedCore` | `Packages/ContainedCore/README.md` | `Packages/ContainedCore/Sources/ContainedCore/ContainedCore.docc/ContainedCore.md` |
| `ContainedUI` | `Packages/ContainedUI/README.md` | `Packages/ContainedUI/Sources/ContainedUI/ContainedUI.docc/ContainedUI.md` |
| `ContainedUX` | `Packages/ContainedUX/README.md` | `Packages/ContainedUX/Sources/ContainedUX/ContainedUX.docc/ContainedUX.md` |

Package docs should use current nested APIs only: `Core.*`, `UI.*`, and
`UX.*`. Packages receive app-supplied copy and should not document localized
strings as package-owned resources.

## Wiki Map

GitHub wikis are stored in a separate repository. This repo keeps the wiki sync
contract under `Documentation/Wiki/` instead of duplicating wiki content.

| File | Purpose |
| --- | --- |
| `Documentation/Wiki/README.md` | Explains the wiki sync model |
| `Documentation/Wiki/File-Map.md` | Maps maintained source docs to intended wiki paths |
| `Documentation/Wiki/_Sidebar.md` | Defines the intended wiki sidebar structure |

When a maintained doc is added, renamed, or removed, update
`Documentation/Wiki/File-Map.md` and `Documentation/Wiki/_Sidebar.md` in the same change.
`Scripts/check.sh repo` checks this from the current tree, so new app,
feature, architecture, development, release, package README, and package DocC
landing pages must be indexed and mapped before CI passes.

## Naming Rules

- Use PascalCase for Swift/domain folders and lowercase for repo infrastructure
  such as `docs` and `scripts`.
- Use hyphenated names for multi-word markdown and shell script files.
- Name Swift files after the concrete type, namespace segment, or behavior they
  define.
- Keep `+` Swift filenames only when SwiftPM target basename uniqueness requires
  them.
- Remove wording that describes migration history, bridge shims, or previous
  package names once the final API is in place.
