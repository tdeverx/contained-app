### Fixes

- Bound app database growth with no-op persistence, hourly activity/metrics retention, and supported transaction-history maintenance. General settings now show allocated database storage and offer manual compaction.
- Recover safely from database fetch/save failures without inserting duplicate inventory. Failed writes roll back and stay paused until explicit retry repairs legacy records and reloads saved preferences, history projections, and scheduling state; runtime detection then reruns with restored CLI paths.
- Group registry update failures by host with classified, privacy-safe errors, bounded retry backoff, and login/retry controls. Private Apple Container image checks can reuse accessible Keychain logins without storing credentials in Contained.

### Improvements

- Add host-allocated storage analysis and exact cleanup previews for container compaction, builder cache reset, and unreferenced resources. Changed inventory requires a fresh preview, and partial results show before/after host allocation.
- Offer opt-in scheduled compaction for running application containers and the builder, with configurable thresholds and rotating bounded batches. Destructive resource cleanup stays manual; low host space is checked before pulls, builds, and recreates. Runtimes without Apple storage analysis retain their confirmed native prune actions.
