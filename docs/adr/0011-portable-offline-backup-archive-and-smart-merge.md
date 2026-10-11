# 0011: Portable Offline Backup Archive and Smart Merge

We decided to provide an offline, file-based backup and restoration mechanism using standardized `.tlbackup` JSON archives with an intelligent de-duplicating merge strategy on import.

1. **Standardized Snapshot Schema:**
   - The offline file backup uses the same versioned JSON schema as the cloud snapshot. It encapsulates athlete settings, activity history, heart rate stream records, shoes, and training plans, while strictly stripping out external auth tokens (e.g. Strava credentials).

2. **Smart Merge Reconciliation by Default:**
   - Upon importing a backup file, the ingestion engine defaults to an additive union:
     - Activities with identical IDs or start-time/distance signatures are de-duplicated rather than duplicated.
     - Activities present locally but missing from the backup file are preserved.
     - Training plan state and preferences are updated if the imported archive contains a newer modification timestamp.

3. **Explicit Overwrite Capability:**
   - For complete device cutovers or clean restores, the import modal presents an explicit "Replace All Local Data" choice that purges existing Hive boxes before populating archive records, gated behind user confirmation.
