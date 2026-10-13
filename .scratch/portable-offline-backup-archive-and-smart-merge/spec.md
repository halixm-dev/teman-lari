# Spec: Portable Offline Backup Archive and Smart Merge

Status: ready-for-agent

Source: ADR 0011, with shared snapshot requirements from ADR 0010.

## Problem Statement

An athlete's Local Profile, Activity history, heart rate streams, equipment, and Training Plan state belong to one device. There is no portable backup or restore flow. Losing the device or moving to another installation risks losing locally recorded runs and personal settings, especially for athletes who use Local Profile / Guest Mode without Strava or Google.

Copying a backup onto an installation with existing runs must not duplicate workouts or erase newer settings. A complete device cutover also needs an explicit replacement option that cannot accidentally destroy local data.

The current implementation persists activities and heart rate streams in Hive and profile settings in SharedPreferences. Training Plans are generated from local inputs rather than saved as complete plans. Shoe Equipment Entities, Rehab Feedback persistence, modification timestamps, and a shared cloud snapshot codec are not implemented. The feature must bridge these storage gaps rather than treat existing raw Hive boxes as a complete backup.

## Solution

Add an offline Backup section to Settings with **Export Backup** and **Import Backup**. Export produces a self-contained, versioned UTF-8 JSON file with the `.tlbackup` extension, using the same snapshot contract intended for cloud backup. No account or internet connection is required.

Import validates the entire archive and shows its creation time, contents, and expected changes before writing anything. **Smart Merge** is the default: add missing activities, reconcile duplicates, keep unrelated local data, and accept newer preferences and Training Plan state. **Replace All Local Data** is a separate, explicitly confirmed option. Both modes preserve credentials and recover the previous state if applying the archive fails.

## User Stories

1. As an athlete in Local Profile / Guest Mode, I want to export a Snapshot Backup without signing in, so that I can protect my data independently of an account.
2. As an offline athlete, I want export and import to work without a network connection, so that I can move my history anywhere.
3. As an athlete, I want backup controls in Settings, so that I can find them alongside my profile settings.
4. As an athlete, I want a recognizable `.tlbackup` file with a dated filename, so that I can identify my backups later.
5. As an athlete, I want to choose where to save or share my backup, so that I can keep it in storage I control.
6. As an athlete using the web app, I want to download and select backup files through the browser, so that I have the same backup capability as a mobile user.
7. As an athlete, I want my name, date of birth, heart rate settings, and threshold pace included, so that another installation uses my personal configuration.
8. As an athlete, I want my complete Activity history included regardless of age or activity type, so that a backup does not silently omit older workouts.
9. As a runner, I want both Manual Activities and recorded runs included with their local identity, so that restoring does not imply that they were uploaded to Strava.
10. As an athlete, I want stored heart rate streams linked to their activities, so that restored analysis retains its source data.
11. As an athlete, I want persisted Training Plans and cycle state included, so that I can resume the state I backed up.
12. As a runner, I want stored Shoe Equipment Entities and shoe assignments included, so that my equipment history survives a device change.
13. As a returning runner, I want stored Rehab Feedback included, so that restoration does not lose my recorded check-ins.
14. As a privacy-conscious athlete, I want authentication tokens excluded from backups, so that sharing a file cannot transfer access to an external account.
15. As an athlete, I want to know that the archive contains readable personal data, so that I can choose an appropriate storage location.
16. As an athlete, I want to select an existing backup file for import, so that I can restore without a cloud service.
17. As an athlete, I want invalid or unsupported files rejected before any changes, so that a bad file cannot damage my current data.
18. As an athlete, I want a preview of archive contents and proposed changes, so that I understand the effect before importing.
19. As an athlete, I want Smart Merge selected by default, so that my existing data remains safe during a normal restore.
20. As an athlete, I want activities with matching identities imported once, so that repeated imports do not inflate my history.
21. As a runner who later uploaded a local workout, I want a matching start-time/distance signature recognized across different IDs, so that the same workout is not counted twice.
22. As an athlete, I want runs absent from the archive preserved during Smart Merge, so that importing an older file does not erase recent training.
23. As an athlete, I want distinct activities with colliding local IDs preserved, so that workouts created on different devices are not lost.
24. As an athlete, I want uncertain duplicate matches explained and preserved, so that the app does not erase a real workout based on a guess.
25. As a runner, I want local perceived exertion and other saved annotations retained when duplicates are reconciled, so that restoration does not discard my input.
26. As an athlete, I want missing heart rate streams added without replacing existing streams unnecessarily, so that analysis becomes more complete.
27. As an athlete, I want newer imported preferences applied and newer local preferences retained, so that my latest settings win.
28. As an athlete, I want newer Training Plan state applied as a coherent unit, so that restoration does not mix incompatible plans and progress.
29. As an athlete, I want older or equally dated imported state to leave my local state unchanged, so that conflict handling is predictable.
30. As an athlete moving devices, I want an explicit Replace All Local Data option, so that I can restore exactly the backed-up application data.
31. As an athlete choosing replacement, I want a separate confirmation describing what will be deleted, so that I cannot trigger a destructive restore accidentally.
32. As an athlete, I want to cancel file selection, preview, or replacement confirmation without changes, so that I remain in control.
33. As an athlete, I want progress and disabled duplicate actions during backup operations, so that I cannot start overlapping imports.
34. As an athlete, I want interrupted or failed imports to recover my previous data, so that a failed restore does not leave half an archive installed.
35. As an athlete, I want failed exports and storage errors reported clearly, so that I do not mistake an incomplete operation for a successful backup.
36. As an athlete, I want an import summary showing additions, matches, retained data, and warnings, so that I can check what happened.
37. As an athlete, I want restored activities, profile settings, and derived Running Stats visible immediately and after restarting, so that restoration feels complete.
38. As an athlete, I want import to leave external account connections unchanged and avoid uploads, so that restoring data never publishes workouts automatically.
39. As an athlete using accessibility tools, I want labeled controls, readable previews, and accessible progress messages, so that I can complete backup and restore independently.
40. As an athlete with no stored workouts, I want to export and restore a valid empty backup, so that backup behavior remains predictable from first use.

