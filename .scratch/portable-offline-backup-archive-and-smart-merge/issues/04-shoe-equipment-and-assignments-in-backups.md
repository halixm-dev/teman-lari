# 04: Preserve shoe equipment and Activity assignments

Status: resolved

**What to build:** Include stored Shoe Equipment Entities and their Activity assignments in offline backups, so equipment history can move with an athlete's runs.

**Blocked by:** 02 — Export an offline backup from Settings.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Add minimal durable Shoe Equipment Entity records and Activity shoe references consistent with the equipment ADR; preserve stable identifiers, functional category, foam chemistry, supported user overrides, and modification times.
- [x] Carry a provided shoe assignment through Manual Activity/Activity persistence rather than accepting and discarding it. No new shoe coaching or rotation UI is required.
- [x] Register equipment writes and assignments with strict snapshot reads, coordinated revisions, and recoverable operations. Track normal record edits without rewriting legacy unknown recency.
- [x] Populate the shared equipment section and related Activity references; expose counts in the existing Settings backup summary.
- [x] Validate supported records and references, reject incompatible immutable ID collisions, and preserve unknown optional fields only under the shared schema rules.
- [x] Test populated equipment and assignments through service export, decode, durable application, and reopen; verify referenced shoes remain associated with their activities.
- [x] Verify invalid or dangling assignments fail before mutation and that equipment errors cannot produce a successful-looking incomplete export.
- [x] Keep foam fatigue coaching, retirement algorithms, automatic gear ingestion, and a new equipment-management screen out of this slice.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.
## Answer

Added durable typed shoe records, Activity assignment persistence, strict reference validation, and faithful equipment archives. Normal edits stamp UTC recency; refreshes and legacy records retain known/unknown recency. Explicit cleared assignments retain null shoe IDs with edit timestamps. The Manual Run selector lists stored shoes. Shared Settings counts are implemented by ticket 03 using this section's recordCount; recoverable normal identity migration is implemented by ticket 05.

Validation: 9 equipment service tests pass, including durable reopen, dangling references, strict timestamps, negative/large IDs, explicit clears, and immutable identity conflicts. Full Flutter suite: 457 passed. dart format ., standards guardrail, zero-warning analysis, web release build, and Wasm dry run pass. Current integration branch merged before completion (4571051).
