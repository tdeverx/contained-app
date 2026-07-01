# Installation

## Requirements

- macOS 26 or later (Apple silicon)
- Apple's [`container`](https://github.com/apple/container) CLI **1.0.0** installed and on `PATH`
- For building from source: Xcode 26 / Swift 6.2+

## Install the app

Download the latest `Contained.dmg` from [Releases](https://github.com/tdeverx/contained-app/releases), open it, and drag **Contained** to Applications.

On first launch, the bootstrap screen checks for the `container` CLI and the runtime service, and helps you start it.

> If the CLI isn't found, set its path in **Settings → General → Container CLI path**, or install it from the [container releases](https://github.com/apple/container).

## Build from source

This is a Swift Package — there is no `.xcodeproj`.

```sh
git clone https://github.com/tdeverx/contained-app.git
cd contained-app
open Package.swift        # open in Xcode
```

Or from the command line:

```sh
swift build              # debug build
swift test               # run the unit tests
./scripts/bundle.sh debug # assemble a runnable development Contained.app
open Contained.app
```

`scripts/bundle.sh [debug|release]` compiles the executable and assembles the `.app` (Info.plist, icon, embedded Sparkle). The `.app` is a build artifact and is git-ignored.

## Updates

Signed distribution builds update in-app via [Sparkle](https://sparkle-project.org). Pick a channel in **Settings → Updates**:

| Channel | What you get |
| --- | --- |
| **Stable** | Finished releases. |
| **Beta** | Pre-release builds, ahead of stable. |
| **Nightly** | The latest build from every commit (CI). Bleeding edge. **(default while pre-1.0)** |

Each channel has a branch-hosted appcast feed (`stable`, `beta`, or `nightly`). The Nightly feed also includes promoted Beta and Stable builds, ordered by their retained build number, so Nightly users still receive those releases. Fresh installs default to Nightly during pre-1.0 development. The updater is inert in development builds.

## Uninstall

Quit Contained, drag it from Applications to the Trash. To remove preferences and local history:

```sh
defaults delete com.contained.app
rm -rf ~/Library/Application\ Support/Contained
```

(Your containers, images, and volumes belong to the `container` runtime and are untouched.)
