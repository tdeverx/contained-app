# Documentation Map

This page explains where documentation belongs in the repo and how it maps to
the separate GitHub wiki repository.

## Repo Docs

Use `docs/` for maintained product, feature, architecture, development, and
release documentation.

| Location | Belongs here |
| --- | --- |
| `docs/app/` | User-facing setup, updates, settings, troubleshooting, localization, and app behavior |
| `docs/features/` | Feature workflows such as containers, images, resources, creation, run/edit, Compose import, and command palette |
| `docs/architecture/` | Package boundaries, runtime architecture, UI/UX ownership, and cross-cutting technical decisions |
| `docs/development/` | Contribution workflow, issue routing, documentation ownership, and maintainer process |
| `docs/release/` | Release, packaging, appcast, signing, and channel runbooks |

Keep `docs/README.md` as the entry point for the maintained docs tree.

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
contract under `docs/wiki/` instead of duplicating wiki content.

| File | Purpose |
| --- | --- |
| `docs/wiki/README.md` | Explains the wiki sync model |
| `docs/wiki/File-Map.md` | Maps maintained source docs to intended wiki paths |
| `docs/wiki/_Sidebar.md` | Defines the intended wiki sidebar structure |

When a maintained doc is added, renamed, or removed, update
`docs/wiki/File-Map.md` and `docs/wiki/_Sidebar.md` in the same change.

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
