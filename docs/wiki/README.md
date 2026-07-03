# Wiki Sync Contract

The GitHub wiki is a separate repository from the app source tree. Contained
keeps the maintained docs in this repository and stores only the wiki sync
contract here.

## Source Of Truth

- `docs/` contains maintained app, feature, architecture, development, and
  release docs.
- `Packages/<PackageName>/README.md` contains package-level usage docs.
- `Packages/<PackageName>/Sources/<PackageName>/*.docc/*.md` contains package
  DocC landing pages.

## Wiki Files

- [File Map](File-Map.md) maps each maintained source file to its intended wiki
  path and page title.
- [_Sidebar](_Sidebar.md) describes the intended GitHub wiki sidebar.

Wiki-local links, page titles, and navigation labels may be adjusted when
syncing into the separate wiki repo, but the mapped source file remains the
maintained content owner.
