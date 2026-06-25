# Install & Build

## Requirements

- macOS 26 or later (Apple silicon)
- Xcode 26 / Swift 6.2+
- Apple's `container` CLI **1.0.0** on `PATH` ([install](https://github.com/apple/container))

## Build & run

This is a Swift Package — no `.xcodeproj`. Open it in Xcode:

```sh
open Package.swift
```

Or from the command line:

```sh
swift build              # debug build
swift test               # run the unit tests
./scripts/bundle.sh      # assemble a runnable Contained.app (release by default)
open Contained.app
```

`scripts/bundle.sh [debug|release]` compiles the executable and assembles the `.app` bundle (Info.plist, icon). The `.app` is a build artifact and is git-ignored.

## Release (maintainers)

`scripts/release.sh` builds release, code-signs with a Developer ID, notarizes, and produces a DMG. It is parameterized — set `DEV_ID` and `KEYCHAIN_PROFILE` and run it yourself; signing requires your own certificate and an App Store Connect key. See [Release.md](Release.md).
