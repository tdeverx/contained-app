# ``ContainedPreviewSupport``

Deterministic sample data for SwiftUI previews and package examples.

## Overview

`ContainedPreviewSupport` gives app and package previews stable data without
launching a runtime service. It intentionally avoids localized strings and live
process calls so previews remain fast and predictable.

Use ``PreviewSamples`` for typed core/runtime fixtures:

- Containers, images, volumes, and networks.
- Runtime descriptors for the current Apple adapter and future runtime shape.
- Live stats, metric-history samples, and graph source arrays.
- Runtime-neutral card-style and widget descriptors for app previews to map
  into app-owned presentation state.
- Activity identifiers and package-error states for status, alert, and Activity
  examples.

The package does not import the app target. App previews should translate the
neutral descriptors into app-owned types such as local personalization or view
state at the preview boundary, including any localized copy shown around
activity state.

The `Samples` source folder contains the deterministic fixture models and
values. Keep new preview data there unless it becomes a reusable pure model that
belongs in `ContainedCore` or `ContainedRuntime`.
