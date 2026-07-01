# Security Policy

## Supported Versions

Contained is pre-1.0 and changes quickly. Security fixes are handled on the
active `nightly` branch first, then promoted to beta or stable when those
channels exist.

## Reporting A Vulnerability

Please do not open a public issue for a vulnerability. Use
[GitHub private vulnerability reporting](https://github.com/tdeverx/contained-app/security/advisories/new)
so details stay private while a fix is prepared.

Include:

- The affected Contained version or commit.
- Your macOS version and `container --version` output, if relevant.
- A clear description of the impact.
- Reproduction steps or proof-of-concept details.
- Any logs, screenshots, or command output that help explain the issue.

The maintainer will acknowledge valid reports as soon as practical, keep the
discussion private while a fix is prepared, and publish notes once the risk is
resolved.

## Scope

Security reports should focus on Contained itself: app behavior, update flow,
release artifacts, local data handling, command construction, and repository
automation. Vulnerabilities in Apple's `container` CLI, macOS, Sparkle, or
third-party services should also be reported upstream.