## Implementation Decisions

### Ownership and public boundary

- Introduce one transport-independent Snapshot Backup service as the primary application boundary. Its public behaviors are export, validated import preview, and confirmed apply in either Smart Merge or replacement mode. Return structured summaries and explicit cancellation or failure outcomes.
- Reuse existing local activity and preferences storage behind this service. Do not route snapshot reads through activity repository methods that can fetch from Strava, limit history, or substitute an empty result after a storage error.
- Keep archive parsing, validation, reconciliation, and operation coordination behind the service. File selection, mobile save/share, and browser download are thin platform adapters supplied through Riverpod. They do not implement merge rules.
- Archive reads and writes need strict error reporting. Existing storage methods that swallow errors cannot establish successful backup or restore; provide strict operations within the storage adapters without requiring a general repository rewrite.
- Settings owns presentation state only. Refresh dependent activity, preferences, athlete identity, cycle, Training Plan, and Running Stats providers after a successful commit, including reloading displayed Settings form values.

### One versioned snapshot contract

- Define snapshot schema version 1 once for both portable files and the future ADR 0010 cloud transport. No cloud codec exists today; this work establishes the shared contract without implementing Firebase or Google authentication.
- Use plain UTF-8 JSON with snake_case field names and a `.tlbackup` extension. The envelope identifies Teman Lari, the schema version, snapshot ID, UTC creation time, originating app version, and section counts. A filename is only a hint; validate the payload itself.
- Require every version 1 data section, including empty collections. Distinguish a missing required section, an empty section, and an explicit nullable value; absence must never silently become a destructive clear operation.
- Use UTC ISO-8601 instants for timestamps, meters for activity distance, and seconds for durations. Preserve original meaningful precision in activity data. Serialize integer identities as decimal strings in archive records and references to avoid JSON number rounding across platforms; the adapter checks that the running app can represent each ID exactly before allowing import.
- Encode only explicitly allowlisted domain data. Never dump SharedPreferences, secure storage, arbitrary Hive boxes, generated analytics, or internal recovery metadata wholesale. In particular, web authentication tokens currently share SharedPreferences with profile settings.
- Supported version 1 archives are accepted; unsupported versions fail before mutation with an actionable message. Unknown optional fields may be ignored, but unknown required data sections or unsupported record variants reject the import to prevent a lossy replacement.
- The following is the required coverage contract:

