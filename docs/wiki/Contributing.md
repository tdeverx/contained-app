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

- **Every CLI action goes through a `ContainerCommands` builder** + a `ContainerClient` wrapper, with a golden-argv test. The UI never assembles argv inline — this keeps "Reveal CLI" honest.
- **Pure decision logic is factored into `ContainedCore`** (`RestartDecision`, `HealthDecision`, compose ordering) and unit-tested without spawning processes.
- **No `contained.*` personalization labels.** Card styles and healthchecks live in local stores. Only `contained.restart` and `contained.stack` are written (they must round-trip through the container).
- **Never put secrets or personal data in test fixtures.** Fixtures are captured CLI output — scrub tokens, domains, and paths before committing. (`.gitignore` blocks signing material; push protection is on.)
- **Match the surrounding style** — comment density, naming, Liquid Glass idioms. Prefer shared primitives such as `PanelHeader`, `PanelSection`, `MorphPanelScaffold`, `ResourceGlassCard`, `CommandPreviewBar`, and `Tokens`.
- **Keep the sidebar fallback working.** Toolbar-first UI and toolbar panel navigation are experimental gates, not replacements for the classic shell.
- **Sync docs with behavior.** If behavior, settings, routes, or user-facing wording changes, update the matching page under `docs/wiki` and keep README links current.

## Before a PR

```sh
swift build && swift test                     # must be green
git diff --check                              # no whitespace damage
./scripts/bundle.sh debug && open Contained.app # smoke-test the screens you touched
```

## Good first contributions

- Work through a row of the **1.0 Polish Checklist** in the [README](https://github.com/tdeverx/contained-app/blob/main/README.md) for one screen (states, a11y, copy, layout).
- Add a golden-argv or decode test for an under-covered command.
- Improve an empty / loading / error state.

See [[Architecture]] for how the pieces fit together.
