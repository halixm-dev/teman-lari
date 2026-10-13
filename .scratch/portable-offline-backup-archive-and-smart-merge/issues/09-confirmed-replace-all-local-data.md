# 09: Restore with explicitly confirmed local replacement

Status: ready-for-agent

**What to build:** Let an athlete perform a clean device cutover by replacing backup-owned local data with a validated archive after a separate deletion confirmation.

**Blocked by:** 07 — Import with safe additive Smart Merge.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [ ] Enable Replace All Local Data as a separate Settings import choice with a second confirmation describing which backup-owned records/settings will be deleted, including data absent from the archive.
- [ ] Compute replacement-specific changes from the complete validated archive. Make an empty-archive replacement explicit and support cancellation of selection, preview, or confirmation with no writes.
- [ ] Bind confirmation to the selected archive and current local revision; recompute the preview and require renewed confirmation if local data changes.
- [ ] After durable staging through the same Snapshot Backup service, clear only backup-owned Hive records and allowlisted preferences and modification metadata, then populate all six archive sections exactly.
- [ ] Treat valid empty collections and explicit nulls as authoritative replacement data. Preserve the installation's credentials, onboarding state, and unrelated preferences.
- [ ] Use the same all-store durability, exclusive writes, recovery journal, startup recovery, active-workout refusal, and concurrent-operation safeguards as Smart Merge. Do not report success after a partial clear/write.
- [ ] Refresh all affected providers and Settings form values after commit without triggering Strava/cloud traffic; verify restored plans and references remain intact after reopening.
- [ ] Test populated and empty replacement, records missing from the archive, nullable clears, stale confirmations, cancellation, storage failures after clearing, and process interruption before/after the durable commit marker.
- [ ] Complete service and Settings coverage for progress, no false cancellation after commit starts, recovery errors/retry, semantic labels, light/dark modes, and 200% text scaling.
- [ ] Verify native-to-web and web-to-native round trips using a populated all-section fixture; check native save/share and browser download/upload outcomes. Each platform must reject non-representable identities before mutation.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