| Section | Included state | Persistence requirement |
| --- | --- | --- |
| Local Profile and preferences | Athlete name, date of birth, explicit heart rate and threshold pace settings; persisted user configuration | Preserve unset versus explicit values and per-field modification times. Derive age from birth date. |
| Activities | All persisted Activity types, local/remote identities, original measurements, perceived exertion, and supported annotations | Read the complete zero-TTL SSOT, including negative local IDs and large remote IDs. |
| Heart rate streams | All stored samples with owning Activity references | Export stored streams only; do not fetch missing streams. |
| Training Plan state | Persisted plan content, cycle start, progress/configuration, and modification time | Add durable plan serialization and storage so restored plans are not immediately discarded by regeneration. |
| Equipment | Shoe Equipment Entity records and persisted Activity assignments | Add the minimal durable record and reference support needed for faithful export/import; no shoe coaching UI. |
| Rehab Feedback | Persisted dual-window check-ins, timestamps, and related identifiers | Include this section for compatibility with ADR 0010 and add minimal durable records where absent; no new clinical engine. |

- Establish durable records and codecs for missing sections before declaring full feature acceptance. Fresh installations may have empty collections; an archive with nonempty supported sections must restore them faithfully. Merely writing permanent empty placeholders is insufficient.
- Preserve established domain semantics from ADRs 0002, 0006, and 0007. This feature transports existing plan, equipment, and feedback information; it does not implement their broader coaching features.
- Onboarding completion and external authentication are installation state, not imported athlete preferences. Keep their existing values on this installation. Replacement clears only backup-owned data and associated modification metadata, not every application preference or secure storage entry.
- Explain in the export UI that the file contains readable personal data. Encryption, passwords, compression, and cryptographic authenticity are outside version 1.

### Deterministic Smart Merge

- Evaluate all incoming activities against both the current local store and records already accepted from this archive. Reconciliation order must be deterministic, and repeated import must be idempotent.
- Match a positive remote Activity ID first. A negative local ID alone is not sufficient if its workout signature differs: independently created local workouts can collide across devices.
- For differing IDs, use a conservative signature of Activity type, exact UTC start instant, and distance normalized to the nearest meter. Match only when there is one unambiguous candidate. No fuzzy time or distance windows in version 1; two zero-distance records with differing IDs are not signature-matched.
- If an archive's negative ID collides with a distinct local workout, assign a fresh unused negative ID and rewrite all imported references consistently. A repeated import then matches the already imported workout by its signature.
- A matching signature with one local and one positive remote identity represents one workout; retain the positive identity and migrate linked streams, feedback, and assignments. This changes identity locally and does not upload anything. Preserve known aliases needed for subsequent deduplication.
- If different positive remote IDs have the same signature, or multiple candidates match a signature, retain the distinct activities and report ambiguity rather than choosing silently. If one positive ID carries incompatible Activity type/start identity, reject the archive as conflicting before any write.
- For a confirmed duplicate, retain existing non-null activity measurements and annotations; fill missing values from the archive. Preserve conflicting local non-null annotations and count these as retained conflicts. Never overwrite existing heart rate sample arrays just because an imported array is longer.
- When an existing stream is absent or empty, attach the imported valid stream after resolving the canonical Activity ID. Reject dangling required references during validation; never leave streams, shoe assignments, or feedback pointing at discarded IDs.
- Union equipment and Rehab Feedback by stable IDs. Add missing records; update mutable matching records only when imported modification time is strictly newer, preserving local values on ties or unknown recency. Rewrite their references alongside activity identity changes. Incompatible immutable identity collisions fail validation.
- Compare profile preference fields independently using their modification times. Treat Training Plan content, progress, and cycle state as one versioned unit. Replace either only when the incoming modification time is strictly newer, or initialize genuinely absent local state from valid imported state.
- Add modification metadata to all relevant normal write paths, not just backup import. Existing records without modification metadata have unknown recency; do not stamp them with the import time and falsely claim they are newer. If both values exist and either timestamp is unknown, preserve local state and show a retained conflict. Explicit clearing of a nullable preference is a timestamped value, not an omitted field.
- Archive creation time and existing storage `synced_at` values are not edit timestamps. Preserve imported modification times during apply so re-import does not become a new edit. Display timestamps as device-clock information, not proof of cross-device causal ordering.
- Never delete a local Activity, equipment record, or feedback record merely because it is absent from the archive. Merge has no deletion propagation in version 1.

### Preview, confirmation, and replacement

