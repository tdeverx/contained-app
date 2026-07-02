# Contributing

Forks, issues, and pull requests are welcome. Contained is **source-available** under the [PolyForm Noncommercial License 1.0.0](https://github.com/tdeverx/contained-app/blob/main/LICENSE) — contributions are accepted under those same non-commercial terms, and the "Contained" name and branding are reserved (see [NOTICE](https://github.com/tdeverx/contained-app/blob/main/NOTICE)).

## Issues And Discussions

Start with the [wiki](https://github.com/tdeverx/contained-app/wiki), then choose
the place that fits:

- Use **Discussions Q&A** for setup help, usage questions, and unclear behavior
  that is not yet an actionable bug.
- Use **Ideas** for early product thoughts before there is a concrete task.
- Use the **Development and architecture** starter thread in General for package
  boundaries, design-system direction, navigation strategy, backend choices,
  release process, and automation design until GitHub category setup is
  customized further.
- Use **Issues** for bugs, crashes, accepted features, exploration tasks,
  architecture tasks, and implementation checklists.

Blank issues are disabled. Use the closest issue form so reports stay readable
and easy to triage. See [[Issues-and-Discussions]] for examples.

For feature, architecture, backend, navigation, design-system, and exploration
work, issues should include a short goal or context, a research/design checklist,
an implementation checklist, and acceptance criteria. Bug and crash forms stay
lighter so reports are not intimidating; maintainers can add implementation
checklists after triage.

Labels are intentionally short and color-coded. Use one type label (`bug`,
`feature`, or `other`), add neutral area labels such as `app`, `core`,
`design`, `navigation`, `backend`, `docker`, `release`, or `repo`, then add a
status like `triage`, `planned`, `backlog`, `up-next`, `in-progress`,
`needs-info`, `needs-design`, `released`, `blocked`, or `wont-fix`. Broad
changes to old issues should be previewed before they are applied. Issue bodies
should only be rewritten by maintainers or when the original reporter has
explicitly allowed it.

Use native GitHub relationships for hard sequencing: parent/sub-issues for work
breakdown, and blocked-by/blocking links when one issue genuinely cannot move
until another issue is resolved. Keep softer context as plain related links.
Milestones are target buckets: `beta` for work expected before the next beta,
`stable` for the first stable-release bar, and `future` for accepted but
unscheduled or post-beta work.

Issue titles should be concise sentence-case summaries without `[Type]` or
area prefixes. PR titles should use conventional-commit style when practical,
such as `fix: handle missing container stats`, `docs: update support links`, or
`chore(deps): bump yams`. See [[Issues-and-Discussions]] for examples.

Release branches (`nightly`, `beta`, and `stable`) are protected against
deletion and force-pushes. Normal work should move through pull requests. A full
required-PR/check rule still needs a release-bot-safe bypass before it can be
enforced without breaking appcast publishing.

## Layout

```
Sources/ContainedCore/   pure logic — models, decoding, compose, argv builders (no SwiftUI)
Sources/ContainedRuntime/ shared runtime contracts and capabilities
Sources/AppleContainerRuntime/ Apple container runtime adapter
Sources/Contained/       the SwiftUI app
  DesignSystem/          core-dependent presentation mappings only
  Features/<Domain>/     one folder per sidebar domain
  Navigation/ Stores/ Support/ History/
Packages/ContainedDesignSystem/ reusable SwiftUI/AppKit visual primitives and tokens
Packages/ContainedNavigation/ reusable navigation/layout infrastructure
Contained.xcworkspace/   optional Xcode entry point over the SwiftPM packages
Contained.xcodeproj/     small Xcode scheme wrapper that delegates to SwiftPM
Tests/ContainedCoreTests/    golden-argv + decode + decision tests
Tests/ContainedRuntimeTests/ runtime adapter contract + Apple adapter tests
Tests/ContainedAppTests/     RunSpec argv + compose mapping
scripts/                 bundle.sh, release.sh, appcast.sh
docs/wiki/               local mirror of the GitHub wiki pages
appcast.xml              Sparkle feed at the root of each release branch
```

## Conventions

- **Agents start at `AGENTS.md`.** Coding agents should read the root agent guide before editing; it summarizes branch, update, release-note, design-system, and verification rules.
- **Directory names are intentional.** SwiftPM folders stay `Sources` and `Tests`, Swift source domains use PascalCase, and repository infrastructure uses lowercase names such as `docs` and `scripts`. Put helper scripts in `scripts/` and use hyphenated names for multi-word shell scripts.
- **Reusable packages live under `Packages/`.** Keep app-agnostic design primitives, tokens, spacing, material, opacity, and micro-chrome in `ContainedDesignSystem`; keep app state, stores, Sparkle, SwiftData, persistence, and feature routing in the executable target.
- **The app owns localization.** Reusable packages should not introduce
  user-facing English defaults or localized resource bundles. If a package
  component needs text, add an explicit parameter and pass app-owned strings
  from `Sources/Contained`; reusable enum labels and dynamic templates should
  flow through `AppText` with English fallbacks.
- **The app owns package error presentation.** Reusable targets should throw
  typed errors with stable codes/context, preferably `ContainedPackageError`.
  Map those failures through `AppErrorPresentation`/`AppText` in
  `Sources/Contained` before showing toasts, inline errors, alerts, or Activity
  entries. Preserve arbitrary backend stderr as runtime detail unless an adapter
  can classify it as a known typed case.
- **Package docs live with the package.** Keep package-local import/setup/examples in [`Packages/ContainedDesignSystem/README.md`](../../Packages/ContainedDesignSystem/README.md) and [`Packages/ContainedNavigation/README.md`](../../Packages/ContainedNavigation/README.md), with DocC landing pages under each target's `.docc` catalog. Keep `docs/wiki` focused on app-level architecture and workflow guidance.
- **Xcode opens the workspace.** `Contained.xcworkspace` points at the SwiftPM root package, local package manifests, and a small committed `Contained.xcodeproj` wrapper with shared schemes. Keep `Contained.xcodeproj` limited to Xcode entry-point metadata that delegates to `scripts/xcode-swiftpm-build.sh`; do not duplicate the SwiftPM source graph as hand-maintained native compile phases.
- **Navigation infrastructure belongs in `ContainedNavigation` only when it is generic.** App sections, pending actions, concrete toolbar panels, and `UIState` stay in the executable target until they can cross the boundary without app policy.
- **Every Apple `container` CLI action goes through a `ContainerCommands` builder** + `AppleContainerRuntime`, with a golden-argv test. The UI never assembles argv inline — this keeps "Reveal CLI" honest.
- **Runtime-facing code should depend on `ContainerRuntimeClient` where a backend choice matters.** The Apple `container` implementation remains the default adapter; future Docker-compatible, Podman, Lima-backed, remote, or other runtimes should be sibling adapter targets that advertise capability differences through `RuntimeDescriptor`. Create/import flows should translate through `ContainerCreateRequest` and carry `RuntimeKind` per container, not as a global app setting.
- **Pure decision logic is factored into `ContainedCore`** (`RestartDecision`, `HealthDecision`, compose ordering) and unit-tested without spawning processes.
- **No `contained.*` personalization labels.** Card styles and healthchecks live in local stores. Only `contained.restart` and `contained.stack` are written (they must round-trip through the container).
- **Never put secrets or personal data in test fixtures.** Fixtures are captured CLI output — scrub tokens, domains, and paths before committing. (`.gitignore` blocks signing material; push protection is on.)
- **Match the surrounding style** — comment density, naming, Liquid Glass idioms. Prefer app-facing design routes such as `PanelHeader`, `PanelSection`, `MorphPanelScaffold`, `ResourceCard`, `DesignActionGroup`, `DesignTextActionButton`, `DesignGlassToggle`, `CommandPreviewBar`, and `Tokens`. Do not add app-local spacing, padding, radius, shadow, material, opacity, glass button styles, or badge/keycap/status-dot recipes; add them to `ContainedDesignSystem` first.
- **Gate debug-only tools at compile time.** Use `#if CONTAINED_DEBUG_TOOLS` for debug menus, diagnostics, fixtures, or local-only inspection surfaces. SwiftPM defines that flag only for debug builds, so release bundles exclude the code instead of merely hiding it at runtime.
- **Keep the sidebar fallback working.** Toolbar-first UI and toolbar panel navigation are experimental gates, not replacements for the classic shell.
- **Sync docs with behavior.** If behavior, settings, routes, or user-facing wording changes, update the matching page under `docs/wiki` and keep README links current.
- **Preserve update build numbers.** `scripts/version-info.sh` is the single build-number source of truth; beta/stable workflows must pass the retained `BUILD` into `scripts/bundle.sh` and merge promoted appcast items into the nightly feed.
- **Keep code scanning intentional.** `.github/workflows/codeql.yml` is the repository-owned CodeQL setup. GitHub Actions workflow analysis runs on PRs and pushes that touch source, scripts, workflows, package files, or tests, plus a weekly scheduled baseline. Swift analysis is scheduled/manual because Swift CodeQL currently takes too long to be a healthy per-PR gate. Appcast-only, docs-only, changelog-resource-only, and change-fragment-only commits are ignored so generated release feed commits do not burn macOS scan minutes.
- **Write release notes at the right level.** Keep `CHANGELOG.md` curated and version-level: use the base version section, such as `## [1.0.0]`, for durable user-facing release notes. Put PR/build deltas in `changes/unreleased/` fragments by default, not in `CHANGELOG.md` as a running implementation inventory. Use `changes/beta/` or `changes/nightly/` only for channel-specific notes. `scripts/collect-changes.sh` can compile those fragments for a directory or git range. When no explicit `CHANGES`/`CHANGES_DIR` source is provided, Beta/Nightly notes first try the previous matching appcast item plus the changelog/change-fragment git delta, then fall back to channel sections and `Unreleased` only as compatibility fallbacks. Stable ships full notes only; Beta/Nightly ship channel changes plus full notes.
- **Let CI check invariants, not fix them.** `scripts/ci-validate.sh` checks bundled changelog sync, shell syntax, workflow YAML syntax, Stable/Beta/Nightly release-note ordering, and PR release-note coverage when given a base ref. If `CHANGELOG.md` changes, run `./scripts/sync-changelog-resource.sh` locally and commit the bundled resource; CI uses `--check` so drift fails loudly.
- **Use `no-release-note` narrowly.** PR CI accepts the label only through `NO_RELEASE_NOTE=1`; reserve it for docs/meta/dependency-only maintenance that does not change shipped behavior, scripts, workflows, tests, or source. Dependabot applies it automatically to grouped dependency update PRs.
- **Use `wiki-approved` for direct wiki-impacting changes only when a maintainer has reviewed the docs impact.** The wiki sync automation prototype is tracked separately in issue #26 and should not be assumed to exist until that issue is resolved.

## Before a PR

Link a tracked issue when the PR changes user-facing behavior, architecture,
runtime/backend behavior, release/workflow policy, security/auth/networking, or
anything that needed design/research. Tiny docs fixes, dependency bumps, typo
fixes, and direct review follow-ups can skip the issue when the PR explains why.

```sh
./scripts/ci-validate.sh                       # release/workflow invariants
./scripts/test-release-scripts.sh              # release script fixtures
swift build && swift test                     # must be green
git diff --check                              # no whitespace damage
./scripts/bundle.sh debug && open Contained.app # smoke-test the screens you touched
```

## Good first contributions

- Work through a row of the **1.0 Polish Checklist** in the [README](https://github.com/tdeverx/contained-app/blob/main/README.md) for one screen (states, a11y, copy, layout).
- Add a golden-argv or decode test for an under-covered command.
- Improve an empty / loading / error state.

See [[Architecture]] for how the pieces fit together.
