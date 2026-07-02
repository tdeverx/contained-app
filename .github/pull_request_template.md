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
- [ ] `./scripts/ci-validate.sh`
- [ ] `swift build`
- [ ] `swift test`
- [ ] UI/app changes smoke-tested with `./scripts/bundle.sh debug`
- [ ] Release/script changes covered by `./scripts/test-release-scripts.sh` and relevant validators

## Release Notes And Docs

- [ ] Added or updated a release/change note, or applied the `no-release-note` label for docs/meta/dependency-only maintenance
- [ ] Updated `docs` for user-facing behavior or workflow changes, or this PR does not need docs
- [ ] Synced `Sources/ContainedApp/Resources/CHANGELOG.md` when `CHANGELOG.md` changed (`./scripts/sync-changelog-resource.sh --check` passes)

## Update Safety

- [ ] Build numbers still come only from `scripts/version-info.sh`
- [ ] Nightly can still receive promoted Beta/Stable appcast items
- [ ] Generated appcast commits still use `[skip ci]` and do not trigger release loops
- [ ] Bundle/appcast changes were validated with `scripts/validate-bundle.sh` and `scripts/validate-appcast.sh`

## Notes For Reviewers

-