- Preview reports creation time, schema/app version, counts by section, added and matched activities, retained conflicts, and other state changes. Explain that Smart Merge keeps unrelated local data. Keep the selected mode obvious.
- **Import with Smart Merge** applies the validated additive result. Selecting **Replace All Local Data** opens a separate confirmation stating that all backup-owned local records and settings will be replaced, including records absent from the archive.
- Replacement follows ADR 0011: after validation and durable recovery staging, clear backup-owned Hive boxes and allowlisted preferences, then populate the archive. Do not call an indiscriminate application-wide preference or credential clear operation.
- Empty collections and cleared nullable values in a valid complete archive are authoritative during replacement. Preview must make replacement with an empty archive explicit before confirmation.
- Cancelling file selection, preview, or confirmation changes nothing. Display progress during staging and application; after the commit starts, do not offer a cancellation control that promises an unimplemented rollback.
- A preview is bound to both the selected archive and the local state revision. If local data changes before confirmation, recompute the preview and request confirmation of the changed result. Do not silently apply a stale replacement or merge decision.
- Successful import refreshes local UI data without a remote refresh, selective push, cloud upload, or account sign-in. Imported remote IDs do not establish a connected Strava identity.

### Failure safety and operation coordination

- Validate schema, all record types, finite measurements, identifiers, date formats, section counts, unique IDs within each section, and cross-references before clearing or writing live data. Validate supported historical data by domain compatibility rather than new-entry restrictions such as refusing old dates.
- Adopt an initial 50 MiB UTF-8 archive limit for both export and import, measured on actual bytes. Refuse larger input before parsing, and bound JSON nesting to 64 levels. If a complete export exceeds the limit, fail clearly rather than truncate history. Centralize these limits and test their boundaries; changing them later must not change schema semantics.
- Capture a consistent local snapshot under shared write coordination. Prevent concurrent imports, profile saves, activity ingestion, Strava pull/upload reconciliation, and plan changes from interleaving with commit. Refuse backup/import during an active tracked workout with a clear instruction to finish the workout first. Reads must not expose partially restored state.
- Hive and SharedPreferences do not provide one application-wide transaction. Stage the validated next state and a durable before-image/recovery journal for every affected store before the first live write. If staging or disk-space checks fail, leave live data unchanged.
- Apply under an exclusive write operation and mark success only after all stores are flushed and the commit marker is durable. On an apply failure before that marker, restore the before-image; a successful marker means startup finishes cleanup rather than undoing the import.
- Run recovery during initialization before normal providers or writes access backup-owned stores. An interrupted apply must recover the prior committed state before normal app use; never claim process-interruption safety from exception handling alone. If recovery itself fails, keep the recovery material and show a retryable recovery error instead of exposing a partially restored store as normal.
- The same recovery guarantee applies to Smart Merge because it can alter preferences and identity references across stores. Delete staging and recovery material only once commit or rollback is durable.
- Export is successful only when the platform adapter confirms file save/download initiation or the operating system accepts the share handoff; label those outcomes accurately. A share handoff cannot prove that a user saved the file in the destination app. Clean up failed temporary exports and never label partial output a successful backup.
- Keep expensive parsing and reconciliation away from interactive rendering where the platform permits background work. Platform adapters must support Android/iOS and the existing Flutter web target without requiring filesystem-only APIs in shared code.

## Testing Decisions

- Test externally observable outcomes: exported contents, returned previews and summaries, persisted state read back after reopen, and visible UI actions. Do not assert private helpers, exact Hive layout, internal call order, or a particular journal implementation.
- Use one primary public seam: the Snapshot Backup service. Run its behavior tests with real temporary Hive stores, controlled SharedPreferences, an injected clock, controlled file transport, and controllable storage failures. Existing local storage adapters remain the persistence boundaries; avoid introducing separate public seams for every merge helper.
- Add focused Settings widget tests through Riverpod overrides for controls, default Smart Merge, preview, cancellation, replacement confirmation, progress, errors, and refreshed values. Keep filesystem and merge algorithms outside widget mocks.
- Prior art includes the LocalActivityDataSource tests using temporary Hive directories and reopenable stores, PreferencesStorage demographics tests using controlled SharedPreferences, activity repository tests using fakes, and SettingsScreen tests using provider overrides. New assertions use `package:checks` even where older tests use matcher assertions.

