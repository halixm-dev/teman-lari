# 0010: Snapshot Cloud Backup via Google Account and Firebase

We decided to implement an optional cloud backup system powered by Google Sign-In (Firebase Auth) and snapshot-based cloud storage in Firebase Storage, avoiding continuous database write costs while providing seamless cross-device restoration.

1. **Decoupled Google Authentication:**
   - Google Sign-In operates solely as an optional authentication mechanism for cloud backup. Athletes who never log into Google retain full, unrestricted access to all local offline capabilities.

2. **Snapshot-Based Cloud Archiving:**
   - Rather than maintaining fine-grained real-time document synchronization via Cloud Firestore, athlete data is serialized into a versioned JSON snapshot archive stored under `users/{uid}/backups/latest.json` in Firebase Storage.
   - The archive includes user demographics, threshold settings, activity histories, sensor streams, training plans, shoe equipment records, and rehab feedback logs. External OAuth tokens are strictly excluded.

3. **Hybrid Backup Triggering Policy:**
   - *Automatic Background Sync:* The app quietly initiates an archive upload upon workout completion or training plan modification whenever network connectivity is active.
   - *Manual Controls:* The Settings interface provides explicit "Back Up Now" and "Restore from Cloud" controls displaying backup status, archive size, and timestamp of the last successful synchronization.
