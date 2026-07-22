# Contributing

Forks, issues, and pull requests are welcome. Contained is **source-available** under the [PolyForm Noncommercial License 1.0.0](https://github.com/tdeverx/contained-app/blob/main/LICENSE) — contributions are accepted under those same non-commercial terms, and the "Contained" name and branding are reserved (see [NOTICE](https://github.com/tdeverx/contained-app/blob/main/NOTICE)).

## Issues And Discussions

Start with the [repo docs index](/Documentation/README.md), then choose the place that
fits:

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
and easy to triage. See [Issues and Discussions](/Documentation/Development/Issues-and-Discussions.md) for examples.

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
changes to existing issues should be previewed before they are applied. Issue bodies
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
`chore(deps): bump yams`. See [Issues and Discussions](/Documentation/Development/Issues-and-Discussions.md) for examples.

Release branches (`nightly`, `beta`, and `stable`) are protected against
deletion and force-pushes. Normal work should move through pull requests. A full
required-PR/check rule still needs a release-bot-safe bypass before it can be
enforced without breaking appcast publishing.

## Layout

```
Packages/ContainedCore/Sources/ContainedCore/   backend orchestration — Core.*, adapters, compose, metrics, typed errors (no SwiftUI)
Sources/ContainedApp/       the SwiftUI app
  Presentation/         app-owned labels, icons, formatting, and localization mapping
  Features/<Domain>/     one folder per sidebar domain
  Navigation/ Services/ Personalization/ Persistence/
Packages/ContainedUI/ reusable SwiftUI/AppKit visual primitives and tokens
Packages/ContainedUX/ reusable navigation/layout infrastructure
Packages/ContainedCore/Sources/ContainedCoreFixtures/ semantic fixtures for preview/test/sandbox targets only
Sources/Contained/       tiny SwiftPM executable launcher
Xcode/Contained/         tiny native Xcode app launcher and Info.plist
Contained.xcworkspace/   Xcode entry point
Contained.xcodeproj/     native macOS app target that links ContainedApp
Packages/*/Tests/        package-local unit tests
Tests/ContainedAppTests/     ContainerFormState form state + runtime mapping
Scripts/                 check.sh, build.sh, package.sh, notes.sh, appcast.sh
Documentation/App/                user-facing app docs
Documentation/Features/           feature and workflow docs
Documentation/Architecture/       architecture and package-boundary docs
Documentation/Development/        contribution, issue, and repo workflow docs
Documentation/Release/            release and updater runbooks
Documentation/Wiki/               file map and sidebar contract for the separate GitHub wiki repo
appcast.xml              Sparkle feed at the root of each release branch
```

## Conventions

- **Agents start at `AGENTS.md`.** Coding agents should read the root agent guide before editing; it summarizes branch, update, release-note, design-system, and verification rules.
- **Directory names are intentional.** SwiftPM folders stay `Sources` and `Tests`, Swift source domains use PascalCase, and maintained repo surfaces use PascalCase roots such as `Documentation`, `Scripts`, and `Changes`. Put helper scripts in `Scripts/` and use hyphenated names for multi-word shell scripts.
- **Reusable packages live under `Packages/`.** Keep app-agnostic design primitives, tokens, spacing, material, opacity, and micro-chrome in `ContainedUI`; keep app state, stores, Sparkle, SwiftData, persistence, and feature routing in `Sources/ContainedApp`.
- **Fixtures are Core-owned and non-shipping.** `ContainedCoreFixtures` exposes deterministic semantic samples under `Core.Fixtures.*` for tests, previews, and sandbox-only targets. Normal app targets and distributable bundles must not depend on it.
- **The app owns product localization.** `ContainedUI` and `ContainedUX` should
  not introduce user-facing English defaults or localized resource bundles. If a
  visual component needs text, add an explicit parameter and pass app-owned
  strings from `Sources/ContainedApp`; reusable enum labels and dynamic
  templates should flow through `AppText` with English fallbacks. `ContainedCore`
  may own display-neutral semantic localization for schema labels/help,
  validation messages, runtime capability reasons, projection warnings, and
  typed package-error fallback descriptions.
- **The app owns package error presentation.** Reusable targets should throw
  typed errors with stable codes/context, preferably `Core.Error.PackageError`.
  Map those failures through `AppErrorPresentation`/`AppText` in
  `Sources/ContainedApp` before showing toasts, inline errors, alerts, or Activity
  entries. Preserve arbitrary backend stderr for immediate runtime-detail
  presentation unless an adapter can classify it as a known typed case; durable
  Activity and Console diagnostics must use allowlisted metadata instead.
- **Package docs live with the package.** Keep package-local import/setup/examples in each `Packages/<PackageName>/README.md`, with DocC landing pages under each target's `.docc` catalog. Keep app-level architecture and workflow guidance under `Documentation/`.
- **The wiki map lives in the repo.** GitHub's wiki is a separate repository. Keep maintained docs in `Documentation/` and package directories, then update `Documentation/Wiki/File-Map.md` and `Documentation/Wiki/_Sidebar.md` when a doc should appear in the wiki.
- **Xcode opens the workspace.** `Contained.xcworkspace` points at the native `Contained.xcodeproj` and local package manifests. The Xcode target links the root package's `ContainedApp` product and builds/runs a real `Contained.app`; SwiftPM remains the release, CI, bundle, signing, notarization, and appcast source of truth.
- **Use Xcode for functional SwiftUI loops.** The shared `Contained` scheme builds/runs the app and runs `ContainedAppTests`; `ContainedAppTests` is the focused app-test scheme; package schemes come from the package manifests. Package previews are colocated with the design-system element or UX primitive they exercise; do not add separate preview-only source folders.
- **Navigation infrastructure belongs in `ContainedUX` only when it is generic.** App sections, pending actions, concrete toolbar panels, and `UIState` stay in `Sources/ContainedApp` until they can cross the boundary without app policy.
- **Every backend action goes through `ContainedCore`.** Apple `container` argv builders and adapter clients are Core internals with golden tests. The UI never assembles argv inline; app stores call `Core.Orchestrator`.
- **Runtime-facing code should use `Core.*` namespaces.** Apple `container` and Docker are sibling adapter folders inside Core; future Podman, Lima-backed, remote, or other runtimes should follow the same shape and advertise capability differences through `Core.Runtime.Descriptor`. Run/edit/import flows should translate through `Core.Schema.Document` and carry `Core.Runtime.Kind` per resource/action, not as a global app setting.
- **Pure decision logic is factored into `ContainedCore`** (`Core.Container.RestartDecision`, `Core.Container.HealthDecision`, compose ordering, runtime translation) and unit-tested without spawning processes.
- **No `contained.*` personalization labels.** Card styles and healthchecks live in local stores. Only `contained.restart` and `contained.stack` are written (they must round-trip through the container).
- **Never put secrets or personal data in test fixtures.** Fixtures are captured CLI output — scrub tokens, domains, and paths before committing. (`.gitignore` blocks signing material; push protection is on.)
- **Match the surrounding style** — comment density, naming, Liquid Glass idioms. Prefer app-facing design routes such as `UI.Panel.Header`, `UI.Panel.Section`, `UI.Panel.Scaffold`, `UI.Card.Scaffold`, `UI.Action.Group`, `UI.Action.TextButton`, `UI.Action.ToggleButton`, `UI.Command.PreviewBar`, and contextual element tokens. Do not add app-local spacing, padding, radius, shadow, material, opacity, material button styles, or badge/keycap/status-dot recipes; add them to `ContainedUI` first.
- **Gate debug-only tools at compile time.** Use `#if CONTAINED_DEBUG_TOOLS` for debug menus, diagnostics, or local-only inspection surfaces. Fixture-backed samples use `CONTAINED_CORE_FIXTURES` in fixture/test/preview/sandbox-only targets, never plain `DEBUG`. SwiftPM defines `CONTAINED_DEBUG_TOOLS` only for debug builds, so release bundles exclude that code instead of merely hiding it at runtime.
- **Keep the sidebar fallback working.** Toolbar-first UI and toolbar panel navigation are experimental gates, not replacements for the classic shell.
- **Sync docs with behavior.** If behavior, settings, routes, or user-facing wording changes, update the matching page under `Documentation/App`, `Documentation/Features`, `Documentation/Development`, `Documentation/Architecture`, or `Documentation/Release`; keep README links and the wiki map current.
- **Preserve update build numbers.** `Scripts/package.sh version` is the single build-number source of truth; beta/stable workflows must pass the retained `BUILD` into `Scripts/package.sh app` and merge promoted appcast items into the nightly feed.
- **Keep code scanning intentional.** `.github/workflows/codeql.yml` is the repository-owned CodeQL setup. GitHub Actions workflow analysis runs on PRs and pushes that touch source, scripts, workflows, package files, or tests, plus a weekly scheduled baseline. Swift analysis is scheduled/manual because Swift CodeQL currently takes too long to be a healthy per-PR gate. Appcast-only, docs-only, changelog-resource-only, and release-note-only commits are ignored so generated release feed commits do not burn macOS scan minutes.
- **Write release notes at the right level.** Keep `CHANGELOG.md` curated and version-level: use the base version section, such as `## [1.0.0]`, for durable user-facing release notes. Put PR/build deltas in `Changes/Current.md`, not in `CHANGELOG.md` as a running implementation inventory. Nightly consumes `Changes/Current.md`, rolls it into `Changes/Beta.md`, and clears it; Beta consumes and clears `Changes/Beta.md`; Stable uses curated full notes and only includes `Changes/Current.md` for direct hotfix builds.
- **Let CI check invariants, not fix them.** `Scripts/check.sh repo` checks bundled changelog sync, shell syntax and headers, workflow YAML syntax and path filters, Documentation/Wiki coverage, package-boundary naming, stale path references, and PR release-note coverage when given a base ref. If `CHANGELOG.md` changes, run `./Scripts/package.sh app debug` to sync the bundled resource, then `./Scripts/check.sh repo` so drift fails loudly before CI.
- **Use `no-release-note` narrowly.** PR CI accepts the label only through `NO_RELEASE_NOTE=1`; reserve it for documentation, metadata, or dependency-only maintenance that does not change shipped behavior, scripts, workflows, tests, or source. Dependabot applies it automatically to grouped dependency update PRs.
- **Use `wiki-approved` for direct wiki-impacting changes only when a maintainer has reviewed the docs impact.** Repo docs stay authoritative; wiki work should follow `Documentation/Wiki/File-Map.md`.

## Before a PR

Link a tracked issue when the PR changes user-facing behavior, architecture,
runtime/backend behavior, release/workflow policy, security/auth/networking, or
anything that needed design/research. Tiny docs fixes, dependency bumps, typo
fixes, and direct review follow-ups can skip the issue when the PR explains why.

```sh
./Scripts/check.sh repo                       # release/workflow invariants
./Scripts/check.sh release              # release script fixtures
swift build && swift test                     # must be green
git diff --check                              # no whitespace damage
xcodebuild -workspace Contained.xcworkspace -scheme Contained -configuration Debug build
./Scripts/package.sh app debug && open Contained.app # smoke-test the screens you touched
```

### Reproducing UI performance traces

Use a packaged Debug app, the same runtime inventory, window size, and feature flags for both runs.
In Instruments, record the **Time Profiler** and **Hangs** templates for these fixed scenarios:

- Toolbar-first and classic idle for 45 seconds.
- Container grid scroll for 20 seconds, card open/close morphs for 25 seconds, then resize and regroup.
- Activity navigation for 25 seconds and repeated History, Stats, and Logs switches for 30 seconds.
- A ten-loop navigation/log soak followed by one idle minute.

The trace is acceptable when idle, grid, morph, Activity, and detail switching report zero potential
hangs; no app-owned main-thread Activity interval exceeds 100 ms; compact cards contain no Swift
Charts mark construction; unchanged refreshes emit no inventory preparation/application work; and
console publication stays at or below ten batches per second. After the soak, settled RSS should
return within 10% of its pre-loop baseline and remain level during the idle minute. Use the static
`performance.activity`, `performance.grid`, `performance.inventory`, and `performance.console`
signpost categories to isolate app-owned work. Keep `.trace` and other profiling artifacts outside
the repository.

## Good first contributions

- Work through a row of the **1.0 Polish Checklist** in the [README](https://github.com/tdeverx/contained-app/blob/main/README.md) for one screen (states, a11y, copy, layout).
- Add a golden-argv or decode test for an under-covered command.
- Improve an empty / loading / error state.

See [Architecture](/Documentation/Architecture/Architecture.md) for how the pieces fit together.
