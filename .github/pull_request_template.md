## Summary

- 

## Linked Issue

- Closes #
- No linked issue because:
- [ ] This PR links an issue, or explains why one is not needed

## Naming

- [ ] PR title follows `type(scope): summary` when practical, for example `fix: handle missing container stats` or `chore(deps): bump yams`

## Change Type

- [ ] App/UI behavior
- [ ] Core/runtime logic
- [ ] Release, workflow, or script behavior
- [ ] Docs, issue templates, or repository metadata only

## Validation

- [ ] `git diff --check`
- [ ] `./Scripts/check.sh repo`
- [ ] `swift build`
- [ ] `swift test`
- [ ] UI/app changes smoke-tested with `./Scripts/package.sh app debug`
- [ ] Release/script changes covered by `./Scripts/check.sh release` and relevant validators

## Release Notes And Docs

- [ ] Added or updated a release/change note, or applied the `no-release-note` label for documentation, metadata, or dependency-only maintenance
- [ ] Updated `docs` for user-facing behavior or workflow changes, or this PR does not need docs
- [ ] Updated `Documentation/Wiki/File-Map.md` and `Documentation/Wiki/_Sidebar.md` when documentation/package docs should appear in the wiki
- [ ] Synced `Sources/ContainedApp/Resources/CHANGELOG.md` when `CHANGELOG.md` changed (`./Scripts/package.sh app debug` then `./Scripts/check.sh repo` passes)

## Update Safety

- [ ] Build numbers still come only from `Scripts/package.sh version`
- [ ] Nightly can still receive promoted Beta/Stable appcast items
- [ ] Generated appcast commits still use `[skip ci]` and do not trigger release loops
- [ ] Bundle/appcast changes were validated with `Scripts/package.sh smoke` and `Scripts/appcast.sh validate`

## Notes For Reviewers

-
