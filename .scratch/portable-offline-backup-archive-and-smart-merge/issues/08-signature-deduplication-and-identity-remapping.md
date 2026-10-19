# 08: Recognize the same workout across different IDs

Status: resolved

**What to build:** Extend Smart Merge so a local workout and its later remote copy become one Activity, while uncertain matches remain separate and explained.

**Blocked by:** 07 — Import with safe additive Smart Merge.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Match differing Activity IDs only by Activity type, exact UTC start instant, and distance rounded to the nearest meter, with one unambiguous candidate. Do not signature-match differing-ID zero-distance activities.
- [x] Keep distinct positive remote IDs even when signatures match, and retain multiple ambiguous signature candidates with a warning rather than choosing silently.
- [x] Canonicalize a confirmed local/remote match to its positive remote ID without any network upload. Re-key linked streams, shoe assignments, and Rehab Feedback and retain identity aliases.
- [x] Use known aliases to preserve idempotence for repeated imports, including remapped negative-ID collisions and zero-distance identity collisions that cannot safely use signatures.
- [x] Apply the same missing-field/local-conflict rules as ticket 07 and ensure rejected or ambiguous matches do not erase annotations or existing streams.
- [x] Expose signature matches, canonical identity changes, and ambiguities in Settings preview and import summaries before confirmation.
- [x] Make archive order deterministic; a second import adds no duplicate records, changes no meaningful state, and does not advance modification timestamps.
- [x] Test UTC-equivalent offsets, start-time precision, distance rounding boundaries, local-to-remote reconciliation, different positive IDs, multiple candidates, zero distance, existing aliases, and colliding negative IDs.
- [x] Use service-level reopen and injected-failure tests to prove identity remapping and every linked store commit or recover together. Add focused Settings tests for the new summary outcomes.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.


## Answer

Smart Merge groups all known identities before exact signature matching, preserves ambiguous workouts, canonicalizes confirmed remote copies, and rewrites every linked owner. Historical aliases keep repeated imports stable after edits and negative-ID collisions. Settings reports detail matches, identity changes, and uncertainty.

Verified: 642 full-suite tests, including real-store reopen, store failures, actual process interruption before/after commit, both themes at 200% text; zero analysis issues; standards and formatting; web build and Wasm dry run. Detailed logs: `D:/Projects/teman-lari/.scratch/backup-build-temp/ticket08-verified-*.log`.
