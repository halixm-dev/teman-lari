# 04: Preserve shoe equipment and Activity assignments

Status: ready-for-agent

**What to build:** Include stored Shoe Equipment Entities and their Activity assignments in offline backups, so equipment history can move with an athlete's runs.

**Blocked by:** 02 — Export an offline backup from Settings.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [ ] Add minimal durable Shoe Equipment Entity records and Activity shoe references consistent with the equipment ADR; preserve stable identifiers, functional category, foam chemistry, supported user overrides, and modification times.
- [ ] Carry a provided shoe assignment through Manual Activity/Activity persistence rather than accepting and discarding it. No new shoe coaching or rotation UI is required.
- [ ] Register equipment writes and assignments with strict snapshot reads, coordinated revisions, and recoverable operations. Track normal record edits without rewriting legacy unknown recency.
- [ ] Populate the shared equipment section and related Activity references; expose counts in the existing Settings backup summary.
- [ ] Validate supported records and references, reject incompatible immutable ID collisions, and preserve unknown optional fields only under the shared schema rules.
- [ ] Test populated equipment and assignments through service export, decode, durable application, and reopen; verify referenced shoes remain associated with their activities.
- [ ] Verify invalid or dangling assignments fail before mutation and that equipment errors cannot produce a successful-looking incomplete export.
- [ ] Keep foam fatigue coaching, retirement algorithms, automatic gear ingestion, and a new equipment-management screen out of this slice.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

