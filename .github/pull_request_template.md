## Summary

- 

## Checks

- [ ] `./scripts/ci-validate.sh`
- [ ] `./scripts/test-release-scripts.sh`
- [ ] `swift build`
- [ ] `swift test`
- [ ] `git diff --check`
- [ ] UI/app changes smoke-tested with `./scripts/bundle.sh debug`
- [ ] Script/workflow changes covered by `./scripts/ci-validate.sh` and relevant fixture/validator scripts

## Release Notes And Docs

- [ ] Added or updated a release/change note, or applied the `no-release-note` label for docs/meta-only work
- [ ] Updated `docs/wiki` for user-facing behavior or workflow changes, or this PR does not need docs
- [ ] Synced `Sources/Contained/Resources/CHANGELOG.md` when `CHANGELOG.md` changed (`./scripts/sync-changelog-resource.sh --check` passes)

## Update Safety

- [ ] Did not compute build numbers outside `scripts/version-info.sh`
- [ ] Did not remove Nightly's ability to receive promoted Beta/Stable appcast items
- [ ] Did not introduce generated-file commits that can trigger release loops
- [ ] Bundle/appcast changes were validated with `scripts/validate-bundle.sh` / `scripts/validate-appcast.sh`
