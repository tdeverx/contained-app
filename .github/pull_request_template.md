## Summary

- 

## Checks

- [ ] `./scripts/ci-validate.sh`
- [ ] `swift build`
- [ ] `swift test`
- [ ] `git diff --check`
- [ ] UI/app changes smoke-tested with `./scripts/bundle.sh debug`
- [ ] Script/workflow changes covered by `./scripts/ci-validate.sh`

## Release Notes And Docs

- [ ] Added or updated a release/change note, or this PR does not need one
- [ ] Updated `docs/wiki` for user-facing behavior or workflow changes, or this PR does not need docs
- [ ] Synced `Sources/Contained/Resources/CHANGELOG.md` when `CHANGELOG.md` changed (`./scripts/sync-changelog-resource.sh --check` passes)

## Update Safety

- [ ] Did not compute build numbers outside `scripts/version-info.sh`
- [ ] Did not remove Nightly's ability to receive promoted Beta/Stable appcast items
- [ ] Did not introduce generated-file commits that can trigger release loops
