# Contributing

Forks, issues, and pull requests are welcome. Contained is **source-available** under the [PolyForm Noncommercial License 1.0.0](https://github.com/tdeverx/contained-app/blob/main/LICENSE) — contributions are accepted under those same non-commercial terms, and the "Contained" name and branding are reserved (see [NOTICE](https://github.com/tdeverx/contained-app/blob/main/NOTICE)).

## Layout

```
Sources/ContainedCore/   pure logic — models, CLI wrapper, decoding, compose (no SwiftUI)
Sources/Contained/       the SwiftUI app
  DesignSystem/          glass helpers, tokens, shared components
  Features/<Domain>/     one folder per sidebar domain
  Navigation/ Stores/ Support/ History/
Tests/ContainedCoreTests/  golden-argv + decode + decision tests
Tests/ContainedAppTests/   RunSpec argv + compose mapping
scripts/                 bundle.sh, release.sh, appcast.sh
docs/wiki/               local mirror of the GitHub wiki pages
appcast.xml              Sparkle feed at the root of each release branch
```

## Conventions

- **Agents start at `AGENTS.md`.** Coding agents should read the root agent guide before editing; it summarizes branch, update, release-note, design-system, and verification rules.
- **Directory names are intentional.** SwiftPM folders stay `Sources` and `Tests`, Swift source domains use PascalCase, and repository infrastructure uses lowercase names such as `docs` and `scripts`. Put helper scripts in `scripts/` and use hyphenated names for multi-word shell scripts.
- **Every CLI action goes through a `ContainerCommands` builder** + a `ContainerClient` wrapper, with a golden-argv test. The UI never assembles argv inline — this keeps "Reveal CLI" honest.
- **Pure decision logic is factored into `ContainedCore`** (`RestartDecision`, `HealthDecision`, compose ordering) and unit-tested without spawning processes.
- **No `contained.*` personalization labels.** Card styles and healthchecks live in local stores. Only `contained.restart` and `contained.stack` are written (they must round-trip through the container).
- **Never put secrets or personal data in test fixtures.** Fixtures are captured CLI output — scrub tokens, domains, and paths before committing. (`.gitignore` blocks signing material; push protection is on.)
- **Match the surrounding style** — comment density, naming, Liquid Glass idioms. Prefer shared primitives such as `PanelHeader`, `PanelSection`, `MorphPanelScaffold`, `ResourceGlassCard`, `CommandPreviewBar`, and `Tokens`.
- **Gate debug-only tools at compile time.** Use `#if CONTAINED_DEBUG_TOOLS` for debug menus, diagnostics, fixtures, or local-only inspection surfaces. SwiftPM defines that flag only for debug builds, so release bundles exclude the code instead of merely hiding it at runtime.
- **Keep the sidebar fallback working.** Toolbar-first UI and toolbar panel navigation are experimental gates, not replacements for the classic shell.
- **Sync docs with behavior.** If behavior, settings, routes, or user-facing wording changes, update the matching page under `docs/wiki` and keep README links current.
- **Preserve update build numbers.** `scripts/version-info.sh` is the single build-number source of truth; beta/stable workflows must pass the retained `BUILD` into `scripts/bundle.sh` and merge promoted appcast items into the nightly feed.
- **Write release notes at the right level.** Put version-wide notes under the base version section, such as `## [1.0.0]`. Put channel/build changes under `Unreleased`, `## [nightly]`, `## [beta]`, or split them into `CHANGES_DIR` fragments. Prefer one fragment per PR/user-facing change under `changes/unreleased/` over one file per commit. `scripts/collect-changes.sh` can compile those fragments for a directory or git range. Stable ships full notes only; Beta/Nightly ship channel changes plus full notes.
- **Let CI check invariants, not fix them.** `scripts/ci-validate.sh` checks bundled changelog sync, shell syntax, workflow YAML syntax, Stable/Beta/Nightly release-note ordering, and PR release-note coverage when given a base ref. If `CHANGELOG.md` changes, run `./scripts/sync-changelog-resource.sh` locally and commit the bundled resource; CI uses `--check` so drift fails loudly.
- **Use `no-release-note` narrowly.** PR CI accepts the label only through `NO_RELEASE_NOTE=1`; reserve it for docs/meta-only work that does not change shipped behavior, scripts, workflows, tests, or source.

## Before a PR

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
