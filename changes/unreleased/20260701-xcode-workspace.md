## Architecture

- Add a checked-in Xcode workspace and small shared-scheme project wrapper that opens the SwiftPM root package and local reusable packages, delegates app/test schemes back to SwiftPM, and preserves SwiftPM as the CI/release source of truth.
