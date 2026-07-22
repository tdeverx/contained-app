# Performance and verification

- Reduced idle UI work by avoiding unchanged runtime-inventory writes, stopping live stats while the Containers surface is hidden, and bounding historical chart rendering.
- Kept SwiftPM and Xcode dependency pins aligned, expanded automated local-package coverage, and retained native Xcode result bundles in PR CI.
