# 04: Selective Push Upload to Strava

**What to build:** An explicit, athlete-initiated "Upload to Strava" feature for local-only and offline-recorded runs. Athletes can distinguish between local-only and cloud-synced workouts on their activity lists and details. When Strava is connected, an upload button on unsynced activities allows them to selectively post the workout to Strava's API, link the resulting remote identifier to the local record, and prevent unwanted duplicates or rate-limit saturation without automatic background uploads.

**Blocked by:** 03: Non-Destructive Remote Activity Pull (Smart Merge)

**Status:** closed

- [x] Activities maintain sync status metadata (local-only vs. synced with remote Strava ID)
- [x] Activity cards and details display a visual indicator differentiating local-only runs from synced Strava runs
- [x] When Strava is connected, local-only activities expose an explicit "Upload to Strava" button
- [x] Tapping upload posts the activity details to Strava's activity creation endpoint, associates the returned remote ID with the local activity, and marks it as synced
- [x] Automated background uploading is omitted to prevent unintended publishing and avoid Strava rate limits
- [x] Rate limits (HTTP 429) or upload failures display helpful error feedback with retry options while leaving the local workout safely stored
- [x] Tests verify that selective push uploads only the specified local activity, updates its status, and protects against duplicate submissions