| Behavior | Required evidence |
| --- | --- |
| Complete round trip | Export a populated fixture and restore into empty stores; compare all supported domain records and references after closing and reopening stores. Include nonempty plan, equipment, and feedback sections. |
| Full history | Include old runs beyond the usual UI history window, all stored Activity types, negative local IDs, and large remote IDs. Verify exact identities across native and web-compatible decoding. |
| Credential exclusion | Seed native token storage and web SharedPreferences with distinct token sentinels; assert none appear in exported data or are changed by either import mode. |
| No network access | Make remote adapters fail if called; exercise export, preview, merge, replacement, and UI refresh successfully without calls. |
| ID and signature matching | Cover same-ID duplicates, equivalent UTC offsets, local-to-remote identity reconciliation, distance rounding boundaries, and zero-distance safeguards. |
| Ambiguous identities | Cover colliding negative IDs, multiple signature matches, different positive IDs with matching signatures, conflicting positive-ID identity, and duplicate IDs within an archive. |
| Additive preservation | Verify unrelated local activities, assignments, feedback, streams, and annotations survive; missing fields fill without replacing conflicting local values. |
| Idempotence | Apply the same archive twice, including ID collisions and alias remapping; the second result adds no extra records and does not advance modification times. |
| Recency | Cover newer, older, equal, missing, and offset-normalized timestamps, per-field preference updates, explicit nullable clears, and coherent plan-state updates. |
| References | Verify streams, feedback, and equipment assignments resolve to retained IDs after all remapping; reject dangling required references before mutation. |
| Replacement | Verify backup-owned data absent from the archive is removed, archive data is installed exactly, and credentials/onboarding/other preferences are preserved. |
| Invalid input | Reject malformed or truncated JSON, wrong product marker, unsupported schema/record variants, missing sections, mismatched counts, invalid measurements/references, and nesting or byte-limit violations without changes. |
| Cancellation and empty data | Confirm every pre-commit cancellation leaves the store unchanged; validate empty export/merge and explicitly confirmed empty replacement. |
| Errors and rollback | Inject staging, Hive write, preference write, flush, and rollback failures; verify no false success, preserved recovery material, and eventual recovery of the prior state. |
| Process interruption | Interrupt a disposable restore process at durable phases, restart through initialization, and verify rollback before the commit marker or retention after it. Run for both import modes. |
| Concurrent writes | Attempt activity/profile/plan changes between preview and confirmation and during commit; verify stale preview detection and no lost writes. |
| Presentation | Verify summaries, duplicate-action prevention, active-workout refusal, error/retry states, and immediate refreshed Settings and dashboard values. |
| Platform delivery | Exercise native picker cancellation/save/share and browser download/upload behavior; prove cross-platform export/import compatibility with the same fixture. |
| Accessibility | Verify semantic labels, focus/confirmation behavior, progress announcements, light/dark themes, and 200% text scaling. |

- Use targeted tests during implementation. Before committing code, run formatting, the standards guardrail, zero-warning analysis, and the full Flutter test suite per project rules. Include a web build check because file transport and integer decoding cross platform boundaries.

## Out of Scope

- Google Sign-In, Firebase provisioning, cloud upload/download, automatic background backup, or real-time synchronization from ADR 0010.
- Automatic Activity upload, automatic network synchronization triggered by restore, or changing the external authentication model.
- New shoe rotation coaching, foam lifecycle algorithms, rehabilitation rules/check-in UI, or a redesigned Training Plan generator. Only persistence and serialization necessary to preserve their supported records belong here.
- Password-protected archives, encryption, compression, digital signatures, or third-party archive formats.
- Fuzzy matching, interactive per-record conflict editing, guaranteed ordering across incorrect device clocks, and propagation of deletions between devices.
- Backup history management, scheduled local exports, partial-section exports, or selective replacement of chosen categories.
- In-progress workout sessions, derived Running Stats caches, arbitrary application caches, OAuth tokens, and installation onboarding state.
- General refactoring of unrelated repositories or existing test suites.

## Further Notes

- ADR 0011 determines the core behavior: shared versioned JSON snapshots, default additive Smart Merge, and separately confirmed replacement. ADR 0010 additionally requires Rehab Feedback coverage in the shared format. ADRs 0007 and 0008 require local SSOT access and account-independent operation.
- Exact matching, timestamp fallback rules, archive limits, the minimal persistence additions, and recovery mechanics above are proposed implementation decisions synthesized from the ADRs and current code. They are not claims that these mechanisms already exist.
- The user confirmed the testing boundary: one Snapshot Backup service covering export, merge, replacement, and recovery, plus focused Settings widget tests.
- Implement in dependency order: durable record coverage and modification tracking; shared codec and strict snapshot access; deterministic preview/merge; recoverable apply and startup recovery; platform file transport and Settings; then platform and interruption verification. This spec creates no separate implementation tickets.
- Feature acceptance requires truthful complete coverage. Do not ship a successful-looking backup that drops unsupported nonempty plan, equipment, or feedback data, and do not mark a restore successful before durability is established.
